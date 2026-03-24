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
    'view_budget': 'Ver Presupuestos',
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
  };

  // Estructura original de permisos
  final Map<String, List<String>> _permissionGroups = {
    'General': ['view_dashboard', 'manage_users', 'view_budget', 'move_stage'],
    'Ver Base de Datos': ['view_clients', 'view_providers', 'view_materials', 'view_tools', 'view_vehicles'],
    'Editar Base de Datos': ['edit_clients', 'edit_providers', 'edit_materials', 'edit_tools', 'edit_vehicles'],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Centro de Administración", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.5)),
                      Text("Gestión de usuarios, permisos y catálogos globales.", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
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
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.users, size: 18), SizedBox(width: 8), Text("Usuarios")])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.shieldCheck, size: 18), SizedBox(width: 8), Text("Roles y Permisos")])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.banknote, size: 18), SizedBox(width: 8), Text("Salarios")])),
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
      case 'manager': return {'text': 'Gerente', 'bg': const Color(0xFF0369A1), 'fg': Colors.white};
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                Row(
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

  bool get isEditing => widget.userToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text = widget.userToEdit!.name;
      _emailCtrl.text = widget.userToEdit!.email;
      _selectedRole = widget.userToEdit!.role;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final user = UserModel(
        id: isEditing ? widget.userToEdit!.id : '', // ID vacío si es nuevo (se asigna en Service)
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isEditing ? LucideIcons.edit3 : LucideIcons.userPlus, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Text(isEditing ? "Editar Usuario" : "Registrar Nuevo Usuario", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInput("Nombre Completo", _nameCtrl, LucideIcons.user),
              const SizedBox(height: 16),
              
              // Email (Deshabilitado en edición para evitar conflictos con Auth)
              _buildInput(
                "Correo Electrónico", 
                _emailCtrl, 
                LucideIcons.mail, 
                isEmail: true, 
                isEnabled: !isEditing // No permitir cambiar email al editar
              ),
              const SizedBox(height: 16),
              
              if (!isEditing) ...[
                _buildInput("Contraseña Inicial", _passwordCtrl, LucideIcons.lock, isPassword: true),
                const SizedBox(height: 16),
              ],
              
              // Selector de Rol
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Rol del Sistema", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(LucideIcons.shield, size: 18, color: Colors.grey),
                    ),
                    items: UserRole.values.map((role) {
                      String label = role.toString().split('.').last.toUpperCase();
                      if (role == UserRole.technician) label = "TÉCNICO";
                      if (role == UserRole.purchasing) label = "COMPRAS";
                      return DropdownMenuItem(value: role, child: Text(label, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                ],
              ),
              if (isEditing) 
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Icon(LucideIcons.info, size: 14, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    const Expanded(child: Text("El correo no se puede cambiar aquí. Para cambiar la contraseña, usa el botón de 'Reset Password'.", style: TextStyle(fontSize: 11, color: Colors.grey))),
                  ]),
                )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          child: Text(isEditing ? "Guardar Cambios" : "Crear Usuario"),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool isEmail = false, bool isPassword = false, bool isEnabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          enabled: isEnabled,
          obscureText: isPassword,
          validator: (val) {
            if (val == null || val.isEmpty) return "Campo obligatorio";
            if (isEmail && !val.contains("@")) return "Correo inválido";
            if (isPassword && val.length < 6) return "Mínimo 6 caracteres";
            return null;
          },
          decoration: InputDecoration(
            hintText: "Escribe aquí...",
            prefixIcon: Icon(icon, size: 18, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: !isEnabled,
            fillColor: !isEnabled ? Colors.grey.shade100 : null,
          ),
        ),
      ],
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
    switch(role.toLowerCase()) {
      case 'superadmin': return 'Super Admin';
      case 'admin': return 'Administrador';
      case 'technician': return 'Técnico';
      case 'manager': return 'Gerente';
      case 'purchasing': return 'Compras';
      case 'accountant': return 'Contador';
      default: return role;
    }
  }

  // Helper para actualizar permisos de forma segura
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SIDEBAR DE ROLES (IGUAL QUE ANTES) ---
            Container(
              width: 280,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text("SELECCIONAR ROL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
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
                              if (isSelected) const Icon(LucideIcons.chevronRight, size: 16, color: Colors.white70)
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            // --- CONTENIDO PRINCIPAL ---
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: ListView(
                  padding: const EdgeInsets.all(40),
                  children: [
                    // TÍTULO
                    Row(
                      children: [
                        const Icon(LucideIcons.shieldCheck, size: 28, color: Color(0xFF0F172A)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Configuración de Permisos", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                            Text("Rol: ${_translateRole(selectedRole)}", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // 1. GRUPOS DE PERMISOS GENERALES (SWITCHES)
                    ...permissionGroups.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Text(
                                groupTitles[entry.key] ?? entry.key, 
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF334155))
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            ...entry.value.map((perm) {
                              final isChecked = currentRolePerms.contains(perm);
                              return SwitchListTile.adaptive(
                                title: Text(permissionLabels[perm] ?? perm, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B))),
                                value: isChecked,
                                activeColor: const Color(0xFF2563EB),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                onChanged: (val) => _togglePermission(currentRolePerms, perm, val),
                              );
                            }).toList(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    }).toList(),

                    // 2. NUEVA SECCIÓN: TABLA DE ETAPAS KANBAN (Diseño de la imagen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.folderKanban, size: 18, color: Color(0xFF334155)),
                                const SizedBox(width: 10),
                                Text(
                                  "ACCESO POR ETAPAS (FLUJO DE TRABAJO)", 
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF334155))
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          
                          // CABECERA DE LA TABLA
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text("ETAPA", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)))),
                                Expanded(child: Center(child: Text("VISIBLE", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))))),
                                Expanded(child: Center(child: Text("EDITABLE", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))))),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),

                          // FILAS DE ETAPAS
                          ...ProcessStage.values.map((stage) {
                            final stageName = stage.toString().split('.').last;
                            
                            // Códigos de permiso: 'stage_view_E1', 'stage_edit_E1'
                            final viewCode = 'stage_view_$stageName';
                            final editCode = 'stage_edit_$stageName';

                            final canView = currentRolePerms.contains(viewCode);
                            final canEdit = currentRolePerms.contains(editCode);

                            // Obtener info bonita de app_constants (titulo y color)
                            final config = stageConfigs[stage]; 

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
                              ),
                              child: Row(
                                children: [
                                  // Nombre de la Etapa con colorcito
                                  Expanded(
                                    flex: 3, 
                                    child: Row(
                                      children: [
                                        Container(width: 8, height: 8, decoration: BoxDecoration(color: config?.textColor ?? Colors.grey, shape: BoxShape.circle)),
                                        const SizedBox(width: 12),
                                        Text(config?.title ?? stageName, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B))),
                                      ],
                                    )
                                  ),
                                  
                                  // Checkbox Visible
                                  Expanded(
                                    child: Center(
                                      child: Checkbox(
                                        value: canView, 
                                        activeColor: const Color(0xFF2563EB),
                                        onChanged: (val) => _togglePermission(currentRolePerms, viewCode, val ?? false),
                                      ),
                                    ),
                                  ),

                                  // Checkbox Editable
                                  Expanded(
                                    child: Center(
                                      child: Checkbox(
                                        value: canEdit, 
                                        activeColor: const Color(0xFF16A34A), // Verde para editar
                                        onChanged: (val) {
                                          // Si activas editar, automáticamente activa ver
                                          if (val == true && !canView) {
                                            final tempPerms = List<String>.from(currentRolePerms)..add(viewCode);
                                            _togglePermission(tempPerms, editCode, true);
                                          } else {
                                            _togglePermission(currentRolePerms, editCode, val ?? false);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
        // SIDEBAR MENÚ CATÁLOGOS
        Container(
          width: 250,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text("CONFIGURACIÓN", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const Icon(LucideIcons.banknote, color: Color(0xFF2563EB), size: 20),
                title: Text("Mano de Obra", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), fontSize: 14)),
                subtitle: Text("Salarios base diarios", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                selected: true,
                selectedTileColor: const Color(0xFFEFF6FF),
              ),
            ],
          ),
        ),
        
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            childAspectRatio: 2.8,
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