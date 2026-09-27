<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

$conn = getDbConnection();
$user = requireRole($conn, ['customer']); // only customers own a cart
$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':    handleGetCart($conn, $user); break;
    case 'POST':   handleAddToCart($conn, $user); break;
    case 'PUT':    handleUpdateQty($conn, $user); break;
    case 'DELETE': handleRemoveItem($conn, $user); break;
    default:       sendResponse(false, null, 'Method not allowed.', 405);
}

/** GET /cart.php -> list current user's cart items with book details + running total */
function handleGetCart(mysqli $conn, array $user): void
{
    $stmt = $conn->prepare(
        "SELECT ci.cart_item_id, ci.quantity, b.book_id, b.title, b.author, b.price, b.stock_qty, b.cover_image
         FROM cart_items ci
         JOIN books b ON b.book_id = ci.book_id
         WHERE ci.user_id = ?
         ORDER BY ci.added_at DESC"
    );
    $stmt->bind_param('i', $user['user_id']);
    $stmt->execute();
    $result = $stmt->get_result();

    $items = [];
    $total = 0.0;
    while ($row = $result->fetch_assoc()) {
        $row['subtotal'] = round($row['price'] * $row['quantity'], 2);
        $total += $row['subtotal'];
        $items[] = $row;
    }

    sendResponse(true, ['items' => $items, 'total' => round($total, 2)], 'Cart retrieved.');
}

/** POST /cart.php {book_id, quantity} -> add or increment an item */
function handleAddToCart(mysqli $conn, array $user): void
{
    $input = getJsonInput();
    $bookId = (int)($input['book_id'] ?? 0);
    $qty    = (int)($input['quantity'] ?? 1);

    if ($bookId <= 0 || $qty <= 0) {
        sendResponse(false, null, 'A valid book_id and quantity are required.', 422);
    }

    $bookStmt = $conn->prepare("SELECT stock_qty FROM books WHERE book_id = ? AND is_active = 1");
    $bookStmt->bind_param('i', $bookId);
    $bookStmt->execute();
    $book = $bookStmt->get_result()->fetch_assoc();

    if (!$book) {
        sendResponse(false, null, 'Book not found.', 404);
    }
    if ($qty > $book['stock_qty']) {
        sendResponse(false, null, "Only {$book['stock_qty']} unit(s) left in stock.", 422);
    }

    $stmt = $conn->prepare(
        "INSERT INTO cart_items (user_id, book_id, quantity) VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)"
    );
    $stmt->bind_param('iii', $user['user_id'], $bookId, $qty);

    if ($stmt->execute()) {
        sendResponse(true, null, 'Item added to cart.', 201);
    }
    sendResponse(false, null, 'Failed to add item to cart.', 500);
}

/** PUT /cart.php {cart_item_id, quantity} -> change quantity of a line */
function handleUpdateQty(mysqli $conn, array $user): void
{
    $input = getJsonInput();
    $itemId = (int)($input['cart_item_id'] ?? 0);
    $qty    = (int)($input['quantity'] ?? 0);

    if ($itemId <= 0 || $qty <= 0) {
        sendResponse(false, null, 'A valid cart_item_id and quantity (>0) are required.', 422);
    }

    $stmt = $conn->prepare("UPDATE cart_items SET quantity = ? WHERE cart_item_id = ? AND user_id = ?");
    $stmt->bind_param('iii', $qty, $itemId, $user['user_id']);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        sendResponse(false, null, 'Cart item not found.', 404);
    }
    sendResponse(true, null, 'Cart updated.');
}

/** DELETE /cart.php?cart_item_id=3 -> remove a line from the cart */
function handleRemoveItem(mysqli $conn, array $user): void
{
    $itemId = (int)($_GET['cart_item_id'] ?? 0);
    if ($itemId <= 0) {
        sendResponse(false, null, 'cart_item_id is required.', 422);
    }

    $stmt = $conn->prepare("DELETE FROM cart_items WHERE cart_item_id = ? AND user_id = ?");
    $stmt->bind_param('ii', $itemId, $user['user_id']);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        sendResponse(false, null, 'Cart item not found.', 404);
    }
    sendResponse(true, null, 'Item removed from cart.');
}
