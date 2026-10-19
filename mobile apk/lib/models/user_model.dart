class UserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? phoneNumber;
  final String? employeeId;
  final String? assignedArea;
  final bool isActiveAgent;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.phoneNumber,
    this.employeeId,
    this.assignedArea,
    this.isActiveAgent = true,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : username;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? 'AGENT',
      phoneNumber: json['phone_number'],
      employeeId: json['employee_id'],
      assignedArea: json['assigned_area'],
      isActiveAgent: json['is_active_agent'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'phone_number': phoneNumber,
      'employee_id': employeeId,
      'assigned_area': assignedArea,
      'is_active_agent': isActiveAgent,
    };
  }
}
