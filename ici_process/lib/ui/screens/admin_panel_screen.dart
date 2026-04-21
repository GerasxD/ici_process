import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/admin_config_model.dart';
import '../../models/role_model.dart';
import '../../services/user_service.dart';
import '../../services/admin_service.dart';
import '../../services/role_service.dart';
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
  final RoleService _roleService = RoleService();

  late TabController _tabController;
  String _selectedRoleForEdit = SystemRoles.admin;

  // Mapa de traducción para los grupos de permisos
  final Map<String, String> _groupTitles = {
    'General': 'General y Flujo',
    'Ver Base de Datos': 'Visibilidad de Módulos (Lectura)',
    'Editar Base de Datos': 'Gestión de Módulos (Escritura)',
    'Archivos Adjuntos': 'Gestión de Archivos por Sección',
    'Archivos': 'Almacén de Archivos'
  };

  // Mapa de permisos técnicos a Español
  final Map<String, String> _permissionLabels = {
    'view_dashboard': 'Ver Panel de Control',
    'manage_users': 'Administrar Usuarios',
    'view_budget': 'Ver Reportes',
    'move_stage': 'Mover Etapas (Kanban)',
    'create_process': 'Crear Nuevo Proceso',
    'discard_process': 'Descartar Proceso',
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
    'view_workers': 'Ver Personal / Trabajadores',    
    'edit_workers': 'Editar/Crear Trabajadores',  
    'view_financials': 'Ver Resumen Financiero (Costos/Precios)',
    'view_company_profile': 'Ver Perfil de la Empresa',
    'edit_company_profile': 'Editar Perfil de la Empresa',
    'view_files_info': 'Ver Archivos: Información Principal',
    'upload_files_info': 'Subir/Eliminar Archivos: Info Principal',
    'view_files_financial': 'Ver Archivos: Cotización / Financiero',
    'upload_files_financial': 'Subir/Eliminar Archivos: Cotización',
    'view_files_oc': 'Ver Archivos: Orden de Compra',
    'upload_files_oc': 'Subir/Eliminar Archivos: Orden de Compra',
    'view_file_vault': 'Ver Sección de Archivos',
    'create_folders': 'Crear Carpetas',
    'manage_all_files': 'Acceso Total a Archivos (Super)',
  };

  // Estructura original de permisos
  final Map<String, List<String>> _permissionGroups = {
    'General': ['view_dashboard', 'manage_users', 'view_budget', 'move_stage', 'create_process', 'discard_process','view_company_profile','edit_company_profile',],
    'Ver Base de Datos': ['view_clients', 'view_providers', 'view_materials', 'view_tools', 'view_vehicles','view_workers','view_financials',],
    'Editar Base de Datos': ['edit_clients', 'edit_providers', 'edit_materials', 'edit_tools', 'edit_vehicles','edit_workers',],
    'Archivos Adjuntos': ['view_files_info','upload_files_info','view_files_financial','upload_files_financial','view_files_oc','upload_files_oc',],
    'Archivos': ['view_file_vault', 'create_folders', 'manage_all_files'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _roleService.ensureDefaultRolesSeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<RoleModel>>(
              stream: _roleService.getRolesStream(),
              builder: (context, roleSnap) {
                final roles = roleSnap.data ?? [];
                final hasSelected = roles.any((r) => r.id == _selectedRoleForEdit);
                if (!hasSelected && roles.isNotEmpty) {
                  final fallback = roles.firstWhere(
                    (r) => r.id == SystemRoles.admin,
                    orElse: () => roles.first,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedRoleForEdit = fallback.id);
                  });
                }
                return TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _UsersTab(
                      userService: _userService,
                      currentUser: widget.currentUser,
                      roles: roles,
                    ),
                    _RolesTab(
                      adminService: _adminService,
                      roleService: _roleService,
                      roles: roles,
                      selectedRole: _selectedRoleForEdit,
                      permissionGroups: _permissionGroups,
                      groupTitles: _groupTitles,
                      permissionLabels: _permissionLabels,
                      onRoleChanged: (r) => setState(() => _selectedRoleForEdit = r),
                    ),
                    _CatalogsTab(adminService: _adminService),
                  ],
                );
              },
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
  final List<RoleModel> roles;

  const _UsersTab({
    required this.userService,
    required this.currentUser,
    required this.roles,
  });

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
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 460,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.userX, color: Color(0xFFDC2626), size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Eliminar Usuario",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Se revocará el acceso al sistema",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  children: [
                    // Info del usuario
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Advertencia
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "El usuario perderá todo acceso al sistema de forma inmediata. Esta acción no se puede deshacer.",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          "Cancelar",
                          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Eliminar Usuario",
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
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

    if (confirm == true) {
      try {
        await widget.userService.deleteUser(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text("${user.name} ha sido eliminado del sistema", style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13))),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertOctagon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text("Error al eliminar usuario", style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13))),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          ));
        }
      }
    }
  }

  // --- LÓGICA: RESTABLECER CONTRASEÑA ---
 Future<void> _handleResetPassword(String email) async {
  final confirm = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 460,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.keyRound, color: Color(0xFFB45309), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Restablecer Contraseña",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Se enviará un correo de recuperación",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                children: [
                  // Destinatario
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.mail, size: 16, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Correo destinatario",
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nota informativa
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.info, size: 16, color: Color(0xFF0369A1)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "El usuario recibirá un enlace en su correo para establecer una nueva contraseña. El enlace tiene una vigencia limitada.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF0C4A6E),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        "Cancelar",
                        style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.send, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Enviar Correo",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
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

  if (confirm == true) {
    try {
      await widget.userService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text("Correo de recuperación enviado a $email", style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13))),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.alertOctagon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text("Error al enviar correo", style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13))),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        ));
      }
    }
  }
}

  // --- LÓGICA: CREAR O EDITAR USUARIO ---
  void _showUserDialog({UserModel? userToEdit}) {
    if (widget.roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Cargando roles, intenta de nuevo en un segundo..."),
      ));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserFormDialog(
        userToEdit: userToEdit,
        availableRoles: widget.roles,
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
    final found = widget.roles.firstWhere(
      (r) => r.id == role,
      orElse: () => RoleModel(
        id: role,
        displayName: role.isEmpty ? 'Sin rol' : role,
        colorHex: '#64748B',
        iconKey: 'user',
      ),
    );
    return {
      'text': found.displayName,
      'bg': found.color,
      'fg': Colors.white,
    };
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
                    final roleStyle = _getRoleStyle(user.role);
                    final isMe = user.id == widget.currentUser.id;
                    final isSuper = widget.currentUser.role == SystemRoles.superAdmin;

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
  final List<RoleModel> availableRoles;
  final Function(UserModel, String?) onSave;

  const _UserFormDialog({
    this.userToEdit,
    required this.availableRoles,
    required this.onSave,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late String _selectedRole;
  bool _obscurePassword = true;

  bool get isEditing => widget.userToEdit != null;

  RoleModel _roleFor(String id) {
    return widget.availableRoles.firstWhere(
      (r) => r.id == id,
      orElse: () => RoleModel(
        id: id,
        displayName: id.isEmpty ? 'Sin rol' : id,
        colorHex: '#64748B',
        iconKey: 'user',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final defaultRole = widget.availableRoles
        .firstWhere(
          (r) => r.id == SystemRoles.technician,
          orElse: () => widget.availableRoles.isNotEmpty
              ? widget.availableRoles.last
              : const RoleModel(
                  id: 'technician',
                  displayName: 'Técnico',
                  colorHex: '#0D9488',
                  iconKey: 'wrench',
                ),
        )
        .id;
    _selectedRole = isEditing ? widget.userToEdit!.role : defaultRole;
    if (isEditing) {
      _nameCtrl.text = widget.userToEdit!.name;
      _emailCtrl.text = widget.userToEdit!.email;
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
    final roleConfig = _roleFor(_selectedRole);
    final Color roleColor = roleConfig.color;

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
                        children: widget.availableRoles.map((role) {
                          final Color color = role.color;
                          final bool isSelected = _selectedRole == role.id;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedRole = role.id),
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
                                    role.icon,
                                    size: 15,
                                    color: isSelected ? Colors.white : color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    role.displayName,
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
                            Icon(roleConfig.icon, size: 16, color: roleColor),
                            const SizedBox(width: 10),
                            Text(
                              "Acceso asignado como: ",
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              roleConfig.displayName,
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
  final RoleService roleService;
  final List<RoleModel> roles;
  final String selectedRole;
  final Map<String, List<String>> permissionGroups;
  final Map<String, String> groupTitles;
  final Map<String, String> permissionLabels;
  final Function(String) onRoleChanged;

  const _RolesTab({
    required this.adminService,
    required this.roleService,
    required this.roles,
    required this.selectedRole,
    required this.permissionGroups,
    required this.groupTitles,
    required this.permissionLabels,
    required this.onRoleChanged,
  });


  String _translateRole(String role) {
    final model = roles.firstWhere(
      (r) => r.id == role,
      orElse: () => RoleModel(
        id: role,
        displayName: role,
        colorHex: '#64748B',
        iconKey: 'user',
      ),
    );
    return model.displayName;
  }

  Color _roleColor(String role) {
    final model = roles.firstWhere(
      (r) => r.id == role,
      orElse: () => const RoleModel(
        id: '',
        displayName: '',
        colorHex: '#64748B',
        iconKey: 'user',
      ),
    );
    return model.color;
  }

  IconData _roleIcon(String role) {
    final model = roles.firstWhere(
      (r) => r.id == role,
      orElse: () => const RoleModel(
        id: '',
        displayName: '',
        colorHex: '#64748B',
        iconKey: 'user',
      ),
    );
    return model.icon;
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
              return _buildDesktopLayout(context, currentRolePerms);
            } else {
              return _buildMobileLayout(context, currentRolePerms);
            }
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DESKTOP: Sidebar + Content (tu diseño original)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context, List<String> currentRolePerms) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SELECCIONAR ROL",
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 1.0)),
                ],
              ),
              const SizedBox(height: 12),
              _NewRoleButton(
                onPressed: () => _showCreateRoleDialog(context),
              ),
              const SizedBox(height: 16),
              ...roles.map((role) {
                final isSelected = role.id == selectedRole;
                final isSuper = role.isSuperAdmin;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onRoleChanged(role.id),
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
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  role.icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : role.color,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    role.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSuper)
                            Icon(
                              LucideIcons.lock,
                              size: 14,
                              color: isSelected ? Colors.white70 : const Color(0xFF94A3B8),
                            )
                          else
                            InkWell(
                              onTap: () => _confirmDeleteRole(context, role),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  LucideIcons.trash2,
                                  size: 15,
                                  color: isSelected ? Colors.white70 : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          if (isSelected) const SizedBox(width: 4),
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
  Widget _buildMobileLayout(BuildContext context, List<String> currentRolePerms) {
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
                  children: [
                    // Botón "Nuevo"
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showCreateRoleDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.plus, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                "Nuevo",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Mapeo de roles
                    ...roles.map((role) {
                      final isSelected = role.id == selectedRole;
                      final rColor = role.color;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => onRoleChanged(role.id),
                          onLongPress: role.isSuperAdmin ? null : () => _confirmDeleteRole(context, role),
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
                                  role.icon,
                                  size: 14,
                                  color: isSelected ? Colors.white : rColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  role.displayName,
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
                    }).toList(), // El .toList() es opcional en versiones recientes de Dart, pero es válido mantenerlo.
                  ],
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

  // ═══════════════════════════════════════════════════════════════
  //  CREAR / ELIMINAR ROLES
  // ═══════════════════════════════════════════════════════════════
  Future<void> _showCreateRoleDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RoleFormDialog(
        existingIds: roles.map((r) => r.id).toList(),
        onSave: (role) async {
          try {
            await roleService.createRole(role);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Rol '${role.displayName}' creado"),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ));
              onRoleChanged(role.id);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Error: ${e.toString().replaceFirst('Exception: ', '')}"),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteRole(BuildContext context, RoleModel role) async {
    if (role.isSuperAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.trash2, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Eliminar Rol",
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              )),
                          const SizedBox(height: 2),
                          Text(role.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  "Se eliminará el rol y sus permisos asignados. Esta acción no se puede deshacer.\n\nSi algún usuario tiene asignado este rol, la operación fallará.",
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text("Cancelar",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text("Eliminar Rol",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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

    if (confirm == true) {
      try {
        await roleService.deleteRole(role.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Rol '${role.displayName}' eliminado"),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ));
          if (selectedRole == role.id) {
            final fallback = roles.firstWhere(
              (r) => r.id == SystemRoles.admin,
              orElse: () => roles.firstWhere(
                (r) => r.id != role.id,
                orElse: () => role,
              ),
            );
            onRoleChanged(fallback.id);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }
}

class _NewRoleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _NewRoleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.plus, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Text(
              "Crear Nuevo Rol",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleFormDialog extends StatefulWidget {
  final List<String> existingIds;
  final Function(RoleModel) onSave;

  const _RoleFormDialog({
    required this.existingIds,
    required this.onSave,
  });

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _selectedColor = kRoleColorPalette.first;
  String _selectedIcon = kRoleIconOptions.keys.first;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final role = RoleModel(
      id: _idCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      colorHex: _selectedColor,
      iconKey: _selectedIcon,
    );
    widget.onSave(role);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewColor = RoleModel(
      id: 'preview',
      displayName: _nameCtrl.text.trim().isEmpty ? 'Nombre del Rol' : _nameCtrl.text.trim(),
      colorHex: _selectedColor,
      iconKey: _selectedIcon,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: previewColor.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(previewColor.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Nuevo Rol",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              )),
                          Text("Define un rol personalizado para tu equipo",
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("Nombre visible"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: _inputDecoration(
                          hint: "Ej. Coordinador de Obra",
                          icon: LucideIcons.tag,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Campo obligatorio";
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _label("Identificador interno (ID)"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _idCtrl,
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: _inputDecoration(
                          hint: "coordinador_obra",
                          icon: LucideIcons.hash,
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return "Campo obligatorio";
                          if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value)) {
                            return "Debe iniciar con letra; solo letras, números y _";
                          }
                          if (widget.existingIds.contains(value)) {
                            return "Ya existe un rol con ese ID";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Este ID se usa internamente (no se puede cambiar después).",
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 20),
                      _label("Color"),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: kRoleColorPalette.map((hex) {
                          final isSelected = hex == _selectedColor;
                          final color = RoleModel(
                            id: '',
                            displayName: '',
                            colorHex: hex,
                            iconKey: 'user',
                          ).color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = hex),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.black : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : [],
                              ),
                              child: isSelected
                                  ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      _label("Icono"),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: kRoleIconOptions.entries.map((entry) {
                          final isSelected = entry.key == _selectedIcon;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = entry.key),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected ? previewColor.color : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? previewColor.color : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                size: 20,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text("Cancelar",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: Text("Crear Rol",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      );

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
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