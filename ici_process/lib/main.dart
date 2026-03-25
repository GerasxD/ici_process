import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:ici_process/ui/screens/login_screen.dart';
import 'package:ici_process/ui/screens/main_navigation_screen.dart'; // Tu nueva pantalla
import 'package:ici_process/services/auth_service.dart';
import 'package:ici_process/models/user_model.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ICI Process',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      // El AuthWrapper es ahora el punto de entrada inteligente
      home: const AuthWrapper(), 
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Si está cargando la conexión con Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Si hay un usuario autenticado
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<UserModel?>(
            future: _authService.getCurrentUserData(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (userSnapshot.hasData && userSnapshot.data != null) {
                PermissionManager().init();
                // Enviamos los datos del usuario (con su rol) a la pantalla principal
                return MainNavigationScreen(user: userSnapshot.data!);
              }

              // Si por alguna razón no hay datos en Firestore, cerramos sesión
              return const LoginScreen();
            },
          );
        }

        // 3. Si no hay nadie logueado
        return const LoginScreen();
      },
    );
  }
}