import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ici_process/models/user_model.dart';
import 'package:ici_process/services/auth_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Paleta de Colores Premium
  final Color primaryBlue = const Color(0xFF3B82F6);
  final Color accentBlue = const Color(0xFF60A5FA);
  final Color bgDark = const Color(0xFF0F172A);
  final Color cardWhite = const Color(0xFFFFFFFF);

  final AuthService _authService = AuthService(); // Instancia del servicio

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "Por favor, llena todos los campos.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserModel? user = await _authService.signIn(
        _emailController.text,
        _passwordController.text,
      );

      if (user != null) {
        // ¡Éxito! Aquí rediriges según el rol
        print("Bienvenido ${user.name} con rol ${user.role}");

        // Ejemplo de navegación basada en rol:
        // if (user.role == SystemRoles.admin) Navigator.pushReplacementNamed(context, '/admin');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found')
          _errorMessage = "Usuario no registrado.";
        else if (e.code == 'wrong-password')
          _errorMessage = "Contraseña incorrecta.";
        else
          _errorMessage = "Error de autenticación.";
      });
    } catch (e) {
      setState(() => _errorMessage = "Ocurrió un error inesperado.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Elementos Decorativos de Fondo (Luces)
          Positioned(
            top: -100,
            right: -100,
            child: _buildBlurCircle(accentBlue.withOpacity(0.2), 300),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBlurCircle(primaryBlue.withOpacity(0.15), 250),
          ),

          // 2. Contenido Principal
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildLoginCard(),
                  const SizedBox(height: 32),
                  _buildFooterText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(LucideIcons.shieldCheck, size: 54, color: accentBlue),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "ICI PROCESS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "GESTIÓN EMPRESARIAL INTEGRAL",
          style: TextStyle(
            color: Colors.blueGrey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Iniciar Sesión",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Bienvenido de nuevo. Por favor, ingresa tus datos corporativos.",
            style: TextStyle(
              color: Colors.blueGrey[400],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          _buildInputField(
            label: "CORREO ELECTRÓNICO",
            controller: _emailController,
            icon: LucideIcons.mail,
            hint: "usuario@iciprocess.com",
          ),
          const SizedBox(height: 24),
          _buildInputField(
            label: "CONTRASEÑA",
            controller: _passwordController,
            icon: LucideIcons.lock,
            hint: "••••••••",
            isPassword: true,
          ),

          if (_errorMessage != null) _buildErrorSection(),

          const SizedBox(height: 40),
          _buildAnimatedButton(),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            prefixIcon: Icon(icon, size: 20, color: primaryBlue),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryBlue.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Entrar al Sistema",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 12),
                  Icon(LucideIcons.arrowRight, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[100]!),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: Colors.red, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Column(
      children: [
        TextButton(
          onPressed: () {},
          child: Text(
            "Recuperar Contraseña",
            style: TextStyle(
              color: Colors.blueGrey[200],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "© 2026 ICI Process S.A. de C.V.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
