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
  // ★ FIX: No sobreescribir reservedStock al editar desde el catálogo
  Future<void> updateMaterial(MaterialItem material) async {
    final map = material.toMap();
    map.remove('reservedStock'); // Nunca tocar las reservas desde aquí
    await _materialsRef.doc(material.id).update(map);
  }

  // 4. ELIMINAR
  Future<void> deleteMaterial(String id) async {
    await _materialsRef.doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════
  //  SISTEMA DE RESERVA DE STOCK EN 2 FASES
  // ═══════════════════════════════════════════════════════════

  /// FASE 1 — APARTAR STOCK
  Future<bool> reserveStock(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception("Material no encontrado");

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] as num?)?.toDouble() ?? 0.0;
        final currentReserved = (data['reservedStock'] as num?)?.toDouble() ?? 0.0;
        final available = currentStock - currentReserved;

        final toReserve = qty.clamp(0.0, available);
        if (toReserve <= 0) return;

        transaction.update(docRef, {
          'reservedStock': currentReserved + toReserve,
        });
      });
      return true;
    } catch (e) {
      print("❌ Error al reservar stock: $e");
      return false;
    }
  }

  /// FASE 2 — CONFIRMAR DEDUCCIÓN (al avanzar a E6)
  Future<bool> confirmStockDeduction(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception("Material no encontrado");

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] as num?)?.toDouble() ?? 0.0;
        final currentReserved = (data['reservedStock'] as num?)?.toDouble() ?? 0.0;

        final newStock = (currentStock - qty).clamp(0.0, double.infinity);
        final newReserved = (currentReserved - qty).clamp(0.0, double.infinity);

        transaction.update(docRef, {
          'stock': newStock,
          'reservedStock': newReserved,
        });
      });
      return true;
    } catch (e) {
      print("❌ Error al confirmar deducción de stock: $e");
      return false;
    }
  }

  /// CANCELAR RESERVA
  Future<bool> cancelReservation(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final currentReserved = (data['reservedStock'] as num?)?.toDouble() ?? 0.0;
        final newReserved = (currentReserved - qty).clamp(0.0, double.infinity);

        transaction.update(docRef, {
          'reservedStock': newReserved,
        });
      });
      return true;
    } catch (e) {
      print("❌ Error al cancelar reserva: $e");
      return false;
    }
  }
}