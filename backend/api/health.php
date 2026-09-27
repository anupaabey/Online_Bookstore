<?php
require_once __DIR__ . '/../helpers.php';

try {
    db()->query('SELECT 1');

    respond([
        'success' => true,
        'message' => 'BookNest API is running'
    ]);
} catch (Throwable $e) {
    fail('Database connection failed: ' . $e->getMessage(), 500);
}
