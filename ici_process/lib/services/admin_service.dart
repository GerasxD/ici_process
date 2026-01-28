import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_config_model.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Referencias a documentos de configuración
  DocumentReference get _laborRef => _db.collection('system_config').doc('labor_catalog');
  DocumentReference get _permsRef => _db.collection('system_config').doc('role_permissions');
  DocumentReference get _stagesRef => _db.collection('system_config').doc('stage_config');

  // --- 1. MANO DE OBRA (LABOR) ---
  Stream<List<LaborCategory>> getLaborCategories() {
    return _laborRef.snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      final list = data['categories'] as List<dynamic>? ?? [];
      return list.map((e) => LaborCategory.fromMap(e)).toList();
    });
  }

  Future<void> saveLaborCategories(List<LaborCategory> list) async {
    await _laborRef.set({'categories': list.map((e) => e.toMap()).toList()});
  }

  // --- 2. PERMISOS POR ROL ---
  // Retorna un Mapa: { "admin": ["view_users", "edit_users"], "tecnico": ["view_tasks"] }
  Stream<Map<String, List<String>>> getRolePermissions() {
    return _permsRef.snapshots().map((doc) {
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>;
      // Convertir dynamic a Map<String, List<String>>
      return data.map((key, value) => MapEntry(key, List<String>.from(value)));
    });
  }

  Future<void> updateRolePermissions(String role, List<String> permissions) async {
    await _permsRef.set({role: permissions}, SetOptions(merge: true));
  }

  // --- 3. CONFIGURACIÓN DE ETAPAS ---
  Stream<Map<String, StageConfig>> getStageConfigs() {
    return _stagesRef.snapshots().map((doc) {
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>;
      // Mapear ID de etapa a su configuración
      return data.map((key, value) => MapEntry(key, StageConfig.fromMap(value)));
    });
  }

  Future<void> updateStageConfig(String stageId, StageConfig config) async {
    await _stagesRef.set({stageId: config.toMap()}, SetOptions(merge: true));
  }
}