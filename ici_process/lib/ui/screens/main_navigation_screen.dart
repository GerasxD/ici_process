import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/services/admin_service.dart';
import 'package:ici_process/ui/screens/admin_panel_screen.dart';
import 'package:ici_process/ui/screens/client_managment_screen.dart';
import 'package:ici_process/ui/screens/material_catalog_screen.dart';
import 'package:ici_process/ui/screens/provider_management_screen.dart';
import 'package:ici_process/ui/screens/service_catalog_screen.dart';
import 'package:ici_process/ui/screens/tool_catalog_screen.dart';
import 'package:ici_process/ui/screens/vehicle_management_screen.dart';
import 'package:ici_process/ui/widgets/process_modal/process_modal.dart';
import 'package:ici_process/ui/widgets/kanban_view.dart';
import 'package:intl/intl.dart'; 
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

  // NOTA: El orden de esta lista debe coincidir con los índices que usamos abajo.
  @override
  void initState() {
    super.initState();
    // ✅ 2. Inicializamos todas las pantallas una sola vez
    _views = [
      KanbanView(currentUser: widget.user), // 0
      const Center(child: Text("Calendario (Próximamente)")), // 1
      const Center(child: Text("Reportes (Próximamente)")), // 2
      ClientManagementScreen(currentUser: widget.user), // 3
      ProviderManagementScreen(currentUser: widget.user), // 4
      MaterialCatalogScreen(currentUser: widget.user), // 5
      ServiceCatalogScreen(currentUser:  widget.user), // 6
      ToolCatalogScreen(currentUser: widget.user), // 7
      VehicleManagementScreen(currentUser: widget.user),// 8
      AdminPanelScreen(currentUser: widget.user), // 9
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    
    // ENVOLVEMOS TODO EN ESTE STREAM BUILDER
    return StreamBuilder<Map<String, List<String>>>(
      stream: _adminService.getRolePermissions(),
      builder: (context, snapshot) {
        
        // Si Firebase aún está descargando los permisos, mostramos una pantalla de carga limpia
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            ),
          );
        }

        // Una vez que los permisos llegaron, dibujamos tu pantalla tal cual la tenías
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
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
                actions: [
                   _buildNotificationBadge(),
                   const SizedBox(width: 16),
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
                      // ✅ 3. ADIÓS ANIMATEDSWITCHER, HOLA INDEXEDSTACK
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
                  child: _buildSidebarContent(isMobile: true)
                ),
              ) 
            : null,
        );
      }
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
              // Admin Panel (Usamos manage_users como llave maestra para ver el panel)
              if (pm.can(widget.user, 'manage_users'))
                _buildNavItem(9, "Administración", LucideIcons.settings, isMobile),
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
             if (PermissionManager().can(widget.user, 'move_stage')) 
                _buildQuickActionButton(),
          ],
        ],
      ),
    );
  }
  
  // ---------------------------------------------------------------------------
  // MÉTODO ACTUALIZADO: BADGE DE NOTIFICACIONES REAL
  // ---------------------------------------------------------------------------
  Widget _buildNotificationBadge() {
    // Escuchamos en tiempo real la colección 'notifications' para este usuario
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: widget.user.id) // Solo las de este usuario
          .where('read', isEqualTo: false) // Solo las no leídas
          .snapshots(),
      builder: (context, snapshot) {
        // Si no hay datos o hay error, mostramos la campana sin badge
        if (!snapshot.hasData || snapshot.hasError) {
          return IconButton(
            icon: const Icon(LucideIcons.bell, color: Color(0xFF94A3B8)),
            onPressed: () => _showNotificationsModal(),
          );
        }

        final unreadCount = snapshot.data!.docs.length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, color: Color(0xFF94A3B8)),
              onPressed: () => _showNotificationsModal(),
            ),
            // Solo mostramos el globito rojo si hay notificaciones sin leer
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MÉTODO ACTUALIZADO: CON MANEJO DE ERRORES
  // ---------------------------------------------------------------------------
  void _showNotificationsModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Evita tintes raros de Material 3
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 420,
          height: 550,
          child: Column(
            children: [
              // --- HEADER DEL MODAL ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF), // Fondo azul clarito
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.bellRing, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 16),
                        Text("Notificaciones", 
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Color(0xFF64748B), size: 22),
                      tooltip: "Cerrar",
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // --- CONTENIDO (LISTA O ESTADOS) ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('targetUserId', isEqualTo: widget.user.id)
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // 1. ESTADO DE ERROR
                    if (snapshot.hasError) {
                      print("Error en notificaciones: ${snapshot.error}");
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.alertTriangle, color: Color(0xFFEF4444), size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text("Error de conexión", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
                              const SizedBox(height: 8),
                              Text("Revisa la consola para crear el índice en Firebase.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      );
                    }

                    // 2. ESTADO DE CARGA
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                      );
                    }
                    
                    // 3. ESTADO VACÍO (Cero notificaciones) - AHORA PERFECTAMENTE CENTRADO
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center( // <-- Este Center envuelve todo para alinear al medio de la pantalla
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
                              child: const Icon(LucideIcons.bellOff, size: 40, color: Color(0xFFCBD5E1)),
                            ),
                            const SizedBox(height: 16),
                            Text("Todo está al día", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                            const SizedBox(height: 8),
                            Text("No tienes notificaciones nuevas por ahora.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      );
                    }

                    // 4. LISTA DE NOTIFICACIONES
                    final docs = snapshot.data!.docs;

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final docId = docs[index].id;
                        final isRead = data['read'] ?? false;
                        final title = data['title'] ?? 'Notificación';
                        final body = data['body'] ?? '';
                        final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                        return Material(
                          color: isRead ? Colors.transparent : const Color(0xFFF0F9FF), // Fondo azul muy claro si no está leída
                          child: InkWell(
                            onTap: () async {
                              if (!isRead) {
                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .doc(docId)
                                    .update({'read': true});
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icono circular
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRead ? const Color(0xFFF1F5F9) : const Color(0xFFDBEAFE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.info, 
                                      size: 18, 
                                      color: isRead ? const Color(0xFF94A3B8) : const Color(0xFF2563EB)
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Textos de la notificación
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, 
                                          style: GoogleFonts.inter(
                                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold, 
                                            fontSize: 14,
                                            color: isRead ? const Color(0xFF334155) : const Color(0xFF0F172A),
                                          )
                                        ),
                                        const SizedBox(height: 4),
                                        Text(body, 
                                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4)
                                        ),
                                        const SizedBox(height: 8),
                                        Text(DateFormat('dd MMM, HH:mm').format(date), 
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)
                                        ),
                                      ],
                                    )
                                  ),
                                  
                                  // Puntito indicador de "No leída"
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6, left: 8),
                                      width: 8, height: 8, 
                                      decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)
                                    )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error al cerrar sesión"))
                  );
                }
              },
            ),
            // -------------------------------------
          ],
        ],
      ),
    );
  }
}