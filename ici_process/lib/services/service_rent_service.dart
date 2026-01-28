import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';

class ServiceRentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference _ref;

  ServiceRentService() {
    _ref = _db.collection('services_rents'); // Nueva colección separada
  }

  // 1. LEER
  Stream<List<ServiceItem>> getServices() {
    return _ref.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ServiceItem.fromFirestore(doc);
      }).toList();
    });
  }

  // 2. CREAR
  Future<void> addService(ServiceItem item) async {
    try {
      print("📤 Enviando Servicio a Firebase: ${item.toMap()}");
      await _ref.add(item.toMap());
    } catch (e) {
      print("❌ Error addService: $e");
      rethrow;
    }
  }

  // 3. ACTUALIZAR
  Future<void> updateService(ServiceItem item) async {
    try {
      await _ref.doc(item.id).update(item.toMap());
    } catch (e) {
      print("❌ Error updateService: $e");
      rethrow;
    }
  }

  // 4. ELIMINAR
  Future<void> deleteService(String id) async {
    await _ref.doc(id).delete();
  }
}