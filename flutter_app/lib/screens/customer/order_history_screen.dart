import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<BookOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('orders.php');
      setState(() => _orders = (data as List).map((e) => BookOrder.fromJson(e)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not load your orders.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'shipped': return Colors.blue;
      case 'processing': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _orders.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No orders yet.'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final o = _orders[i];
                          return Card(
                            child: ListTile(
                              title: Text('Order #${o.id}'),
                              subtitle: Text('${o.createdAt}\n\$${o.totalAmount.toStringAsFixed(2)}'),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(o.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                backgroundColor: _statusColor(o.status),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
