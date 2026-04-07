import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  
  // SOLUCIÓN 1: Variable para almacenar el stream y evitar el "flickering" o recargas al abrir el teclado
  late Stream<List<Provider>> _providersStream;

  // --- PALETA DE COLORES REFINADA ---
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB); 
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF6366F1); 

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_providers');

  @override
  void initState() {
    super.initState();
    // Se inicializa el stream solo una vez al cargar la pantalla
    _providersStream = _providerService.getProviders();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (!canEdit) return;
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
                stream: _providersStream, // Se usa la variable, no la función directa
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
                        if (canEdit) Expanded(flex: 4, child: _buildForm()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        if (canEdit) ...[_buildForm(), const SizedBox(height: 40)],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary),
                ),
                const SizedBox(height: 8),
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
          if (canEdit)
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
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 520,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB45309),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: const Color(0xFFB45309).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: Text(
                              provider.name.isNotEmpty ? provider.name[0].toUpperCase() : 'P',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Editar Proveedor", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text("Modifica los datos del proveedor", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                          icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // Contenido
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("EMPRESA", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(nCtrl, "Nombre Empresa", LucideIcons.building),
                          const SizedBox(height: 20),
                          Text("DATOS DE CONTACTO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(cCtrl, "Nombre del Contacto", LucideIcons.user),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _input(pCtrl, "Teléfono", LucideIcons.phone)),
                              const SizedBox(width: 12),
                              Expanded(child: _input(eCtrl, "Correo", LucideIcons.mail)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                            child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    setStateDialog(() => isUpdating = true);
                                    try {
                                      await _providerService.updateProvider(Provider(
                                        id: provider.id,
                                        name: nCtrl.text.trim(),
                                        contactName: cCtrl.text.trim(),
                                        phone: pCtrl.text.trim(),
                                        email: eCtrl.text.trim(),
                                      ));
                                      if (mounted) {
                                        Navigator.pop(ctx);
                                        _showSnack("Proveedor actualizado", isSuccess: true);
                                      }
                                    } catch (e) {
                                      setStateDialog(() => isUpdating = false);
                                      if (mounted) _showSnack("Error: $e", isSuccess: false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: isUpdating
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.save, size: 18),
                                      const SizedBox(width: 8),
                                      Text("Guardar Cambios", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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
          );
        },
      ),
    );
  }

  void _confirmDelete(Provider provider) {
    showDialog(
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(LucideIcons.trash2, color: Color(0xFFDC2626), size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Eliminar Proveedor", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text("Se eliminará del directorio", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20), splashRadius: 20),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(LucideIcons.boxes, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(provider.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (provider.contactName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(provider.contactName, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text("El proveedor será eliminado permanentemente del directorio. Las órdenes de compra existentes no se verán afectadas.", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                        child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          _providerService.deleteProvider(provider.id);
                          Navigator.pop(ctx);
                          _showSnack("Proveedor eliminado correctamente");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text("Eliminar Proveedor", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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
  }
}