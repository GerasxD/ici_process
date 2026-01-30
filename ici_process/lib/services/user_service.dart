import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ NECESARIO PARA AUTH
import 'package:firebase_core/firebase_core.dart'; // ✅ NECESARIO PARA APP SECUNDARIA
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Instancia principal para reset pass
  final String _collection = 'users';

  // 1. OBTENER TODOS LOS USUARIOS (STREAM)
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

  // 3. CREAR USUARIO COMPLETO (AUTH + FIRESTORE)
  // ✅ ESTA ES LA FUNCIÓN CLAVE:
  // Usa una "App Secundaria" para crear el usuario sin desloguear al Admin actual.
  Future<void> createUserComplete(UserModel user, String password) async {
    FirebaseApp? tempApp;
    try {
      // A. Crear una instancia temporal de Firebase
      tempApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      // B. Usar esa instancia para crear el usuario en Auth
      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: user.email, password: password);

      // C. Ahora que tenemos el UID real de Auth, preparamos el modelo
      final newUser = UserModel(
        id: cred.user!.uid, // Usamos el ID generado por Auth
        name: user.name,
        email: user.email,
        role: user.role,
        linkedWorkerId: user.linkedWorkerId,
      );

      // D. Guardamos los datos en Firestore
      await _db.collection(_collection).doc(newUser.id).set(newUser.toMap());

      // E. Borramos la app temporal para liberar memoria
      await tempApp.delete();

    } catch (e) {
      print("❌ Error creando usuario completo: $e");
      // Si falla, aseguramos borrar la app temporal si se creó
      if (tempApp != null) await tempApp.delete();
      rethrow;
    }
  }

  // 4. ACTUALIZAR USUARIO (EDICIÓN)
  // He actualizado esto para recibir el UserModel completo, es más fácil de usar
  Future<void> updateUser(UserModel user) async {
    try {
      // Convertimos a mapa para actualizar
      await _db.collection(_collection).doc(user.id).update(user.toMap());
    } catch (e) {
      print("❌ Error al actualizar usuario: $e");
      rethrow;
    }
  }

  // 5. ELIMINAR USUARIO
  // Nota: Esto borra el acceso de la BD. El usuario queda en Auth pero sin datos no podrá entrar a la App.
  Future<void> deleteUser(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      print("❌ Error al eliminar usuario: $e");
      rethrow;
    }
  }

  // 6. ENVIAR CORREO DE RESTABLECER CONTRASEÑA
  // ✅ NUEVA FUNCIÓN
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("❌ Error enviando correo de reset: $e");
      rethrow;
    }
  }
  
  // 7. VERIFICAR PERMISOS (Helper opcional)
  bool canEdit(UserRole userRole, ProcessStage stage) {
    final config = stageConfigs[stage];
    if (config == null) return false;
    return config.editing.contains(userRole);
  }
}