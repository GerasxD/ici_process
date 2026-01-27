import '../core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? linkedWorkerId; // Para técnicos vinculados a un trabajador

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.linkedWorkerId,
  });

  // Convertir de Firebase a Objeto Dart
  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      // Mapeamos el string de la DB al enum de Dart
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == (data['role'] ?? 'technician'),
        orElse: () => UserRole.technician,
      ),
      linkedWorkerId: data['linkedWorkerId'],
    );
  }

  // Convertir de Objeto Dart a Map para Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.toString().split('.').last, // Guardamos solo el nombre (admin, technician, etc.)
      'linkedWorkerId': linkedWorkerId,
    };
  }
}