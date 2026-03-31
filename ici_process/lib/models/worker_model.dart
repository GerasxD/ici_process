import 'package:cloud_firestore/cloud_firestore.dart';

class Worker {
  final String id;
  final String name;
  final String email;
  final String role;
  final String nss;
  final String curp;
  final String bloodType;
  final DateTime? startDate;
  final String address;
  final String emergencyPhone; // ← NUEVO
  final String? linkedWorkerId;

  Worker({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'technician',
    this.nss = '',
    this.curp = '',
    this.bloodType = '',
    this.startDate,
    this.address = '',
    this.emergencyPhone = '', // ← NUEVO
    this.linkedWorkerId,
  });

  factory Worker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Worker(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'technician',
      nss: data['nss'] ?? '',
      curp: data['curp'] ?? '',
      bloodType: data['bloodType'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      address: data['address'] ?? '',
      emergencyPhone: data['emergencyPhone'] ?? '', // ← NUEVO
      linkedWorkerId: data['linkedWorkerId'],
    );
  }

  Map<String, dynamic> toExtraFieldsMap() {
    return {
      'nss': nss,
      'curp': curp,
      'bloodType': bloodType,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'address': address,
      'emergencyPhone': emergencyPhone, // ← NUEVO
    };
  }

  Map<String, dynamic> toFullMap() {
    return {
      'name': name,
      'email': email,
      'role': 'technician',
      'nss': nss,
      'curp': curp,
      'bloodType': bloodType,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'address': address,
      'emergencyPhone': emergencyPhone, // ← NUEVO
      'linkedWorkerId': linkedWorkerId,
    };
  }
}