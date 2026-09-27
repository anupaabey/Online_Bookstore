<?php
/**
 * One-off utility: run this once from a browser or CLI (php generate_hash.php)
 * to print bcrypt hashes for the three seed accounts, then paste them into
 * schema.sql (or run the UPDATE statements it prints) before importing.
 *
 * This exists because bcrypt hashes cannot be typed by hand reliably -
 * always generate them with PHP's own password_hash().
 */
$accounts = [
    'admin@bookstore.com' => 'Password123',
    'staff@bookstore.com' => 'Password123',
    'jane@bookstore.com'  => 'Password123',
];

foreach ($accounts as $email => $plain) {
    $hash = password_hash($plain, PASSWORD_BCRYPT);
    echo "UPDATE users SET password_hash = '$hash' WHERE email = '$email';\n";
}
