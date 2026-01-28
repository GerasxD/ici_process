import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../models/provider_model.dart';
import '../../services/provider_service.dart';

class ProviderManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProviderManagementScreen({super.key, required this.currentUser});

  @override
  State<ProviderManagementScreen> createState() => _ProviderManagementScreenState();
}

class _ProviderManagementScreenState extends State<ProviderManagementScreen> {
  // Controladores
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final ProviderService _providerService = ProviderService();
  bool _isUploading = false;

  // --- PALETA DE COLORES REFINADA ---
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB); // Color principal de la app
  final Color _inputFill = const Color(0xFFF1F5F9);
  
  // Color distintivo para Proveedores (Indigo suave para diferenciar de Clientes azules)
  final Color _accentColor = const Color(0xFF6366F1); 

  bool get isAdmin =>
      widget.currentUser.role == UserRole.admin ||
      widget.currentUser.role == UserRole.superAdmin;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (_nameCtrl.text.isEmpty || _contactCtrl.text.isEmpty) {
      _showSnack("Nombre y Contacto son obligatorios", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);
    try {
      await _providerService.addProvider(
        _nameCtrl.text.trim(),
        _contactCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        _emailCtrl.text.trim(),
      );
      
      _nameCtrl.clear();
      _contactCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      FocusScope.of(context).unfocus();
      if (mounted) _showSnack("Proveedor registrado correctamente");
    } catch (e) {
      if (mounted) _showSnack("Error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: LayoutBuilder(builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth > 1000;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              StreamBuilder<List<Provider>>(
                stream: _providerService.getProviders(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final providers = snapshot.data ?? [];

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildList(providers)),
                        const SizedBox(width: 40),
                        if (isAdmin) Expanded(flex: 4, child: _buildForm()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        if (isAdmin) ...[_buildForm(), const SizedBox(height: 40)],
                        _buildList(providers),
                      ],
                    );
                  }
                },
              )
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4)
              )
            ],
            border: Border.all(color: _borderColor),
          ),
          // ✅ NUEVO ICONO: BOXES (Representa inventario/suministros)
          child: Icon(LucideIcons.boxes, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Proveedores y Suministros",
              style: GoogleFonts.inter(
                fontSize: 26, 
                fontWeight: FontWeight.w800, 
                color: _textPrimary,
                letterSpacing: -0.5
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Gestiona tu catálogo de proveedores y contactos externos.",
              style: GoogleFonts.inter(fontSize: 15, color: _textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildList(List<Provider> providers) {
    if (providers.isEmpty) return _buildEmptyState();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LISTADO DE PROVEEDORES (${providers.length})",
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 1),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: providers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, index) => _buildCard(providers[index]),
        ),
      ],
    );
  }

  Widget _buildCard(Provider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar con las iniciales
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                provider.name.isNotEmpty ? provider.name.substring(0, 1).toUpperCase() : '#',
                style: GoogleFonts.inter(color: _accentColor, fontWeight: FontWeight.w700, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // Información
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary),
                ),
                const SizedBox(height: 8),
                
                // Grid de información de contacto
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _buildInfoItem(LucideIcons.user, provider.contactName),
                    if (provider.phone.isNotEmpty) _buildInfoItem(LucideIcons.phone, provider.phone),
                    if (provider.email.isNotEmpty) _buildInfoItem(LucideIcons.mail, provider.email),
                  ],
                )
              ],
            ),
          ),

          // Botones de acción mejorados
          if (isAdmin)
            Row(
              children: [
                _buildIconBtn(
                  icon: LucideIcons.edit3, 
                  color: Colors.blue, 
                  onTap: () => _showEditDialog(provider)
                ),
                const SizedBox(width: 8),
                _buildIconBtn(
                  icon: LucideIcons.trash2, 
                  color: Colors.red, 
                  onTap: () => _confirmDelete(provider)
                ),
              ],
            )
        ],
      ),
    );
  }

  // Widget auxiliar para botones de acción suaves
  Widget _buildIconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.inter(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(LucideIcons.plus, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text("Registrar Proveedor", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSectionLabel("Datos de la Empresa"),
          _input(_nameCtrl, "Nombre Comercial", LucideIcons.building),
          
          const SizedBox(height: 24),
          _buildSectionLabel("Datos de Contacto"),
          _input(_contactCtrl, "Nombre del Contacto", LucideIcons.user),
          const SizedBox(height: 12),
          _input(_phoneCtrl, "Teléfono", LucideIcons.phone),
          const SizedBox(height: 12),
          _input(_emailCtrl, "Correo Electrónico", LucideIcons.mail),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _handleAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("Guardar Proveedor", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: _primaryBlue, width: 1.5)
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageOpen, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No hay proveedores", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(height: 8),
          Text("Agrega proveedores para gestionar tus suministros.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626), size: 32),
            const SizedBox(height: 12),
            Text("Error de conexión", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
            Text(error, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C))),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Provider provider) {
    final nCtrl = TextEditingController(text: provider.name);
    final cCtrl = TextEditingController(text: provider.contactName);
    final pCtrl = TextEditingController(text: provider.phone);
    final eCtrl = TextEditingController(text: provider.email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Editar Proveedor", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel("Información"),
            _input(nCtrl, "Nombre Empresa", LucideIcons.building),
            const SizedBox(height: 16),
            _input(cCtrl, "Contacto", LucideIcons.user),
            const SizedBox(height: 12),
            _input(pCtrl, "Teléfono", LucideIcons.phone),
            const SizedBox(height: 12),
            _input(eCtrl, "Correo", LucideIcons.mail),
          ],
        ),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _providerService.updateProvider(Provider(
                id: provider.id,
                name: nCtrl.text,
                contactName: cCtrl.text,
                phone: pCtrl.text,
                email: eCtrl.text,
              ));
              if (mounted) {
                Navigator.pop(ctx);
                _showSnack("Proveedor actualizado", isSuccess: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text("Guardar Cambios"),
          )
        ],
      ),
    );
  }

  void _confirmDelete(Provider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Text("Eliminar Proveedor", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Seguro que deseas eliminar a '${provider.name}'?\nEsta acción no se puede deshacer.", style: GoogleFonts.inter()),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              _providerService.deleteProvider(provider.id);
              Navigator.pop(ctx);
              _showSnack("Proveedor eliminado");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }
}