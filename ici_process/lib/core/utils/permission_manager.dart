import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../constants/app_constants.dart'; // Donde tengas tu enum UserRole

class PermissionManager {
  // Instancia única (Singleton) para acceder desde cualquier lado
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  // Aquí guardaremos una copia local de los permisos
  Map<String, List<String>> _rolePermissions = {};
  
  // Servicio administrativo
  final AdminService _adminService = AdminService();

  // 1. INICIALIZAR: Llama a esto en tu main.dart o Login
  // Se queda escuchando cambios en tiempo real desde Firebase
  void init() {
    _adminService.getRolePermissions().listen((perms) {
      _rolePermissions = perms;
      print("🔔 Permisos actualizados en tiempo real: $_rolePermissions");
    });
  }

  // 2. VERIFICAR: La función mágica que usarás en tus pantallas
  bool can(UserModel user, String permissionCode) {
    // A. El SuperAdmin SIEMPRE puede hacer todo (God Mode)
    if (user.role == UserRole.superAdmin) return true;

    // B. Obtener el string del rol del usuario (ej: "technician")
    String roleKey = user.role.toString().split('.').last;

    // C. Buscar si ese rol tiene el permiso en la lista
    List<String> allowedPerms = _rolePermissions[roleKey] ?? [];

    return allowedPerms.contains(permissionCode);
  }
}