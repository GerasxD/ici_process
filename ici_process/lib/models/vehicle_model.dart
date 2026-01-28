import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String model;
  final double kmPerLiter;    // KM/L (Rendimiento)
  final double costPerKm;     // COST/KM (Costo por kilómetro)
  final double gasPrice;      // $/L GAS (Precio gasolina)

  Vehicle({
    required this.id,
    required this.model,
    required this.kmPerLiter,
    required this.costPerKm,
    required this.gasPrice,
  });

  // Convertir de Firebase a Objeto
  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      model: data['model'] ?? '',
      // Aseguramos que los números se lean como double
      kmPerLiter: (data['kmPerLiter'] ?? 0).toDouble(),
      costPerKm: (data['costPerKm'] ?? 0).toDouble(),
      gasPrice: (data['gasPrice'] ?? 0).toDouble(),
    );
  }

  // Convertir de Objeto a Mapa para Firebase
  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'kmPerLiter': kmPerLiter,
      'costPerKm': costPerKm,
      'gasPrice': gasPrice,
      'createdAt': FieldValue.serverTimestamp(), // Útil para ordenar
    };
  }
}