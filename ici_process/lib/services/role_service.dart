import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/role_model.dart';

class RoleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'roles';

  static const String superAdminId = 'superAdmin';

  static const List<RoleModel> _defaultRoles = [
    RoleModel(
      id: 'superAdmin',
      displayName: 'Super Admin',
      colorHex: '#312E81',
      iconKey: 'shieldAlert',
    ),
    RoleModel(
      id: 'admin',
      displayName: 'Administrador',
      colorHex: '#1E40AF',
      iconKey: 'shield',
    ),
    RoleModel(
      id: 'manager',
      displayName: 'Gerente Operativo',
      colorHex: '#0369A1',
      iconKey: 'briefcase',
    ),
    RoleModel(
      id: 'technician',
      displayName: 'Técnico',
      colorHex: '#0D9488',
      iconKey: 'wrench',
    ),
    RoleModel(
      id: 'purchasing',
      displayName: 'Compras',
      colorHex: '#B45309',
      iconKey: 'shoppingCart',
    ),
    RoleModel(
      id: 'accountant',
      displayName: 'Contador',
      colorHex: '#059669',
      iconKey: 'dollarSign',
    ),
  ];

  CollectionReference<Map<String, dynamic>> get _rolesRef =>
      _db.collection(_collection);

  Stream<List<RoleModel>> getRolesStream() {
    return _rolesRef.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => RoleModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        if (a.id == superAdminId) return -1;
        if (b.id == superAdminId) return 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
      return list;
    });
  }

  Future<List<RoleModel>> getRolesOnce() async {
    final snap = await _rolesRef.get();
    return snap.docs
        .map((doc) => RoleModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<RoleModel?> getRoleById(String id) async {
    final doc = await _rolesRef.doc(id).get();
    if (!doc.exists) return null;
    return RoleModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> createRole(RoleModel role) async {
    final trimmedId = role.id.trim();
    if (trimmedId.isEmpty) {
      throw Exception('El identificador del rol no puede estar vacío.');
    }
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(trimmedId)) {
      throw Exception(
          'El ID del rol debe iniciar con letra y solo contener letras, números o guiones bajos.');
    }

    final existing = await _rolesRef.doc(trimmedId).get();
    if (existing.exists) {
      throw Exception('Ya existe un rol con ese identificador.');
    }

    await _rolesRef.doc(trimmedId).set(role.copyWith(id: trimmedId).toMap());
  }

  Future<void> updateRole(RoleModel role) async {
    await _rolesRef.doc(role.id).set(role.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteRole(String id) async {
    if (id == superAdminId) {
      throw Exception('El rol Super Admin no se puede eliminar.');
    }

    final usersWithRole = await _db
        .collection('users')
        .where('role', isEqualTo: id)
        .limit(1)
        .get();
    if (usersWithRole.docs.isNotEmpty) {
      throw Exception(
          'No se puede eliminar: hay usuarios asignados a este rol. Reasígnalos primero.');
    }

    await _rolesRef.doc(id).delete();

    await _db
        .collection('system_config')
        .doc('role_permissions')
        .update({id: FieldValue.delete()}).catchError((_) {});
  }

  Future<void> ensureDefaultRolesSeeded() async {
    final snap = await _rolesRef.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final role in _defaultRoles) {
      batch.set(_rolesRef.doc(role.id), role.toMap());
    }
    await batch.commit();
  }
}
