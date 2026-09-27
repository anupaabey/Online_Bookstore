import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'customer/customer_shell.dart';
import 'staff/staff_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';

/// Chosen straight after login/auto-login: sends each role to its own
/// dashboard so screens and permissions never overlap between roles.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user.isAdmin) return const AdminDashboardScreen();
    if (user.isStaff) return const StaffDashboardScreen();
    return const CustomerShell();
  }
}
