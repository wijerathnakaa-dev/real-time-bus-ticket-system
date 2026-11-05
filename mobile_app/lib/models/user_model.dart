import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'passenger' or 'conductor'
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

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'passenger',
      assignedBusId: map['assignedBusId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'assignedBusId': assignedBusId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

