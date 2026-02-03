import 'package:cloud_firestore/cloud_firestore.dart';

class ToolItem {
  final String id;
  final String name;
  final String brand;       // Marca
  final String serialNumber; // Número de serie
  final String status;      // Disponible, En Uso, Mantenimiento, Extraviada

  ToolItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.serialNumber,
    required this.status,
  });

  // Leer de Firebase
  factory ToolItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ToolItem(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      status: data['status'] ?? 'Disponible',
    );
  }

  // Guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'serialNumber': serialNumber,
      'status': status,
    };
  }
}