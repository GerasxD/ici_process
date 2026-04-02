import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/admin_config_model.dart';
import '../../services/user_service.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';

class AdminPanelScreen extends StatefulWidget {
  final UserModel currentUser;
  const AdminPanelScreen({super.key, required this.currentUser});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final UserService _userService = UserService();
  
  late TabController _tabController;
  String _selectedRoleForEdit = UserRole.admin.name;

  // Mapa de traducción para los grupos de permisos
  final Map<String, String> _groupTitles = {
    'General': 'General y Flujo',
    'Ver Base de Datos': 'Visibilidad de Módulos (Lectura)',
    'Editar Base de Datos': 'Gestión de Módulos (Escritura)',
  };

  // Mapa de permisos técnicos a Español
  final Map<String, String> _permissionLabels = {
    'view_dashboard': 'Ver Panel de Control',
    'manage_users': 'Administrar Usuarios',
    'view_budget': 'Ver Reportes',
    'move_stage': 'Mover Etapas (Kanban)',
    'view_clients': 'Ver Clientes',
    'view_providers': 'Ver Proveedores',
    'view_materials': 'Ver Materiales',
    'view_tools': 'Ver Herramientas',
    'view_vehicles': 'Ver Vehículos',
    'edit_clients': 'Editar/Crear Clientes',
    'edit_providers': 'Editar/Crear Proveedores',
    'edit_materials': 'Editar/Crear Materiales',
    'edit_tools': 'Editar/Crear Herramientas',
    'edit_vehicles': 'Editar/Crear Vehículos',
    'view_workers': 'Ver Personal / Trabajadores',    // ← NUEVO
    'edit_workers': 'Editar/Crear Trabajadores',  
    'view_financials': 'Ver Resumen Financiero (Costos/Precios)',
  };

  // Estructura original de permisos
  final Map<String, List<String>> _permissionGroups = {
    'General': ['view_dashboard', 'manage_users', 'view_budget', 'move_stage'],
    'Ver Base de Datos': ['view_clients', 'view_providers', 'view_materials', 'view_tools', 'view_vehicles','view_workers','view_financials',],
    'Editar Base de Datos': ['edit_clients', 'edit_providers', 'edit_materials', 'edit_tools', 'edit_vehicles','edit_workers',],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _UsersTab(userService: _userService, currentUser: widget.currentUser),
                _RolesTab(
                  adminService: _adminService, 
                  selectedRole: _selectedRoleForEdit,
                  permissionGroups: _permissionGroups,
                  groupTitles: _groupTitles,
                  permissionLabels: _permissionLabels,
                  onRoleChanged: (r) => setState(() => _selectedRoleForEdit = r),
                ),
                _CatalogsTab(adminService: _adminService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row( // <-- ROW PROTEGIDO
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded( // <-- EVITA QUE EL TÍTULO HAGA OVERFLOW
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.settings, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded( // <-- PERMITE QUE LOS TEXTOS SE ADAPTEN O SE CORTEN
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Centro de Administración", 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.5)
                          ),
                          Text(
                            "Gestión de usuarios, permisos y catálogos globales.", 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              padding: const EdgeInsets.all(4),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                // LOS FLEXIBLE PROTEGEN LOS TEXTOS DENTRO DE LOS TABS SI LA PANTALLA ES PEQUEÑA
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.users, size: 18), SizedBox(width: 8), Flexible(child: Text("Usuarios", overflow: TextOverflow.ellipsis))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.shieldCheck, size: 18), SizedBox(width: 8), Flexible(child: Text("Roles y Permisos", overflow: TextOverflow.ellipsis))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.banknote, size: 18), SizedBox(width: 8), Flexible(child: Text("Salarios", overflow: TextOverflow.ellipsis))])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. PESTAÑA DE USUARIOS (AGREGAR, EDITAR, ELIMINAR, AUTH)
// -----------------------------------------------------------------------------
class _UsersTab extends StatefulWidget {
  final UserService userService;
  final UserModel currentUser;

  const _UsersTab({required this.userService, required this.currentUser});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  bool _isProcessing = false;

  // --- LÓGICA: ELIMINAR USUARIO ---
  Future<void> _handleDeleteUser(UserModel user) async {
    if (user.id == widget.currentUser.id) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Usuario?"),
        content: Text("Se eliminará el acceso de ${user.name} al sistema."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.userService.deleteUser(user.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario eliminado"), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // --- LÓGICA: RESTABLECER CONTRASEÑA ---
  Future<void> _handleResetPassword(String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Restablecer Contraseña?"),
        content: Text("Se enviará un correo a $email para que el usuario genere una nueva contraseña."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Enviar Correo"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.userService.sendPasswordResetEmail(email);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Correo de recuperación enviado"), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // --- LÓGICA: CREAR O EDITAR USUARIO ---
  void _showUserDialog({UserModel? userToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserFormDialog(
        userToEdit: userToEdit,
        onSave: (user, password) async {
          try {
            setState(() => _isProcessing = true);
            
            if (userToEdit == null) {
              // CREAR: Usamos el método completo (Auth + DB)
              await widget.userService.createUserComplete(user, password!);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario creado y vinculado"), backgroundColor: Colors.green));
            } else {
              // EDITAR: Solo actualizamos DB
              await widget.userService.updateUser(user);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Datos actualizados"), backgroundColor: Colors.green));
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
          } finally {
            if (mounted) setState(() => _isProcessing = false);
          }
        },
      ),
    );
  }

  Map<String, dynamic> _getRoleStyle(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin': return {'text': 'Super Admin', 'bg': const Color(0xFF312E81), 'fg': Colors.white};
      case 'admin': return {'text': 'Administrador', 'bg': const Color(0xFF1E40AF), 'fg': Colors.white};
      case 'manager': return {'text': 'Gerente Operativo', 'bg': const Color(0xFF0369A1), 'fg': Colors.white};
      case 'technician': return {'text': 'Técnico', 'bg': const Color(0xFF0D9488), 'fg': Colors.white};
      case 'purchasing': return {'text': 'Compras', 'bg': const Color(0xFFB45309), 'fg': Colors.white};
      case 'accountant': return {'text': 'Contador', 'bg': const Color(0xFF059669), 'fg': Colors.white};
      default: return {'text': role, 'bg': Colors.grey, 'fg': Colors.white};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap( // <-- CAMBIO DE ROW A WRAP
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Text("Directorio de Usuarios", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _showUserDialog(),
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: const Text("Nuevo Usuario"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB), 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: widget.userService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final users = snapshot.data ?? [];

                if (users.isEmpty) return const Center(child: Text("No hay usuarios registrados"));

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final roleStyle = _getRoleStyle(user.role.toString().split('.').last);
                    final isMe = user.id == widget.currentUser.id;
                    final isSuper = widget.currentUser.role == UserRole.superAdmin;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  children: [
                                    Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                                    if (isMe) ...[
                                      const SizedBox(width: 8),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text("TÚ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)))
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(user.email, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: roleStyle['bg'].withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: roleStyle['bg'].withOpacity(0.2))),
                            child: Text(roleStyle['text'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: roleStyle['bg'])),
                          ),
                          const SizedBox(width: 24),
                          
                          // --- BOTONES DE ACCIÓN ---
                          if (isSuper || isMe) // Admin puede editar a todos, Usuario solo a sí mismo (limitado)
                            IconButton(
                              icon: const Icon(LucideIcons.edit3, size: 20, color: Colors.blue),
                              tooltip: "Editar Datos",
                              onPressed: () => _showUserDialog(userToEdit: user),
                            ),
                          
                          if (isSuper) ...[ // Solo SuperAdmin tiene estas opciones avanzadas
                            IconButton(
                              icon: const Icon(LucideIcons.key, size: 20, color: Colors.orange),
                              tooltip: "Enviar Reset Password",
                              onPressed: () => _handleResetPassword(user.email),
                            ),
                            if (!isMe)
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 20, color: Color(0xFFEF4444)),
                                tooltip: "Eliminar Usuario",
                                onPressed: () => _handleDeleteUser(user),
                              )
                          ]
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FORMULARIO INTELIGENTE (CREAR Y EDITAR)
// -----------------------------------------------------------------------------
class _UserFormDialog extends StatefulWidget {
  final UserModel? userToEdit;
  final Function(UserModel, String?) onSave;

  const _UserFormDialog({this.userToEdit, required this.onSave});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.technician;
  bool _obscurePassword = true;

  bool get isEditing => widget.userToEdit != null;

  // Config visual por rol
  Map<String, dynamic> _getRoleConfig(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return {'label': 'Super Admin', 'color': const Color(0xFF312E81), 'icon': LucideIcons.shieldAlert};
      case UserRole.admin:
        return {'label': 'Administrador', 'color': const Color(0xFF1E40AF), 'icon': LucideIcons.shield};
      case UserRole.manager:
        return {'label': 'Gerente Operativo', 'color': const Color(0xFF0369A1), 'icon': LucideIcons.briefcase};
      case UserRole.technician:
        return {'label': 'Técnico', 'color': const Color(0xFF0D9488), 'icon': LucideIcons.wrench};
      case UserRole.purchasing:
        return {'label': 'Compras', 'color': const Color(0xFFB45309), 'icon': LucideIcons.shoppingCart};
      case UserRole.accountant:
        return {'label': 'Contador', 'color': const Color(0xFF059669), 'icon': LucideIcons.dollarSign};
      // ignore: unreachable_switch_default
      default:
        return {'label': role.name, 'color': Colors.grey, 'icon': LucideIcons.user};
    }
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text = widget.userToEdit!.name;
      _emailCtrl.text = widget.userToEdit!.email;
      _selectedRole = widget.userToEdit!.role;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final user = UserModel(
        id: isEditing ? widget.userToEdit!.id : '',
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: _selectedRole,
      );
      widget.onSave(user, isEditing ? null : _passwordCtrl.text.trim());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleConfig = _getRoleConfig(_selectedRole);
    final Color roleColor = roleConfig['color'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── HEADER con gradiente ──────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F172A),
                      const Color(0xFF1E293B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    // Avatar con inicial (si es edición)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isEditing ? roleColor : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isEditing ? roleColor : const Color(0xFF2563EB)).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isEditing
                            ? Text(
                                widget.userToEdit!.name.isNotEmpty
                                    ? widget.userToEdit!.name[0].toUpperCase()
                                    : 'U',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Icon(LucideIcons.userPlus, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? "Editar Usuario" : "Nuevo Usuario",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEditing
                                ? "Modifica los datos del usuario"
                                : "Completa el formulario para registrar acceso",
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // ── CONTENIDO ────────────────────────────────────────────
              Flexible( // <-- 1. FLEXIBLE EVITA QUE LA COLUMNA SE DESBORDE
                child: SingleChildScrollView( // <-- 2. PERMITE HACER SCROLL SI ES NECESARIO
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Nombre completo
                      _buildLabel("Nombre Completo"),
                      const SizedBox(height: 8),
                      _buildField(
                        controller: _nameCtrl,
                        hint: "Ej. Carlos Ramírez",
                        icon: LucideIcons.user,
                        validator: (v) => (v == null || v.isEmpty) ? "Campo obligatorio" : null,
                      ),

                      const SizedBox(height: 20),

                      // Correo
                      _buildLabel("Correo Electrónico"),
                      const SizedBox(height: 8),
                      _buildField(
                        controller: _emailCtrl,
                        hint: "usuario@empresa.com",
                        icon: LucideIcons.mail,
                        enabled: !isEditing,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Campo obligatorio";
                          if (!v.contains('@')) return "Correo inválido";
                          return null;
                        },
                      ),

                      // Aviso si está deshabilitado
                      if (isEditing) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.info, size: 13, color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                            Expanded( // <-- Previene overflow si este texto se vuelve muy largo
                              child: Text(
                                "El correo no puede modificarse. Usa Reset Password para cambiar contraseña.",
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.amber.shade800),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Contraseña (solo en creación)
                      if (!isEditing) ...[
                        const SizedBox(height: 20),
                        _buildLabel("Contraseña Inicial"),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Campo obligatorio";
                            if (v.length < 6) return "Mínimo 6 caracteres";
                            return null;
                          },
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: "Mínimo 6 caracteres",
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: Icon(LucideIcons.lock, size: 18, color: Colors.grey.shade400),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                size: 18,
                                color: Colors.grey.shade400,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Selector de Rol ──────────────────────────────
                      _buildLabel("Rol del Sistema"),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: UserRole.values.map((role) {
                          final config = _getRoleConfig(role);
                          final Color color = config['color'];
                          final bool isSelected = _selectedRole == role;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedRole = role),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? color : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? color : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    config['icon'],
                                    size: 15,
                                    color: isSelected ? Colors.white : color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    config['label'],
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Preview del rol seleccionado
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: roleColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(roleConfig['icon'], size: 16, color: roleColor),
                            const SizedBox(width: 10),
                            Text(
                              "Acceso asignado como: ",
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              roleConfig['label'],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: roleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── FOOTER ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          "Cancelar",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                          isEditing ? LucideIcons.save : LucideIcons.userPlus,
                          size: 18,
                        ),
                        label: Text(
                          isEditing ? "Guardar Cambios" : "Crear Usuario",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. PESTAÑA DE ROLES (Diseño Sidebar + Switches)
// -----------------------------------------------------------------------------
// EN: lib/ui/screens/admin_panel_screen.dart

class _RolesTab extends StatelessWidget {
  final AdminService adminService;
  final String selectedRole;
  final Map<String, List<String>> permissionGroups;
  final Map<String, String> groupTitles;
  final Map<String, String> permissionLabels;
  final Function(String) onRoleChanged;

  const _RolesTab({
    required this.adminService,
    required this.selectedRole,
    required this.permissionGroups,
    required this.groupTitles,
    required this.permissionLabels,
    required this.onRoleChanged,
  });

  String _translateRole(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin': return 'Super Admin';
      case 'admin': return 'Administrador';
      case 'technician': return 'Técnico';
      case 'manager': return 'Gerente Operativo';
      case 'purchasing': return 'Compras';
      case 'accountant': return 'Contador';
      default: return role;
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin': return const Color(0xFF312E81);
      case 'admin': return const Color(0xFF1E40AF);
      case 'manager': return const Color(0xFF0369A1);
      case 'technician': return const Color(0xFF0D9488);
      case 'purchasing': return const Color(0xFFB45309);
      case 'accountant': return const Color(0xFF059669);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin': return LucideIcons.shieldAlert;
      case 'admin': return LucideIcons.shield;
      case 'manager': return LucideIcons.briefcase;
      case 'technician': return LucideIcons.wrench;
      case 'purchasing': return LucideIcons.shoppingCart;
      case 'accountant': return LucideIcons.dollarSign;
      default: return LucideIcons.user;
    }
  }

  void _togglePermission(List<String> currentPerms, String code, bool active) {
    final newPerms = List<String>.from(currentPerms);
    if (active) {
      if (!newPerms.contains(code)) newPerms.add(code);
    } else {
      newPerms.remove(code);
    }
    adminService.updateRolePermissions(selectedRole, newPerms);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, List<String>>>(
      stream: adminService.getRolePermissions(),
      builder: (context, snapshot) {
        final allPermissions = snapshot.data ?? {};
        final currentRolePerms = allPermissions[selectedRole] ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;

            if (isWide) {
              return _buildDesktopLayout(currentRolePerms);
            } else {
              return _buildMobileLayout(currentRolePerms);
            }
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DESKTOP: Sidebar + Content (tu diseño original)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(List<String> currentRolePerms) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text("SELECCIONAR ROL",
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1.0)),
              const SizedBox(height: 16),
              ...UserRole.values.map((roleEnum) {
                final roleStr = roleEnum.toString().split('.').last;
                final isSelected = roleStr == selectedRole;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onRoleChanged(roleStr),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _translateRole(roleStr),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                          if (isSelected)
                            const Icon(LucideIcons.chevronRight, size: 16, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _buildPermissionsContent(currentRolePerms, horizontalPadding: 40),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MOBILE: Chips selector arriba + Content abajo
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(List<String> currentRolePerms) {
    final color = _roleColor(selectedRole);

    return Column(
      children: [
        // ── Selector de rol horizontal ────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    Icon(_roleIcon(selectedRole), size: 18, color: color),
                    const SizedBox(width: 10),
                    Text(
                      "Rol: ${_translateRole(selectedRole)}",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: UserRole.values.map((roleEnum) {
                    final roleStr = roleEnum.toString().split('.').last;
                    final isSelected = roleStr == selectedRole;
                    final rColor = _roleColor(roleStr);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onRoleChanged(roleStr),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? rColor : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? rColor : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _roleIcon(roleStr),
                                size: 14,
                                color: isSelected ? Colors.white : rColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _translateRole(roleStr),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ── Contenido de permisos ─────────────────────────────
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _buildPermissionsContent(currentRolePerms, horizontalPadding: 16),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONTENIDO COMPARTIDO (permisos + tabla de etapas)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPermissionsContent(List<String> currentRolePerms, {double horizontalPadding = 40}) {
    return ListView(
      padding: EdgeInsets.all(horizontalPadding),
      children: [
        // Título
        Row(
          children: [
            const Icon(LucideIcons.shieldCheck, size: 24, color: Color(0xFF0F172A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Configuración de Permisos",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A))),
                  Text("Rol: ${_translateRole(selectedRole)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Grupos de permisos (Switches) ─────────────────────
        ...permissionGroups.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Text(
                    groupTitles[entry.key] ?? entry.key,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155)),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ...entry.value.map((perm) {
                  final isChecked = currentRolePerms.contains(perm);
                  return SwitchListTile.adaptive(
                    title: Text(
                      permissionLabels[perm] ?? perm,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
                    ),
                    value: isChecked,
                    activeColor: const Color(0xFF2563EB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    onChanged: (val) => _togglePermission(currentRolePerms, perm, val),
                  );
                }),
                const SizedBox(height: 6),
              ],
            ),
          );
        }),

        // ── Tabla de etapas ───────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(LucideIcons.folderKanban, size: 16, color: Color(0xFF334155)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "ACCESO POR ETAPAS",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Cabecera
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text("ETAPA",
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.5)),
                    ),
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: Text("VER",
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.5)),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: Text("EDIT",
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Filas de etapas
              ...ProcessStage.values.map((stage) {
                final stageName = stage.toString().split('.').last;
                final viewCode = 'stage_view_$stageName';
                final editCode = 'stage_edit_$stageName';
                final canView = currentRolePerms.contains(viewCode);
                final canEdit = currentRolePerms.contains(editCode);
                final config = stageConfigs[stage];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: config?.textColor ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                config?.title ?? stageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: canView,
                              activeColor: const Color(0xFF2563EB),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) =>
                                  _togglePermission(currentRolePerms, viewCode, val ?? false),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: canEdit,
                              activeColor: const Color(0xFF16A34A),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) {
                                if (val == true && !canView) {
                                  final tempPerms = List<String>.from(currentRolePerms)
                                    ..add(viewCode);
                                  _togglePermission(tempPerms, editCode, true);
                                } else {
                                  _togglePermission(currentRolePerms, editCode, val ?? false);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 3. PESTAÑA DE CATÁLOGOS (Diseño Grid Moderno - CORREGIDO SIN OVERFLOW)
// -----------------------------------------------------------------------------
class _CatalogsTab extends StatefulWidget {
  final AdminService adminService;
  const _CatalogsTab({required this.adminService});

  @override
  State<_CatalogsTab> createState() => _CatalogsTabState();
}

class _CatalogsTabState extends State<_CatalogsTab> {
  void _addNewLabor(List<LaborCategory> currentList) {
    final newItem = LaborCategory(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      name: 'Nuevo Puesto', 
      baseDailySalary: 0
    );
    final newList = [...currentList, newItem];
    widget.adminService.saveLaborCategories(newList);
  }

  void _updateLabor(List<LaborCategory> currentList, int index, String field, dynamic val) {
    final item = currentList[index];
    final updatedItem = LaborCategory(
      id: item.id,
      name: field == 'name' ? val : item.name,
      baseDailySalary: field == 'salary' ? (double.tryParse(val.toString()) ?? 0) : item.baseDailySalary,
    );
    final newList = List<LaborCategory>.from(currentList);
    newList[index] = updatedItem;
    widget.adminService.saveLaborCategories(newList);
  }

  void _deleteLabor(List<LaborCategory> currentList, int index) {
    final newList = List<LaborCategory>.from(currentList);
    newList.removeAt(index);
    widget.adminService.saveLaborCategories(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // CONTENT - CORREGIDO: GridView con SingleChildScrollView
        Expanded(
          child: StreamBuilder<List<LaborCategory>>(
            stream: widget.adminService.getLaborCategories(),
            builder: (context, snapshot) {
              final laborList = snapshot.data ?? [];
              
              return Container(
                color: const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    // Header fijo
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Wrap( // <-- CAMBIO DE ROW A WRAP
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Tabulador de Salarios", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                              Text("Define los costos base para el cálculo de cotizaciones.", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _addNewLabor(laborList),
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: const Text("Agregar Puesto"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB), 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    // ✅ SOLUCIÓN: SingleChildScrollView + GridView con shrinkWrap
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                        child: GridView.builder(
                          shrinkWrap: true, // IMPORTANTE: Permite que GridView ocupe solo su contenido
                          physics: const NeverScrollableScrollPhysics(), // Desactiva scroll interno
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400, // Cards responsivos
                            mainAxisExtent: 130, // <-- REEMPLAZAMOS childAspectRatio POR ALTURA FIJA (130px)
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: laborList.length,
                          itemBuilder: (context, index) {
                            final item = laborList[index];
                            return _LaborCard(
                              key: ValueKey(item.id),
                              item: item,
                              onUpdate: (field, val) => _updateLabor(laborList, index, field, val),
                              onDelete: () => _deleteLabor(laborList, index),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16), // Espacio extra al final
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LaborCard extends StatefulWidget {
  final LaborCategory item;
  final Function(String, dynamic) onUpdate;
  final VoidCallback onDelete;

  const _LaborCard({
    super.key, 
    required this.item, 
    required this.onUpdate, 
    required this.onDelete
  });

  @override
  State<_LaborCard> createState() => _LaborCardState();
}

class _LaborCardState extends State<_LaborCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _salaryCtrl;
  
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _salaryFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _salaryCtrl = TextEditingController(text: widget.item.baseDailySalary.toString());

    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        if (_nameCtrl.text != widget.item.name) {
          widget.onUpdate('name', _nameCtrl.text);
        }
      }
    });

    _salaryFocus.addListener(() {
      if (!_salaryFocus.hasFocus) {
        final val = double.tryParse(_salaryCtrl.text) ?? 0.0;
        if (val != widget.item.baseDailySalary) {
          widget.onUpdate('salary', val);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salaryCtrl.dispose();
    _nameFocus.dispose();
    _salaryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2)
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Cambiado de start a center
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10)
            ),
            child: const Icon(LucideIcons.users, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Mantenemos center
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre del puesto
                TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  onSubmitted: (val) => widget.onUpdate('name', val),
                  decoration: InputDecoration(
                    labelText: "Nombre del Puesto", 
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    isDense: true, 
                    border: InputBorder.none, 
                    contentPadding: EdgeInsets.zero,
                    // Eliminamos cualquier padding adicional
                  ),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF0F172A),
                    height: 1.2, // Controlamos la altura de línea
                  ),
                ),
                const SizedBox(height: 8),
                // Línea separadora
                Container(height: 1, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                // Salario diario base
                TextField(
                  controller: _salaryCtrl,
                  focusNode: _salaryFocus,
                  onSubmitted: (val) => widget.onUpdate('salary', val),
                  decoration: InputDecoration(
                    labelText: "Salario Diario Base",
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    isDense: true, 
                    border: InputBorder.none, 
                    prefixText: "\$ ",
                    prefixStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.bold
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14, 
                    color: const Color(0xFF334155),
                    height: 1.2, // Controlamos la altura de línea
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),    
          ),
          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 18),
            tooltip: "Eliminar",
            padding: EdgeInsets.zero, // Eliminamos padding del botón
            constraints: const BoxConstraints(), // Quitamos restricciones de tamaño
          ),
        ],
      ),
    );
  }
}