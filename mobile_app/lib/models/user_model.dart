class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String role; // passenger | conductor | admin
  final String? assignedBusId;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.assignedBusId,
    required this.createdAt,
  });

  bool get isConductor => role == 'conductor';
  bool get isPassenger => role == 'passenger';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        uid: j['id'] ?? '',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        role: j['role'] ?? 'passenger',
        assignedBusId: j['assigned_bus_id'],
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'assignedBusId': assignedBusId,
        'createdAt': createdAt.toIso8601String(),
      };
}
