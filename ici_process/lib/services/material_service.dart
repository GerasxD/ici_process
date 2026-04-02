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

  // ── (Añadir en la sección 1. LEER) ──
  Future<MaterialItem?> getMaterialById(String id) async {
    try {
      final doc = await _materialsRef.doc(id).get();
      if (doc.exists) {
        return MaterialItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print("Error obteniendo material por ID: $e");
      return null;
    }
  }

  // ── (Añadir en la sección 3. ACTUALIZAR) ──
  // Este método recibe un mapa con solo los campos específicos que queremos cambiar,
  // evitando sobreescribir accidentalmente el reservedStock o el stock en tiempo real.
  Future<void> updateMaterialFields(String id, Map<String, dynamic> data) async {
    await _materialsRef.doc(id).update(data);
  }

  // 4. ELIMINAR
  Future<void> deleteMaterial(String id) async {
    await _materialsRef.doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════
  //  SISTEMA DE RESERVA DE STOCK EN 2 FASES (CORREGIDO)
  // ═══════════════════════════════════════════════════════════

  /// FASE 1 — APARTAR STOCK
  /// ★ CAMBIO CRÍTICO: Ahora retorna la CANTIDAD REAL que se apartó,
  /// no solo un bool. Esto resuelve el problema de reserva parcial.
  /// Retorna -1.0 si hubo error.
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

        // ★ Solo apartar lo que realmente hay disponible
        actuallyReserved = qty.clamp(0.0, available);
        if (actuallyReserved <= 0) return; // Nada que apartar

        transaction.update(docRef, {
          'reservedStock': currentReserved + actuallyReserved,
        });
      });

      return actuallyReserved;
    } catch (e) {
      print("❌ Error al reservar stock: $e");
      return -1.0; // Indicador de error
    }
  }

  /// FASE 2 — CONFIRMAR DEDUCCIÓN (al avanzar a E6)
  /// ★ MEJORA: Validación adicional para no descontar más de lo que existe
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

        // ★ SEGURIDAD: No descontar más stock del que existe
        final safeQtyToDeduct = qty.clamp(0.0, currentStock);
        // ★ SEGURIDAD: No reducir reservedStock por debajo de 0
        final safeReservedReduction = qty.clamp(0.0, currentReserved);

        transaction.update(docRef, {
          'stock': (currentStock - safeQtyToDeduct).clamp(0.0, double.infinity),
          'reservedStock': (currentReserved - safeReservedReduction).clamp(0.0, double.infinity),
        });
      });
      return true;
    } catch (e) {
      print("❌ Error al confirmar deducción de stock: $e");
      return false;
    }
  }

  /// CANCELAR RESERVA
  /// ★ MEJORA: Validación para no reducir por debajo de 0
  Future<bool> cancelReservation(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final currentReserved = (data['reservedStock'] as num?)?.toDouble() ?? 0.0;

        // ★ SEGURIDAD: No cancelar más de lo que realmente hay reservado
        final safeReduction = qty.clamp(0.0, currentReserved);
        if (safeReduction <= 0) return;

        transaction.update(docRef, {
          'reservedStock': (currentReserved - safeReduction).clamp(0.0, double.infinity),
        });
      });
      return true;
    } catch (e) {
      print("❌ Error al cancelar reserva: $e");
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// REEMBOLSAR STOCK (Para retrocesos de E6 a E5)
  /// ═══════════════════════════════════════════════════════════
  Future<bool> refundStock(String materialId, double qty) async {
    if (qty <= 0 || materialId.isEmpty) return false;

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _materialsRef.doc(materialId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return; 

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] as num?)?.toDouble() ?? 0.0;

        // ★ FIX: Solo sumamos al stock total. NO tocamos el reservedStock.
        // Esto hace que el material quede 100% libre y disponible en el almacén.
        transaction.update(docRef, {
          'stock': currentStock + qty,
        });
      });
      return true;
    } catch (e) {
      print("❌ Error al reembolsar stock: $e");
      return false;
    }
  }

}