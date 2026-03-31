import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_model.dart';

class WorkerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Referencia a la colección 'users' (la misma que ya usas)
  CollectionReference get _usersRef => _db.collection('users');

  // ─────────────────────────────────────────────────────────
  // 1. LEER — Solo usuarios con role == 'technician'
  // ─────────────────────────────────────────────────────────
  Stream<List<Worker>> getWorkers() {
    return _usersRef
        .where('role', isEqualTo: 'technician')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Worker.fromFirestore(doc)).toList();
    });
  }

  // ─────────────────────────────────────────────────────────
  // 2. ACTUALIZAR — Solo los campos extra (NSS, CURP, etc.)
  //    No toca name/email/role para no romper tu UserModel
  // ─────────────────────────────────────────────────────────
  Future<void> updateWorkerDetails(Worker worker) async {
    try {
      await _usersRef.doc(worker.id).update(worker.toExtraFieldsMap());
      print("✅ Datos del trabajador actualizados: ${worker.name}");
    } catch (e) {
      print("❌ Error al actualizar trabajador: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 3. CREAR — Crea un documento nuevo en 'users' con role=technician
  //    (Para trabajadores que NO necesitan login, solo registro)
  // ─────────────────────────────────────────────────────────
  Future<void> addWorker(Worker worker) async {
    try {
      await _usersRef.add(worker.toFullMap());
      print("✅ Trabajador registrado: ${worker.name}");
    } catch (e) {
      print("❌ Error al registrar trabajador: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 4. ELIMINAR — Borra el documento de 'users'
  //    ⚠️ Esto también elimina su acceso al sistema si tenía cuenta
  // ─────────────────────────────────────────────────────────
  Future<void> deleteWorker(String id) async {
    try {
      await _usersRef.doc(id).delete();
      print("✅ Trabajador eliminado: $id");
    } catch (e) {
      print("❌ Error al eliminar trabajador: $e");
      rethrow;
    }
  }
}