import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/material_model.dart';

class MaterialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference _materialsRef;

  MaterialService() {
    _materialsRef = _db.collection('materials');
  }

  // 1. LEER
  Stream<List<MaterialItem>> getMaterials() {
    return _materialsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return MaterialItem.fromFirestore(doc);
      }).toList();
    });
  }

  // 2. CREAR
  Future<void> addMaterial(MaterialItem material) async {
    await _materialsRef.add(material.toMap());
  }

  // 3. ACTUALIZAR
  Future<void> updateMaterial(MaterialItem material) async {
    await _materialsRef.doc(material.id).update(material.toMap());
  }

  // 4. ELIMINAR
  Future<void> deleteMaterial(String id) async {
    await _materialsRef.doc(id).delete();
  }
}