<?php
/**
 * Common helpers shared by every endpoint:
 * CORS headers, JSON response helpers, input validation, and auth/role guards.
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=UTF-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

function sendResponse(bool $success, $data = null, string $message = '', int $code = 200): void
{
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data'    => $data,
    ]);
    exit;
}

function getJsonInput(): array
{
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

/** Basic sanitisation for plain-text fields. */
function cleanString($value): string
{
    return trim(htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8'));
}

function isValidEmail(string $email): bool
{
    return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

/**
 * Reads the Bearer token from the Authorization header and returns the
 * matching user row (id, role) or null if invalid/expired.
 */
function getAuthenticatedUser(mysqli $conn): ?array
{
    // Apache/XAMPP setups frequently do NOT hand the Authorization header to
    // PHP by default (it gets consumed before it reaches mod_php/CGI). We
    // check every place it might turn up instead of relying on one one.
    $authHeader = '';

    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        // Header names aren't guaranteed exact case, so search case-insensitively.
        foreach ($headers as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $authHeader = $value;
                break;
            }
        }
    }

    if (!$authHeader) {
        // Direct mod_php / CGI.
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    }
    if (!$authHeader) {
        // Apache commonly renames it when it's passed through a rewrite,
        // e.g. via an .htaccess RewriteRule.
        $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    }
    if (!$authHeader && function_exists('apache_request_headers')) {
        $apacheHeaders = apache_request_headers();
        foreach ($apacheHeaders as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $authHeader = $value;
                break;
            }
        }
    }

    if (!$authHeader || !preg_match('/Bearer\s+(.+)/i', $authHeader, $m)) {
        return null;
    }
    $token = $conn->real_escape_string($m[1]);

    $sql = "SELECT u.user_id, u.full_name, u.email, u.role
            FROM auth_tokens t
            JOIN users u ON u.user_id = t.user_id
            WHERE t.token = '$token' AND t.expires_at > NOW()
            LIMIT 1";
    $result = $conn->query($sql);
    if ($result && $result->num_rows === 1) {
        return $result->fetch_assoc();
    }
    return null;
}

/**
 * Guard: ends the request with 401/403 unless the caller is authenticated
 * and (if $roles is given) has one of the allowed roles.
 */
function requireRole(mysqli $conn, array $roles = []): array
{
    $user = getAuthenticatedUser($conn);
    if (!$user) {
        sendResponse(false, null, 'Unauthorized. Please log in.', 401);
    }
    if (!empty($roles) && !in_array($user['role'], $roles, true)) {
        sendResponse(false, null, 'Forbidden. You do not have permission for this action.', 403);
    }
    return $user;
}

function logActivity(mysqli $conn, ?int $userId, string $action): void
{
    $stmt = $conn->prepare("INSERT INTO activity_log (user_id, action) VALUES (?, ?)");
    $stmt->bind_param('is', $userId, $action);
    $stmt->execute();
    $stmt->close();
}
