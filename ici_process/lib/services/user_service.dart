import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'users';

  // 1. OBTENER TODOS LOS USUARIOS (STREAM)
  // Escucha cambios en tiempo real para la tabla de usuarios
  Stream<List<UserModel>> getUsersStream() {
    return _db.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // 2. OBTENER UN SOLO USUARIO
  Future<UserModel?> getUserById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // 3. CREAR USUARIO (Solo Datos en Firestore)
  // Nota: Para la autenticación real (Login), se usa FirebaseAuth. 
  // Esta función guarda los datos del perfil (Rol, Nombre, etc).
  Future<void> createUserFirestore(UserModel user) async {
    try {
      // Usamos .set con el ID del usuario (usualmente el UID de Auth)
      await _db.collection(_collection).doc(user.id).set(user.toMap());
    } catch (e) {
      print("Error al crear usuario en DB: $e");
      rethrow;
    }
  }

  // 4. ACTUALIZAR USUARIO (Roles, Vinculación, etc.)
  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    try {
      // Si estamos actualizando el ROL, debemos convertir el Enum a String
      if (data.containsKey('role') && data['role'] is UserRole) {
        data['role'] = data['role'].toString().split('.').last;
      }

      await _db.collection(_collection).doc(id).update(data);
    } catch (e) {
      print("Error al actualizar usuario: $e");
      rethrow;
    }
  }

  // 5. ELIMINAR USUARIO
  Future<void> deleteUser(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      print("Error al eliminar usuario: $e");
      rethrow;
    }
  }
  
  // 6. VERIFICAR PERMISOS (Helper opcional)
  bool canEdit(UserRole userRole, ProcessStage stage) {
    // Busca en tu configuración si este rol puede editar esta etapa
    final config = stageConfigs[stage];
    if (config == null) return false;
    return config.editing.contains(userRole);
  }
}