<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, null, 'Method not allowed.', 405);
}

$conn = getDbConnection();
$user = requireRole($conn); // any logged-in user

$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = $headers['Authorization'] ?? ($_SERVER['HTTP_AUTHORIZATION'] ?? '');
preg_match('/Bearer\s+(.+)/i', $authHeader, $m);
$token = $conn->real_escape_string($m[1] ?? '');

$conn->query("DELETE FROM auth_tokens WHERE token = '$token'");
logActivity($conn, (int)$user['user_id'], 'Logged out');

sendResponse(true, null, 'Logged out successfully.');
