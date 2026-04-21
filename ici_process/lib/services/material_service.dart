import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/material_model.dart';

class MaterialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference _materialsRef;

  MaterialService() {
    _materialsRef = _db.collection('materials');
  }

  // ═══════════════════════════════════════════════════════════
  //  1. LEER
  // ═══════════════════════════════════════════════════════════
  Stream<List<MaterialItem>> getMaterials() {
    return _materialsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => MaterialItem.fromFirestore(doc)).toList();
    });
  }

  Future<MaterialItem?> getMaterialById(String id) async {
    try {
      final doc = await _materialsRef.doc(id).get();
      if (doc.exists) {
        return MaterialItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error obteniendo material por ID: $e");
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  2. CREAR
  // ═══════════════════════════════════════════════════════════
  Future<String> addMaterial(MaterialItem material) async {
    final map = material.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();
    final docRef = await _materialsRef.add(map);
    return docRef.id;
  }

  // ═══════════════════════════════════════════════════════════
  //  3. ACTUALIZAR
  // ═══════════════════════════════════════════════════════════
  Future<void> updateMaterial(MaterialItem material) async {
    final map = material.toMap();
    map.remove('reservedStock');
    map['updatedAt'] = FieldValue.serverTimestamp();
    await _materialsRef.doc(material.id).update(map);
  }

  /// ★ Actualización parcial: solo modifica los campos enviados.
  /// Blinda reservedStock (solo los métodos de reserva pueden tocarlo).
  Future<void> updateMaterialFields(String id, Map<String, dynamic> data) async {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.remove('reservedStock');
    sanitized.remove('id');
    sanitized['updatedAt'] = FieldValue.serverTimestamp();
    await _materialsRef.doc(id).update(sanitized);
  }

  // ═══════════════════════════════════════════════════════════
  //  4. ELIMINAR
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteMaterial(String id) async {
    await _materialsRef.doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════
  //  SISTEMA DE RESERVA DE STOCK EN 2 FASES
  // ═══════════════════════════════════════════════════════════

  /// FASE 1 — APARTAR STOCK
  /// Retorna la CANTIDAD REAL apartada. -1.0 si hubo error.
  Future<double> reserveStock(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return 0.0;

    try {
      double actuallyReserved = 0.0;

      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception("Material no encontrado");

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] as num?)?.toDouble() ?? 0.0;
        final currentReserved = (data['reservedStock'] as num?)?.toDouble() ?? 0.0;
        final available = (currentStock - currentReserved).clamp(0.0, double.infinity);

        actuallyReserved = qty.clamp(0.0, available);
        if (actuallyReserved <= 0) return;

        transaction.update(docRef, {
          'reservedStock': currentReserved + actuallyReserved,
        });
      });

      return actuallyReserved;
    } catch (e) {
      debugPrint("❌ Error al reservar stock: $e");
      return -1.0;
    }
  }

  /// FASE 2 — CONFIRMAR DEDUCCIÓN
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

        final safeQtyToDeduct = qty.clamp(0.0, currentStock);
        final safeReservedReduction = qty.clamp(0.0, currentReserved);

        transaction.update(docRef, {
          'stock': (currentStock - safeQtyToDeduct).clamp(0.0, double.infinity),
          'reservedStock': (currentReserved - safeReservedReduction).clamp(0.0, double.infinity),
        });
      });
      return true;
    } catch (e) {
      debugPrint("❌ Error al confirmar deducción de stock: $e");
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

        final safeReduction = qty.clamp(0.0, currentReserved);
        if (safeReduction <= 0) return;

        transaction.update(docRef, {
          'reservedStock': (currentReserved - safeReduction).clamp(0.0, double.infinity),
        });
      });
      return true;
    } catch (e) {
      debugPrint("❌ Error al cancelar reserva: $e");
      return false;
    }
  }

  /// REEMBOLSAR STOCK (retrocesos de E6 a E5)
  Future<bool> refundStock(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] as num?)?.toDouble() ?? 0.0;

        transaction.update(docRef, {
          'stock': currentStock + qty,
        });
      });
      return true;
    } catch (e) {
      debugPrint("❌ Error al reembolsar stock: $e");
      return false;
    }
  }
}