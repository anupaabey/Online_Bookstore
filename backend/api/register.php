<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, null, 'Method not allowed.', 405);
}

$input = getJsonInput();

$fullName = cleanString($input['full_name'] ?? '');
$email    = cleanString($input['email'] ?? '');
$password = (string)($input['password'] ?? '');

// ---- Validation ----
$errors = [];
if (strlen($fullName) < 2)           $errors['full_name'] = 'Full name must be at least 2 characters.';
if (!isValidEmail($email))           $errors['email'] = 'A valid email address is required.';
if (strlen($password) < 6)           $errors['password'] = 'Password must be at least 6 characters.';

if (!empty($errors)) {
    sendResponse(false, $errors, 'Validation failed.', 422);
}

$conn = getDbConnection();

// Only "customer" accounts can self-register. Staff/Admin are created by an Administrator.
$role = 'customer';

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
    logActivity($conn, $stmt->insert_id, 'Registered a new customer account');
    sendResponse(true, ['user_id' => $stmt->insert_id], 'Account created successfully. Please log in.', 201);
} else {
    sendResponse(false, null, 'Registration failed. Please try again.', 500);
}
