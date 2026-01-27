import 'package:flutter/material.dart';
import 'package:ici_process/ui/widgets/process_modal/process_modal.dart';
import 'package:ici_process/ui/widgets/kanban_view.dart'; // Importante para ver las tarjetas
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel user;
  const MainNavigationScreen({super.key, required this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;

  // Definimos las vistas aquí para que se carguen dinámicamente
  List<Widget> get _views => [
    KanbanView(currentUser: widget.user), // Carga real de Firebase
    const Center(child: Text("Calendario (Próximamente)")),
    const Center(child: Text("Reportes (Próximamente)")),
    const Center(child: Text("Base de Datos (Próximamente)")),
    const Center(child: Text("Configuración (Próximamente)")),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // AppBar exclusivo para móviles
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
            title: const Text("ICI INTEGRAL", 
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _views[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Menú lateral para móviles
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

  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarOpen ? 280 : 80,
      color: const Color(0xFF0F172A),
      child: _buildSidebarContent(isMobile: false),
    );
  }

  Widget _buildSidebarContent({required bool isMobile}) {
    bool showText = isMobile ? true : _isSidebarOpen;

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
                const Text("ICI INTEGRAL", 
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
              _buildNavItem(0, "Tablero", LucideIcons.squareKanban, isMobile),
              _buildNavItem(1, "Calendario", LucideIcons.calendar, isMobile),
              _buildNavItem(2, "Reportes", LucideIcons.barChart2, isMobile),
              const SizedBox(height: 20),
              if (showText)
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 10),
                  child: Text("BASE DE DATOS", 
                    style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              _buildNavItem(3, "Inventario/DB", LucideIcons.database, isMobile),
              _buildNavItem(4, "Sistema", LucideIcons.settings, isMobile),
            ],
          ),
        ),
        _buildUserProfileFooter(showText),
      ],
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, bool isMobile) {
    bool isSelected = _selectedIndex == index;
    bool showText = isMobile ? true : _isSidebarOpen;

    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) {
          Navigator.pop(context); // Cierra el Drawer automáticamente
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
          const SizedBox(width: 24),
          _buildQuickActionButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        const Icon(LucideIcons.bell, color: Color(0xFF94A3B8)),
        Positioned(
          right: 0, top: 0,
          child: Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
        ),
      ],
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
      label: const Text("Nuevo", style: TextStyle(color: Colors.white)),
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
            child: Text(widget.user.name[0], 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            IconButton(
              icon: const Icon(LucideIcons.logOut, color: Colors.white30, size: 18),
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ],
      ),
    );
  }
}