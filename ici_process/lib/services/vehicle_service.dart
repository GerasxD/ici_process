import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';

class VehicleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference _ref;

  VehicleService() {
    _ref = _db.collection('vehicles'); // Nueva colección
  }

  // 1. LEER (Ordenados por fecha de creación descendente)
  Stream<List<Vehicle>> getVehicles() {
    return _ref.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Vehicle.fromFirestore(doc);
      }).toList();
    });
  }

  // 2. CREAR
  Future<void> addVehicle(Vehicle vehicle) async {
    await _ref.add(vehicle.toMap());
  }

  // 3. ACTUALIZAR
  Future<void> updateVehicle(Vehicle vehicle) async {
    await _ref.doc(vehicle.id).update(vehicle.toMap());
  }

  // 4. ELIMINAR
  Future<void> deleteVehicle(String id) async {
    await _ref.doc(id).delete();
  }
}