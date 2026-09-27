/// Represents an authenticated user and their role.
/// Role drives which screens/actions are shown across the app.
class AppUser {
  final int id;
  final String fullName;
  final String email;
  final String role; // 'customer' | 'staff' | 'admin'

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  bool get isCustomer => role == 'customer';
  bool get isStaff => role == 'staff';
  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['user_id'] is int
          ? json['user_id']
          : int.parse(json['user_id'].toString()),
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
      };
}
