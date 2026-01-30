import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/process_model.dart';
import '../core/constants/app_constants.dart';

class ProcessService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'processes';

  // 1. Obtener todos los procesos en tiempo real (Para el Kanban)
  Stream<List<ProcessModel>> getProcessesStream() {
    return _db
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProcessModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // 2. Crear un nuevo proceso
  Future<void> createProcess(ProcessModel process) async {
    try {
      await _db.collection(_collection).add(process.toMap());
    } catch (e) {
      print("Error al crear proceso: $e");
      rethrow;
    }
  }

  // 3. Actualizar un proceso existente (Guardar cambios del Modal)
  Future<void> updateProcess(ProcessModel process) async {
    try {
      await _db.collection(_collection).doc(process.id).update(process.toMap());
    } catch (e) {
      print("Error al actualizar proceso: $e");
      rethrow;
    }
  }

  // 4. Mover de Etapa (Lógica rápida para arrastrar en Kanban)
  // Esta función añade automáticamente una entrada al historial
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

  // 5. Eliminar proceso (Mover a Etapa X o borrar permanente)
  Future<void> deleteProcess(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  // --- AGREGA ESTO EN TU ProcessService ---

  // Obtener un solo proceso por ID (Para recargar datos frescos)
  Future<ProcessModel?> getProcessById(String id) async {
    try {
      final doc = await _db.collection('processes').doc(id).get();
      if (doc.exists && doc.data() != null) {
        // Asegúrate de que tu ProcessModel tenga el factory .fromMap
        return ProcessModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print("Error obteniendo proceso por ID: $e");
      return null;
    }
  }
  
}