import 'package:cloud_firestore/cloud_firestore.dart';

class Provider {
  final String id;
  final String name;        // Nombre del Proveedor (Empresa)
  final String contactName; // Nombre de la persona de contacto
  final String phone;       // Teléfono
  final String email;       // Correo

  Provider({
    required this.id,
    required this.name,
    required this.contactName,
    required this.phone,
    required this.email,
  });

  // Convertir de Firestore a Objeto Dart
  factory Provider.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Provider(
      id: doc.id,
      name: data['name'] ?? '',
      contactName: data['contactName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
    );
  }

  // Convertir de Objeto Dart a Mapa para guardar
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contactName': contactName,
      'phone': phone,
      'email': email,
    };
  }
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Provider &&
      other.id == id; // Comparamos por ID único
  }

  @override
  int get hashCode => id.hashCode;
}