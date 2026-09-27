<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

$conn = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {

    case 'GET':
        handleGet($conn);
        break;

    case 'POST':
        handleCreate($conn);
        break;

    case 'PUT':
        handleUpdate($conn);
        break;

    case 'DELETE':
        handleDelete($conn);
        break;

    default:
        sendResponse(false, null, 'Method not allowed.', 405);
}

/**
 * GET /books.php            -> list all active books
 * GET /books.php?id=5       -> single book detail
 * GET /books.php?q=hobbit   -> search by title/author
 * GET /books.php?category=2 -> filter by category
 * Public endpoint - browsing does not require login (matches the brief:
 * "browse available books" as a core feature) but role is attached if present.
 */
function handleGet(mysqli $conn): void
{
    if (isset($_GET['id'])) {
        $id = (int)$_GET['id'];
        $stmt = $conn->prepare(
            "SELECT b.*, c.name AS category_name FROM books b
             LEFT JOIN categories c ON c.category_id = b.category_id
             WHERE b.book_id = ? AND b.is_active = 1"
        );
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $book = $stmt->get_result()->fetch_assoc();

        if (!$book) {
            sendResponse(false, null, 'Book not found.', 404);
        }
        sendResponse(true, $book, 'Book retrieved.');
    }

    $where = ['b.is_active = 1'];
    $params = [];
    $types = '';

    if (!empty($_GET['q'])) {
        $q = '%' . cleanString($_GET['q']) . '%';
        $where[] = '(b.title LIKE ? OR b.author LIKE ?)';
        $params[] = $q; $params[] = $q;
        $types .= 'ss';
    }
    if (!empty($_GET['category'])) {
        $where[] = 'b.category_id = ?';
        $params[] = (int)$_GET['category'];
        $types .= 'i';
    }

    $sql = "SELECT b.*, c.name AS category_name FROM books b
            LEFT JOIN categories c ON c.category_id = b.category_id
            WHERE " . implode(' AND ', $where) . "
            ORDER BY b.created_at DESC";

    $stmt = $conn->prepare($sql);
    if ($params) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $books = [];
    while ($row = $result->fetch_assoc()) {
        $books[] = $row;
    }
    sendResponse(true, $books, 'Books retrieved.');
}

/** POST /books.php -> create a new book. Staff + Admin only. */
function handleCreate(mysqli $conn): void
{
    $user = requireRole($conn, ['staff', 'admin']);
    $input = getJsonInput();

    [$data, $errors] = validateBookInput($input);
    if (!empty($errors)) {
        sendResponse(false, $errors, 'Validation failed.', 422);
    }

    $stmt = $conn->prepare(
        "INSERT INTO books (title, author, isbn, description, price, stock_qty, category_id, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $stmt->bind_param(
        'ssssdiii',
        $data['title'], $data['author'], $data['isbn'], $data['description'],
        $data['price'], $data['stock_qty'], $data['category_id'], $user['user_id']
    );

    if ($stmt->execute()) {
        logActivity($conn, (int)$user['user_id'], "Added book '{$data['title']}'");
        sendResponse(true, ['book_id' => $stmt->insert_id], 'Book created successfully.', 201);
    }
    sendResponse(false, null, 'Failed to create book.', 500);
}

/** PUT /books.php?id=5 -> update an existing book. Staff + Admin only. */
function handleUpdate(mysqli $conn): void
{
    $user = requireRole($conn, ['staff', 'admin']);
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        sendResponse(false, null, 'Book id is required.', 422);
    }

    $input = getJsonInput();
    [$data, $errors] = validateBookInput($input);
    if (!empty($errors)) {
        sendResponse(false, $errors, 'Validation failed.', 422);
    }

    $stmt = $conn->prepare(
        "UPDATE books SET title=?, author=?, isbn=?, description=?, price=?, stock_qty=?, category_id=?
         WHERE book_id=?"
    );
    $stmt->bind_param(
        'ssssdiii',
        $data['title'], $data['author'], $data['isbn'], $data['description'],
        $data['price'], $data['stock_qty'], $data['category_id'], $id
    );

    if ($stmt->execute()) {
        logActivity($conn, (int)$user['user_id'], "Updated book #$id");
        sendResponse(true, null, 'Book updated successfully.');
    }
    sendResponse(false, null, 'Failed to update book.', 500);
}

/** DELETE /books.php?id=5 -> soft-delete (deactivate). Admin only (staff can only edit/add stock). */
function handleDelete(mysqli $conn): void
{
    $user = requireRole($conn, ['admin']);
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        sendResponse(false, null, 'Book id is required.', 422);
    }

    $stmt = $conn->prepare("UPDATE books SET is_active = 0 WHERE book_id = ?");
    $stmt->bind_param('i', $id);

    if ($stmt->execute()) {
        logActivity($conn, (int)$user['user_id'], "Removed book #$id");
        sendResponse(true, null, 'Book removed successfully.');
    }
    sendResponse(false, null, 'Failed to remove book.', 500);
}

/** Shared validation for create/update. Returns [cleanedData, errors]. */
function validateBookInput(array $input): array
{
    $errors = [];

    $title       = cleanString($input['title'] ?? '');
    $author      = cleanString($input['author'] ?? '');
    $isbn        = cleanString($input['isbn'] ?? '');
    $description = cleanString($input['description'] ?? '');
    $price       = $input['price'] ?? null;
    $stock       = $input['stock_qty'] ?? null;
    $categoryId  = isset($input['category_id']) && $input['category_id'] !== ''
                    ? (int)$input['category_id'] : null;

    if (strlen($title) < 1)                     $errors['title'] = 'Title is required.';
    if (strlen($author) < 1)                    $errors['author'] = 'Author is required.';
    if (!is_numeric($price) || $price < 0)      $errors['price'] = 'Price must be a non-negative number.';
    if (!is_numeric($stock) || $stock < 0 || (int)$stock != $stock)
                                                 $errors['stock_qty'] = 'Stock quantity must be a non-negative whole number.';

    return [[
        'title' => $title, 'author' => $author, 'isbn' => $isbn,
        'description' => $description, 'price' => (float)$price,
        'stock_qty' => (int)$stock, 'category_id' => $categoryId,
    ], $errors];
}
