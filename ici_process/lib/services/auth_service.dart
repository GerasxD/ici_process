import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener el usuario actual como Stream para saber si está logueado o no
  Stream<User?> get userStatus => _auth.authStateChanges();

  // Iniciar Sesión con Email y Contraseña
  Future<UserModel?> signIn(String email, String password) async {
    try {
      // 1. Autenticar en Firebase Auth
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;

      if (user != null) {
        // 2. Traer los datos del perfil (Rol, Nombre) desde la colección 'users'
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }
      }
      return null;
    } catch (e) {
      rethrow; // Lanzamos el error para atraparlo en la UI (LoginScreen)
    }
  }

  // Cerrar Sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obtener datos del usuario logueado actualmente
  Future<UserModel?> getCurrentUserData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    }
    return null;
  }
}