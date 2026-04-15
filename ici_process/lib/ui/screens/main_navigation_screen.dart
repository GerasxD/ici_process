import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ici_process/services/admin_service.dart';
import 'package:ici_process/ui/screens/admin_panel_screen.dart';
import 'package:ici_process/ui/screens/calendar_screen.dart';
import 'package:ici_process/ui/screens/client_managment_screen.dart';
import 'package:ici_process/ui/screens/material_catalog_screen.dart';
import 'package:ici_process/ui/screens/provider_management_screen.dart';
import 'package:ici_process/ui/screens/service_catalog_screen.dart';
import 'package:ici_process/ui/screens/tool_catalog_screen.dart';
import 'package:ici_process/ui/screens/vehicle_management_screen.dart';
import 'package:ici_process/ui/screens/worker_management_screen.dart';
import 'package:ici_process/ui/widgets/calendar/event_form_dialog.dart';
import 'package:ici_process/ui/widgets/notifications_modal.dart';
import 'package:ici_process/ui/widgets/process_modal/process_modal.dart';
import 'package:ici_process/ui/widgets/kanban_view.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
// 1. IMPORTAMOS EL GESTOR DE PERMISOS
import '../../core/utils/permission_manager.dart'; 

class MainNavigationScreen extends StatefulWidget {
  final UserModel user;
  const MainNavigationScreen({super.key, required this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;

  final AdminService _adminService = AdminService();
  late final List<Widget> _views;

  // ignore: unused_field
  Map<String, List<String>> _permissions = {};
  bool _permissionsLoaded = false;

  StreamSubscription? _permissionsSubscription;


  // NOTA: El orden de esta lista debe coincidir con los índices que usamos abajo.
  @override
  void initState() {
    super.initState();

    _permissionsSubscription = _adminService.getRolePermissions().listen((perms) {
      if (mounted) {
        setState(() {
          _permissions = perms;
          _permissionsLoaded = true;
        });
      }
    });


    // ✅ 2. Inicializamos todas las pantallas una sola vez
    _views = [
      KanbanView(currentUser: widget.user),                    // 0
      CalendarScreen(currentUser: widget.user),                // 1
      const Center(child: Text("Reportes (Próximamente)")),    // 2
      ClientManagementScreen(currentUser: widget.user),        // 3
      ProviderManagementScreen(currentUser: widget.user),      // 4
      MaterialCatalogScreen(currentUser: widget.user),         // 5
      ServiceCatalogScreen(currentUser: widget.user),          // 6
      ToolCatalogScreen(currentUser: widget.user),             // 7
      VehicleManagementScreen(currentUser: widget.user),       // 8
      WorkerManagementScreen(currentUser: widget.user),        // 9  
      AdminPanelScreen(currentUser: widget.user),              // 10
    ];
  }

  @override
  void dispose() {
    _permissionsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    // Pantalla de carga inicial SOLO la primera vez
    if (!_permissionsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    // Sin StreamBuilder = sin flashes
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(LucideIcons.menu, color: Color(0xFF94A3B8)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: const Text("ICI-PROCESS",
                  style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              actions: [
                _buildNotificationBadge(),
                if (_selectedIndex == 0 && PermissionManager().can(widget.user, 'create_process'))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ProcessModal(user: widget.user),
                          );
                        },
                        icon: const Icon(LucideIcons.plus, size: 16, color: Colors.white),
                        label: const Text("Nuevo", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),

                  if (_selectedIndex == 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => EventFormDialog(
                              currentUser: widget.user,
                              initialDate: DateTime.now(), // Usa el día actual por defecto
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.calendarPlus, size: 16, color: Colors.white),
                        label: const Text("Nuevo", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (isDesktop) _buildDesktopSidebar(),
          Expanded(
            child: Column(
              children: [
                if (isDesktop) _buildTopHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _views,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: !isDesktop
          ? Drawer(
              width: 280,
              child: Container(
                color: const Color(0xFF0F172A),
                child: _buildSidebarContent(isMobile: true),
              ),
            )
          : null,
    );
  }

  // ... (El método _buildDesktopSidebar se queda igual) ...
  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarOpen ? 280 : 80,
      color: const Color(0xFF0F172A),
      child: _buildSidebarContent(isMobile: false),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. AQUÍ APLICAMOS LA LÓGICA EN EL SIDEBAR
  // ---------------------------------------------------------------------------
  Widget _buildSidebarContent({required bool isMobile}) {
    bool showText = isMobile ? true : _isSidebarOpen;
    // Instancia corta para escribir menos
    final pm = PermissionManager(); 

    return Column(
      children: [
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const Icon(LucideIcons.layout, color: Color(0xFF3B82F6), size: 32),
              if (showText) ...[
                const SizedBox(width: 12),
                const Text("ICI-PROCESS", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            children: [
              // General (Suele ser visible para todos, o usa 'view_dashboard')
              if (pm.can(widget.user, 'view_dashboard'))
                 _buildNavItem(0, "Tablero", LucideIcons.squareKanban, isMobile),
              
              if (pm.can(widget.user, 'view_dashboard')) // Asumiendo que todos ven calendario
                 _buildNavItem(1, "Calendario", LucideIcons.calendar, isMobile),
              
              if (pm.can(widget.user, 'view_budget')) // Ejemplo: Solo quien ve presupuesto ve reportes
                 _buildNavItem(2, "Reportes", LucideIcons.barChart2, isMobile),
              
              const SizedBox(height: 20),
              if (showText)
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 10),
                  child: Text("BASE DE DATOS", 
                    style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                ),

              // --- APLICANDO PERMISOS ESPECÍFICOS ---
              
              // Clientes
              if (pm.can(widget.user, 'view_clients'))
                _buildNavItem(3, "Clientes", LucideIcons.users, isMobile),

              // Proveedores
              if (pm.can(widget.user, 'view_providers'))
                _buildNavItem(4, "Proveedores", LucideIcons.boxes, isMobile),

              // Materiales
              if (pm.can(widget.user, 'view_materials'))
                _buildNavItem(5, "Materiales", LucideIcons.box, isMobile),

              // Servicios (Si no tienes un permiso 'view_services' usa uno similar o crea uno nuevo)
              if (pm.can(widget.user, 'view_materials')) // Reusando material o agrega 'view_services' en DB
                _buildNavItem(6, "Servicios / Rentas", LucideIcons.calendarClock, isMobile),

              if (pm.can(widget.user, 'view_tools'))
                _buildNavItem(7, "Herramientas", LucideIcons.wrench, isMobile),

              // Vehículos
              if (pm.can(widget.user, 'view_vehicles'))
                _buildNavItem(8, "Vehiculos", LucideIcons.truck, isMobile),

              if (pm.can(widget.user, 'view_workers'))
                _buildNavItem(9, "Personal", LucideIcons.hardHat, isMobile),
                
              // Admin Panel (Usamos manage_users como llave maestra para ver el panel)
              if (pm.can(widget.user, 'manage_users'))
                _buildNavItem(10, "Administración", LucideIcons.settings, isMobile),
            ],
          ),
        ),
        _buildUserProfileFooter(showText),
      ],
    );
  }

  // ... (El método _buildNavItem se queda igual) ...
  Widget _buildNavItem(int index, String label, IconData icon, bool isMobile) {
    // ... tu código original ...
    bool isSelected = _selectedIndex == index;
    bool showText = isMobile ? true : _isSidebarOpen;

    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) {
          Navigator.pop(context); 
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 20),
            if (showText) ...[
              const SizedBox(width: 16),
              Flexible(
                child: Text(label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ... (El método _buildTopHeader se modifica ligeramente) ...
  Widget _buildTopHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.menu, color: Color(0xFF94A3B8)),
            onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
          ),
          const Spacer(),
          _buildNotificationBadge(),
          
          if (_selectedIndex == 0) ...[
             const SizedBox(width: 24),
             // 3. PROTEGEMOS EL BOTÓN DE "NUEVO"
             // Solo mostramos el botón si tiene permiso de editar/mover en el tablero
             if (PermissionManager().can(widget.user, 'create_process')) 
                _buildQuickActionButton(),
          ],
          if (_selectedIndex == 1) ...[
             const SizedBox(width: 24),
             _buildNewEventButton(),
          ],
        ],
      ),
    );
  }
  
  // ---------------------------------------------------------------------------
  // MÉTODO ACTUALIZADO: BADGE DE NOTIFICACIONES REAL
  // ---------------------------------------------------------------------------
  Widget _buildNotificationBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: widget.user.id)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
  
        return Stack(
          alignment: Alignment.center,
          children: [
            // Botón principal con fondo sutil cuando hay notificaciones
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: unreadCount > 0
                    ? const Color(0xFFFEF2F2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(
                  unreadCount > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                  color: unreadCount > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                tooltip: unreadCount > 0
                    ? "$unreadCount notificaciones sin leer"
                    : "Notificaciones",
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        NotificationsModal(currentUser: widget.user),
                  );
                },
              ),
            ),
  
            // Badge contador
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: unreadCount > 9 ? 4 : 3,
                      vertical: 2,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 17, minHeight: 17),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
 
  Widget _buildQuickActionButton() {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => ProcessModal(user: widget.user),
        );
      },
      icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
      label: const Text("Nuevo Proceso", style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildNewEventButton() {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => EventFormDialog(
            currentUser: widget.user,
            initialDate: DateTime.now(),
          ),
        );
      },
      icon: const Icon(LucideIcons.calendarPlus, size: 18, color: Colors.white),
      label: const Text("Nuevo Evento", style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

 Widget _buildUserProfileFooter(bool showText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
        color: Color(0xFF1E293B),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF3B82F6),
            radius: 18,
            child: Text(
              widget.user.name.isNotEmpty ? widget.user.name[0] : 'U', 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.user.name, 
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), 
                    overflow: TextOverflow.ellipsis),
                  Text(widget.user.role.name.toUpperCase(), 
                    style: const TextStyle(color: Colors.white30, fontSize: 10)),
                ],
              ),
            ),
            // --- CÓDIGO DE LOGOUT SIMPLIFICADO ---
            IconButton(
              icon: const Icon(LucideIcons.logOut, color: Colors.white30, size: 18),
              tooltip: "Cerrar Sesión",
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (e) {
                  print("Error al cerrar sesión: $e");
                  // ✅ Verificar mounted ANTES de usar context tras el await
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error al cerrar sesión"))
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}