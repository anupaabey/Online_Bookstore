import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';

/// Staff/Admin view of every order in the system, with the ability to
/// advance an order's status (pending -> processing -> shipped -> completed).
class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  List<BookOrder> _orders = [];
  bool _loading = true;
  String? _error;

  static const _statuses = ['pending', 'processing', 'shipped', 'completed', 'cancelled'];

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
      setState(() => _error = 'Could not load orders.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(BookOrder order, String status) async {
    try {
      await ApiService.put('orders.php?id=${order.id}', {'status': status});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
    return RefreshIndicator(
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
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Order #${o.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Chip(
                                      label: Text(o.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                      backgroundColor: _statusColor(o.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${o.customerName ?? ''} · ${o.customerEmail ?? ''}'),
                                Text('\$${o.totalAmount.toStringAsFixed(2)} · ${o.createdAt}'),
                                const SizedBox(height: 8),
                                DropdownButton<String>(
                                  value: o.status,
                                  isDense: true,
                                  items: _statuses
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null && v != o.status) _updateStatus(o, v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
