class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? linkedWorkerId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.linkedWorkerId,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: (data['role'] as String?) ?? 'technician',
      linkedWorkerId: data['linkedWorkerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'linkedWorkerId': linkedWorkerId,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? linkedWorkerId,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      linkedWorkerId: linkedWorkerId ?? this.linkedWorkerId,
    );
  }
}
