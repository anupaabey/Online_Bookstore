<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

$conn = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];

// Every action on this endpoint is Administrator-only: managing staff/customer
// accounts and role assignment is an Admin permission per the brief.
$admin = requireRole($conn, ['admin']);

switch ($method) {
    case 'GET':    handleList($conn); break;
    case 'POST':   handleCreate($conn, $admin); break;
    case 'PUT':    handleUpdate($conn, $admin); break;
    case 'DELETE': handleDeactivate($conn, $admin); break;
    default:       sendResponse(false, null, 'Method not allowed.', 405);
}

/** GET /users.php -> list all accounts (no password hashes) */
function handleList(mysqli $conn): void
{
    $result = $conn->query(
        "SELECT user_id, full_name, email, role, phone, address, is_active, created_at
         FROM users ORDER BY created_at DESC"
    );
    sendResponse(true, $result->fetch_all(MYSQLI_ASSOC), 'Users retrieved.');
}

/** POST /users.php -> Admin creates a Staff or Admin account */
function handleCreate(mysqli $conn, array $admin): void
{
    $input = getJsonInput();
    $fullName = cleanString($input['full_name'] ?? '');
    $email    = cleanString($input['email'] ?? '');
    $password = (string)($input['password'] ?? '');
    $role     = cleanString($input['role'] ?? '');

    $errors = [];
    if (strlen($fullName) < 2)                       $errors['full_name'] = 'Full name must be at least 2 characters.';
    if (!isValidEmail($email))                       $errors['email'] = 'A valid email is required.';
    if (strlen($password) < 6)                       $errors['password'] = 'Password must be at least 6 characters.';
    if (!in_array($role, ['staff', 'admin', 'customer'], true)) $errors['role'] = 'Role must be customer, staff or admin.';

    if (!empty($errors)) {
        sendResponse(false, $errors, 'Validation failed.', 422);
    }

    $check = $conn->prepare("SELECT user_id FROM users WHERE email = ?");
    $check->bind_param('s', $email);
    $check->execute();
    if ($check->get_result()->num_rows > 0) {
        sendResponse(false, null, 'An account with this email already exists.', 409);
    }

    $hash = password_hash($password, PASSWORD_BCRYPT);
    $stmt = $conn->prepare("INSERT INTO users (full_name, email, password_hash, role) VALUES (?, ?, ?, ?)");
    $stmt->bind_param('ssss', $fullName, $email, $hash, $role);

    if ($stmt->execute()) {
        logActivity($conn, (int)$admin['user_id'], "Created $role account for $email");
        sendResponse(true, ['user_id' => $stmt->insert_id], 'Account created.', 201);
    }
    sendResponse(false, null, 'Failed to create account.', 500);
}

/** PUT /users.php?id=4 {role, is_active} -> change role or activate/deactivate */
function handleUpdate(mysqli $conn, array $admin): void
{
    $id = (int)($_GET['id'] ?? 0);
    $input = getJsonInput();

    if ($id <= 0) {
        sendResponse(false, null, 'User id is required.', 422);
    }
    if ($id === (int)$admin['user_id']) {
        sendResponse(false, null, 'You cannot modify your own account here.', 422);
    }

    $fields = [];
    $params = [];
    $types = '';

    if (isset($input['role']) && in_array($input['role'], ['customer', 'staff', 'admin'], true)) {
        $fields[] = 'role = ?';
        $params[] = $input['role'];
        $types .= 's';
    }
    if (isset($input['is_active'])) {
        $fields[] = 'is_active = ?';
        $params[] = (int)(bool)$input['is_active'];
        $types .= 'i';
    }

    if (empty($fields)) {
        sendResponse(false, null, 'Nothing to update.', 422);
    }

    $params[] = $id;
    $types .= 'i';

    $sql = "UPDATE users SET " . implode(', ', $fields) . " WHERE user_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();

    logActivity($conn, (int)$admin['user_id'], "Updated user #$id");
    sendResponse(true, null, 'User updated.');
}

/** DELETE /users.php?id=4 -> deactivate account (soft delete, preserves order history) */
function handleDeactivate(mysqli $conn, array $admin): void
{
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0 || $id === (int)$admin['user_id']) {
        sendResponse(false, null, 'A valid user id (not your own) is required.', 422);
    }

    $stmt = $conn->prepare("UPDATE users SET is_active = 0 WHERE user_id = ?");
    $stmt->bind_param('i', $id);
    $stmt->execute();

    logActivity($conn, (int)$admin['user_id'], "Deactivated user #$id");
    sendResponse(true, null, 'User deactivated.');
}
