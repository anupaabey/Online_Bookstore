<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

$conn = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':  handleGet($conn); break;
    case 'POST': handlePlaceOrder($conn); break;
    case 'PUT':  handleUpdateStatus($conn); break;
    default:     sendResponse(false, null, 'Method not allowed.', 405);
}

/**
 * GET /orders.php          -> customer: own orders. staff/admin: ALL orders.
 * GET /orders.php?id=7     -> single order with line items (owner or staff/admin)
 */
function handleGet(mysqli $conn): void
{
    $user = requireRole($conn); // any authenticated user

    if (isset($_GET['id'])) {
        $orderId = (int)$_GET['id'];

        $orderStmt = $conn->prepare("SELECT * FROM orders WHERE order_id = ?");
        $orderStmt->bind_param('i', $orderId);
        $orderStmt->execute();
        $order = $orderStmt->get_result()->fetch_assoc();

        if (!$order) {
            sendResponse(false, null, 'Order not found.', 404);
        }
        if ($user['role'] === 'customer' && (int)$order['user_id'] !== (int)$user['user_id']) {
            sendResponse(false, null, 'Forbidden.', 403);
        }

        $itemsStmt = $conn->prepare(
            "SELECT oi.*, b.title, b.author FROM order_items oi
             JOIN books b ON b.book_id = oi.book_id WHERE oi.order_id = ?"
        );
        $itemsStmt->bind_param('i', $orderId);
        $itemsStmt->execute();
        $order['items'] = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);

        sendResponse(true, $order, 'Order retrieved.');
    }

    if (in_array($user['role'], ['staff', 'admin'], true)) {
        $result = $conn->query(
            "SELECT o.*, u.full_name, u.email FROM orders o
             JOIN users u ON u.user_id = o.user_id
             ORDER BY o.created_at DESC"
        );
    } else {
        $stmt = $conn->prepare("SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC");
        $stmt->bind_param('i', $user['user_id']);
        $stmt->execute();
        $result = $stmt->get_result();
    }

    sendResponse(true, $result->fetch_all(MYSQLI_ASSOC), 'Orders retrieved.');
}

/**
 * POST /orders.php {shipping_address, payment_method}
 * Converts the caller's current cart into an order (transaction),
 * decrements stock, and clears the cart. Customer only.
 */
function handlePlaceOrder(mysqli $conn): void
{
    $user = requireRole($conn, ['customer']);
    $input = getJsonInput();

    $address = cleanString($input['shipping_address'] ?? '');
    $payment = cleanString($input['payment_method'] ?? 'cash_on_delivery');

    if (strlen($address) < 5) {
        sendResponse(false, ['shipping_address' => 'A valid shipping address is required.'], 'Validation failed.', 422);
    }

    $cartStmt = $conn->prepare(
        "SELECT ci.cart_item_id, ci.book_id, ci.quantity, b.price, b.stock_qty, b.title
         FROM cart_items ci JOIN books b ON b.book_id = ci.book_id
         WHERE ci.user_id = ?"
    );
    $cartStmt->bind_param('i', $user['user_id']);
    $cartStmt->execute();
    $cartItems = $cartStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    if (empty($cartItems)) {
        sendResponse(false, null, 'Your cart is empty.', 422);
    }

    // Validate stock before committing anything
    foreach ($cartItems as $item) {
        if ($item['quantity'] > $item['stock_qty']) {
            sendResponse(false, null, "'{$item['title']}' only has {$item['stock_qty']} unit(s) left.", 422);
        }
    }

    $conn->begin_transaction();
    try {
        $total = array_reduce($cartItems, fn($carry, $i) => $carry + $i['price'] * $i['quantity'], 0.0);

        $orderStmt = $conn->prepare(
            "INSERT INTO orders (user_id, total_amount, shipping_address, payment_method, status)
             VALUES (?, ?, ?, ?, 'pending')"
        );
        $orderStmt->bind_param('idss', $user['user_id'], $total, $address, $payment);
        $orderStmt->execute();
        $orderId = $orderStmt->insert_id;

        $itemStmt  = $conn->prepare(
            "INSERT INTO order_items (order_id, book_id, quantity, unit_price) VALUES (?, ?, ?, ?)"
        );
        $stockStmt = $conn->prepare(
            "UPDATE books SET stock_qty = stock_qty - ? WHERE book_id = ?"
        );

        foreach ($cartItems as $item) {
            $itemStmt->bind_param('iiid', $orderId, $item['book_id'], $item['quantity'], $item['price']);
            $itemStmt->execute();

            $stockStmt->bind_param('ii', $item['quantity'], $item['book_id']);
            $stockStmt->execute();
        }

        $conn->query("DELETE FROM cart_items WHERE user_id = " . (int)$user['user_id']);

        $conn->commit();
        logActivity($conn, (int)$user['user_id'], "Placed order #$orderId");

        sendResponse(true, ['order_id' => $orderId, 'total' => round($total, 2)], 'Order placed successfully.', 201);
    } catch (Throwable $e) {
        $conn->rollback();
        sendResponse(false, null, 'Failed to place order. Please try again.', 500);
    }
}

/**
 * PUT /orders.php?id=7 {status}
 * Staff/Admin update order status (pending -> processing -> shipped -> completed / cancelled).
 */
function handleUpdateStatus(mysqli $conn): void
{
    $user = requireRole($conn, ['staff', 'admin']);
    $orderId = (int)($_GET['id'] ?? 0);
    $input = getJsonInput();
    $status = cleanString($input['status'] ?? '');

    $allowed = ['pending', 'processing', 'shipped', 'completed', 'cancelled'];
    if ($orderId <= 0 || !in_array($status, $allowed, true)) {
        sendResponse(false, null, 'A valid order id and status are required.', 422);
    }

    $stmt = $conn->prepare("UPDATE orders SET status = ? WHERE order_id = ?");
    $stmt->bind_param('si', $status, $orderId);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        sendResponse(false, null, 'Order not found or status unchanged.', 404);
    }
    logActivity($conn, (int)$user['user_id'], "Updated order #$orderId status to $status");
    sendResponse(true, null, 'Order status updated.');
}
