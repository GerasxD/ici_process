import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/process_model.dart';
import '../core/constants/app_constants.dart';

class ProcessService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'processes';

  // ── Genera el siguiente ID correlativo (PR-01, PR-02...) ──
  Future<String> _generateProcessId() async {
    final counterRef = _db.collection('counters').doc('processes');

    return await _db.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int nextNumber = 1;
      if (snapshot.exists) {
        nextNumber = (snapshot.data()?['lastNumber'] ?? 0) + 1;
      }

      transaction.set(counterRef, {'lastNumber': nextNumber});

      // Formato: PR-01, PR-02 ... PR-99, PR-100
      final padded = nextNumber.toString().padLeft(2, '0');
      return 'PR-$padded';
    });
  }

  // 1. Obtener todos los procesos en tiempo real
  Stream<List<ProcessModel>> getProcessesStream({String? currentUserId, String? currentUserRole}) {
    return _db
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final allProcesses = snapshot.docs
          .map((doc) => ProcessModel.fromMap(doc.data(), doc.id))
          .toList();

      if (currentUserId == null) return allProcesses;

      // Superadmin ve todo
      // ── Solo SuperAdmin ve TODOS los procesos (incluidos privados) ──
      // Los admin ya NO tienen acceso automático; deben estar en visibleToUserIds
      final roleLower = (currentUserRole ?? '').toLowerCase();
      if (roleLower == 'superadmin') return allProcesses;

      return allProcesses.where((p) {
        // Procesos públicos: todos los ven
        if (!p.isPrivate) return true;
        // Proceso privado: solo creador o usuarios autorizados
        if (p.createdByUserId == currentUserId) return true;
        return p.visibleToUserIds.contains(currentUserId);
      }).toList();
    });
  }

  // 2. Crear un nuevo proceso con ID correlativo
  Future<void> createProcess(ProcessModel process) async {
    try {
      final newId = await _generateProcessId();

      // Creamos el proceso con el ID generado usando .doc(id).set()
      await _db
          .collection(_collection)
          .doc(newId)
          .set(process.toMap());
    } catch (e) {
      print("Error al crear proceso: $e");
      rethrow;
    }
  }

  // 3. Actualizar un proceso existente
  Future<void> updateProcess(ProcessModel process) async {
    try {
      await _db
          .collection(_collection)
          .doc(process.id)
          .update(process.toMap());
    } catch (e) {
      print("Error al actualizar proceso: $e");
      rethrow;
    }
  }

  // 4. Mover de Etapa
  Future<void> moveProcessStage({
    required String processId,
    required ProcessStage newStage,
    required String userName,
    required String stageTitle,
  }) async {
    try {
      final historyEntry = {
        'action': 'Cambio de Etapa',
        'userName': userName,
        'date': Timestamp.now(),
        'details': 'Movido a $stageTitle',
      };
      await _db.collection(_collection).doc(processId).update({
        'stage': newStage.toString().split('.').last,
        'updatedAt': Timestamp.now(),
        'history': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      print("Error al mover etapa: $e");
      rethrow;
    }
  }

  // 5. Eliminar proceso permanentemente
  Future<void> deleteProcess(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  // 6. Obtener un proceso por ID
  Future<ProcessModel?> getProcessById(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return ProcessModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print("Error obteniendo proceso por ID: $e");
      return null;
    }
  }

  // 7. Obtener todos los procesos (snapshot único, no stream)
  Future<List<ProcessModel>> getProcessesOnce() async {
    final snapshot = await _db.collection(_collection).get();
    return snapshot.docs
        .map((doc) => ProcessModel.fromMap(doc.data(), doc.id))
        .toList();
  }
}