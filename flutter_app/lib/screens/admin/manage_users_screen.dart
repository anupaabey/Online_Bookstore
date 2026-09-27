import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'user_form_screen.dart';

/// Administrator-only: view all accounts, create Staff/Admin accounts,
/// change roles, and activate/deactivate accounts.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<dynamic> _users = [];
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
      final data = await ApiService.get('users.php');
      setState(() => _users = data as List);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not load users.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map user) async {
    try {
      await ApiService.put('users.php?id=${user['user_id']}', {
        'is_active': (int.parse(user['is_active'].toString()) == 1) ? 0 : 1,
      });
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeRole(Map user, String role) async {
    try {
      await ApiService.put('users.php?id=${user['user_id']}', {'role': role});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final active = int.parse(u['is_active'].toString()) == 1;
                      return Card(
                        child: ListTile(
                          title: Text(u['full_name']),
                          subtitle: Text('${u['email']}\nRole: ${u['role']}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButton<String>(
                                value: u['role'],
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'customer', child: Text('customer')),
                                  DropdownMenuItem(value: 'staff', child: Text('staff')),
                                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                                ],
                                onChanged: (v) {
                                  if (v != null) _changeRole(u, v);
                                },
                              ),
                              Switch(
                                value: active,
                                onChanged: (_) => _toggleActive(u),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          if (changed == true) _load();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff/Admin'),
      ),
    );
  }
}
