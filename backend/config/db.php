<?php
/**
 * Database connection configuration.
 * Update these four constants to match your MySQL/XAMPP/WAMP setup.
 */
define('DB_HOST', 'localhost');  // this PHP script and MySQL run on the SAME machine (your
                                  // XAMPP/WAMP box), so this must be 'localhost', never 10.0.2.2.
                                  // 10.0.2.2 is only meaningful *inside the emulator's own network*
                                  // as an alias for reaching the host PC — it's what api_service.dart's
                                  // baseUrl uses to reach this server, not what this server uses to
                                  // reach its own MySQL.
define('DB_NAME', 'bookstore_db');
define('DB_USER', 'root');
define('DB_PASS', '');

function getDbConnection(): mysqli
{
    mysqli_report(MYSQLI_REPORT_OFF); // we handle errors ourselves
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

    if ($conn->connect_error) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Database connection failed.'
        ]);
        exit;
    }
    $conn->set_charset('utf8mb4');
    return $conn;
}
