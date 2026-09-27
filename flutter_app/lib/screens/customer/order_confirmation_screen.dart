import 'package:flutter/material.dart';
import 'customer_shell.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final int orderId;
  final double total;

  const OrderConfirmationScreen({super.key, required this.orderId, required this.total});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 84),
              const SizedBox(height: 20),
              const Text('Order Placed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Order #$orderId · Total \$${total.toStringAsFixed(2)}'),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CustomerShell()),
                  (route) => false,
                ),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
