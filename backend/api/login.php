<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, null, 'Method not allowed.', 405);
}

$input = getJsonInput();
$email    = cleanString($input['email'] ?? '');
$password = (string)($input['password'] ?? '');

if (!isValidEmail($email) || $password === '') {
    sendResponse(false, null, 'Email and password are required.', 422);
}

$conn = getDbConnection();

$stmt = $conn->prepare("SELECT user_id, full_name, email, password_hash, role, is_active FROM users WHERE email = ?");
$stmt->bind_param('s', $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    sendResponse(false, null, 'Invalid email or password.', 401);
}

$user = $result->fetch_assoc();

if ((int)$user['is_active'] === 0) {
    sendResponse(false, null, 'This account has been deactivated. Contact an administrator.', 403);
}

if (!password_verify($password, $user['password_hash'])) {
    sendResponse(false, null, 'Invalid email or password.', 401);
}

// Issue a new bearer token valid for 7 days
$token = bin2hex(random_bytes(32));
$expires = date('Y-m-d H:i:s', strtotime('+7 days'));

$tokenStmt = $conn->prepare("INSERT INTO auth_tokens (user_id, token, expires_at) VALUES (?, ?, ?)");
$tokenStmt->bind_param('iss', $user['user_id'], $token, $expires);
$tokenStmt->execute();

logActivity($conn, (int)$user['user_id'], 'Logged in');

sendResponse(true, [
    'token' => $token,
    'user'  => [
        'user_id'   => (int)$user['user_id'],
        'full_name' => $user['full_name'],
        'email'     => $user['email'],
        'role'      => $user['role'],
    ],
], 'Login successful.');
