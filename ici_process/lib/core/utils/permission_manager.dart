import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../constants/app_constants.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  Map<String, List<String>> _rolePermissions = {};

  final AdminService _adminService = AdminService();

  void init() {
    _adminService.getRolePermissions().listen((perms) {
      _rolePermissions = perms;
      print("🔔 Permisos actualizados en tiempo real: $_rolePermissions");
    });
  }

  bool can(UserModel user, String permissionCode) {
    // A. El SuperAdmin SIEMPRE puede hacer todo (God Mode)
    if (user.role == SystemRoles.superAdmin) return true;

    // B. Buscar si el rol tiene el permiso en la lista
    final List<String> allowedPerms = _rolePermissions[user.role] ?? [];

    return allowedPerms.contains(permissionCode);
  }
}
