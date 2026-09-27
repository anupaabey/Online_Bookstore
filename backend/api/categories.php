<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

$conn = getDbConnection();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendResponse(false, null, 'Method not allowed.', 405);
}

$result = $conn->query("SELECT category_id, name FROM categories ORDER BY name");
$categories = [];
while ($row = $result->fetch_assoc()) {
    $categories[] = $row;
}
sendResponse(true, $categories, 'Categories retrieved.');
