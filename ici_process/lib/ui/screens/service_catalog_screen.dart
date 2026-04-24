import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/service_model.dart'; // Importa el modelo nuevo
import '../../models/provider_model.dart';
import '../../services/service_rent_service.dart'; // Importa el servicio nuevo
import '../../services/provider_service.dart';

class ServiceCatalogScreen extends StatefulWidget {
  final UserModel currentUser;
  const ServiceCatalogScreen({super.key, required this.currentUser});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final ServiceRentService _serviceRentService = ServiceRentService();
  final ProviderService _providerService = ProviderService();

  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  List<ServicePriceEntry> _tempPrices = [];
  bool _isUploading = false;
  late Stream<List<ServiceItem>> _servicesStream;
  late Stream<List<Provider>> _providersStream;

  // --- PALETA DE COLORES (Tema Morado para Servicios) ---
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  
  // Color distintivo: Morado/Violeta para servicios intangibles
  final Color _accentColor = const Color(0xFF8B5CF6); 

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_materials');

  @override
  void initState() {
    super.initState();
    _servicesStream = _serviceRentService.getServices();
    _providersStream = _providerService.getProviders();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    if (_nameCtrl.text.isEmpty || _unitCtrl.text.isEmpty) {
      _showSnack("Nombre y Unidad son obligatorios", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      final item = ServiceItem(
        id: docId ?? '',
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        prices: _tempPrices,
      );

      if (docId == null) {
        await _serviceRentService.addService(item);
        _resetForm();
        _showSnack("Servicio registrado correctamente");
      } else {
        await _serviceRentService.updateService(item);
        if (mounted) Navigator.pop(context);
        _showSnack("Servicio actualizado");
      }
    } catch (e) {
      _showSnack("Error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _unitCtrl.clear();
    setState(() => _tempPrices = []);
    FocusScope.of(context).unfocus();
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<ServiceItem> _applyFilter(List<ServiceItem> services) {
    if (_searchQuery.isEmpty) return services;
    final q = _searchQuery.toLowerCase();
    return services.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.unit.toLowerCase().contains(q) ||
      s.prices.any((p) => p.providerName.toLowerCase().contains(q))
    ).toList();
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
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              
              StreamBuilder<List<ServiceItem>>(
                stream: _servicesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allServices = snapshot.data ?? [];
                  final filtered = _applyFilter(allServices);

                  return StreamBuilder<List<Provider>>(
                    stream: _providersStream,
                    builder: (context, providerSnap) {
                      final providers = providerSnap.data ?? [];

                      final listSection = Column(
                        children: [
                          _buildSearchBar(allServices.length),
                          const SizedBox(height: 20),
                          _buildListResults(filtered, allServices.length, providers),
                        ],
                      );

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: listSection),
                            const SizedBox(width: 40),
                            if (canEdit) Expanded(flex: 4, child: _buildForm(providers)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            if (canEdit) ...[_buildForm(providers), const SizedBox(height: 40)],
                            listSection,
                          ],
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSearchBar(int totalCount) {
  return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
              decoration: InputDecoration(
                hintText: "Buscar por nombre, unidad o proveedor...",
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                      )
                    : null,
                filled: true,
                fillColor: _inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.briefcase, size: 16, color: _accentColor),
                const SizedBox(width: 8),
                Text("$totalCount", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _accentColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.calendarClock, color: _accentColor, size: 30),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Catálogo de Servicios y Rentas", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("Gestiona costos indirectos, maquinaria y mano de obra.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListResults(List<ServiceItem> filtered, int totalCount, List<Provider> providers) {
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                _searchQuery.isNotEmpty ? LucideIcons.searchX : LucideIcons.briefcase,
                size: 44,
                color: const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty
                    ? "Sin resultados para \"$_searchQuery\""
                    : "Sin servicios registrados",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                  icon: Icon(LucideIcons.rotateCcw, size: 14, color: _primaryBlue),
                  label: Text("Limpiar búsqueda", style: GoogleFonts.inter(fontSize: 13, color: _primaryBlue, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            filtered.length == totalCount
                ? "$totalCount servicio${totalCount == 1 ? '' : 's'}"
                : "${filtered.length} de $totalCount servicio${totalCount == 1 ? '' : 's'}",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _buildCard(filtered[index], providers),
        ),
      ],
    );
  }

 Widget _buildCard(ServiceItem item, List<Provider> providers) {
    double minPrice = item.prices.isEmpty ? 0 : item.prices.map((e) => e.price).reduce((a, b) => a < b ? a : b);
    double maxPrice = item.prices.isEmpty ? 0 : item.prices.map((e) => e.price).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Fila superior
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor.withOpacity(0.1), _accentColor.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accentColor.withOpacity(0.15)),
                ),
                child: Icon(LucideIcons.briefcase, color: _accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _textPrimary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8.0, // Espacio horizontal entre las etiquetas
                      runSpacing: 8.0, // Espacio vertical si bajan a la siguiente línea
                      children: [
                        // Badge unidad
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.clock, size: 10, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(item.unit, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textSecondary)),
                            ],
                          ),
                        ),
                        // Badge precio
                        if (item.prices.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _accentColor.withOpacity(0.2)),
                            ),
                            child: Text(
                              minPrice == maxPrice
                                  ? "\$${minPrice.toStringAsFixed(2)}"
                                  : "\$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}",
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _accentColor),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text("Sin cotizar", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                          ),
                        // Badge proveedores
                        if (item.prices.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.store, size: 10, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text("${item.prices.length} prov.", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textSecondary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canEdit)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(LucideIcons.edit3, const Color(0xFF2563EB), () => _showEditDialog(item, providers)),
                    const SizedBox(width: 4),
                    _buildActionIcon(LucideIcons.trash2, const Color(0xFFEF4444), () => _confirmDelete(item)),
                  ],
                ),
            ],
          ),

          // Precios por proveedor
          if (item.prices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.store, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text("COSTOS POR PROVEEDOR (${item.prices.length})", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...item.prices.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p.providerName, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500))),
                        Text("\$${p.price.toStringAsFixed(2)}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _textPrimary)),
                        const SizedBox(width: 12),
                        Text(DateFormat('dd/MM/yy').format(p.updatedAt), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // --- FORMULARIO ---
  Widget _buildForm(List<Provider> providers) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue.withOpacity(0.08), _primaryBlue.withOpacity(0.02)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.fileText, color: _primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nuevo Servicio",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text("Completa los datos del servicio",
                        style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ),

          // ── Cuerpo ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Sección: Identificación
                Row(children: [
                  Icon(LucideIcons.fileText, size: 14, color: _textSecondary),
                  const SizedBox(width: 6),
                  Text("IDENTIFICACIÓN DEL SERVICIO", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 12),
                _input(_nameCtrl, "Nombre del Servicio / Renta", LucideIcons.fileText),
                const SizedBox(height: 12),
                _input(_unitCtrl, "Unidad (Día, Mes, Hora)", LucideIcons.clock),

                const SizedBox(height: 24),
                Divider(color: _borderColor, thickness: 1, height: 1),
                const SizedBox(height: 20),

                // Sección: Costos
                Row(children: [
                  Icon(LucideIcons.tags, size: 14, color: _textSecondary),
                  const SizedBox(width: 6),
                  Text("COSTOS POR PROVEEDOR", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 14),

                _PriceManager(
                  providers: providers,
                  initialPrices: _tempPrices,
                  onChanged: (updatedList) {
                    setState(() => _tempPrices = updatedList);
                  },
                ),

                const SizedBox(height: 32),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : () => _handleSave(docId: null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primaryBlue.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ).copyWith(
                      overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.checkCircle, size: 18),
                              const SizedBox(width: 8),
                              Text("Guardar Servicio",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.2)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGOS ---
  void _showEditDialog(ServiceItem item, List<Provider> providers) {
    _nameCtrl.text = item.name;
    _unitCtrl.text = item.unit;
    _tempPrices = List.from(item.prices);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 540,
              constraints: const BoxConstraints(maxHeight: 620),
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                          child: const Center(child: Icon(LucideIcons.calendarClock, color: Colors.white, size: 24)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Editar Servicio", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text(item.name, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () { _resetForm(); Navigator.pop(ctx); }, icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20), splashRadius: 20),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("NOMBRE DEL SERVICIO / RENTA", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(_nameCtrl, "Ej. Renta de Retroexcavadora", LucideIcons.fileText),
                          const SizedBox(height: 20),
                          Text("UNIDAD", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(_unitCtrl, "Ej. Día, Mes, Hora", LucideIcons.clock),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(LucideIcons.dollarSign, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Text("COSTOS POR PROVEEDOR", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PriceManager(
                            providers: providers,
                            initialPrices: _tempPrices,
                            onChanged: (updated) { setModalState(() => _tempPrices = updated); },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () { _resetForm(); Navigator.pop(ctx); },
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                            child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : () => _handleSave(docId: item.id),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: _isUploading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const Icon(LucideIcons.save, size: 18), const SizedBox(width: 8),
                                    Text("Guardar Cambios", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ]),
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
    ).then((_) => _resetForm());
  }

  void _confirmDelete(ServiceItem item) {
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20)),
            ],
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
                          Text("Eliminar Servicio", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text("Se eliminará del catálogo", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
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
                            child: const Icon(LucideIcons.calendarClock, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(item.unit, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            child: Text("El servicio será eliminado permanentemente del catálogo. Las cotizaciones que lo referencien no se verán afectadas.", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500, height: 1.4)),
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
                          _serviceRentService.deleteService(item.id);
                          Navigator.pop(ctx);
                          _showSnack("Servicio eliminado correctamente");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text("Eliminar Servicio", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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

  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true, fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

// --------------------------------------------------------
// ✅ WIDGET MANAGER DE PRECIOS (ADAPTADO A ServicePriceEntry)
// --------------------------------------------------------
class _PriceManager extends StatefulWidget {
  final List<Provider> providers;
  final List<ServicePriceEntry> initialPrices;
  final Function(List<ServicePriceEntry>) onChanged;

  const _PriceManager({required this.providers, required this.initialPrices, required this.onChanged});

  @override
  State<_PriceManager> createState() => _PriceManagerState();
}

class _PriceManagerState extends State<_PriceManager> {
  late List<ServicePriceEntry> prices;
  Provider? selectedProvider;
  final TextEditingController priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    prices = List.from(widget.initialPrices);
  }

  @override
  void didUpdateWidget(_PriceManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrices != widget.initialPrices) {
      prices = List.from(widget.initialPrices);
    }
  }

  void _addPrice() {
    if (selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona un proveedor")));
      return;
    }
    if (priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escribe un precio")));
      return;
    }
    
    final val = double.tryParse(priceCtrl.text);
    if (val == null) return;

    final newEntry = ServicePriceEntry(
      providerId: selectedProvider!.id,
      providerName: selectedProvider!.name,
      price: val,
      updatedAt: DateTime.now(),
    );

    setState(() {
      final index = prices.indexWhere((p) => p.providerId == selectedProvider!.id);
      if (index >= 0) {
        prices[index] = newEntry;
      } else {
        prices.add(newEntry);
      }
      priceCtrl.clear();
      selectedProvider = null; 
    });
    
    widget.onChanged(prices);
  }

  void _removePrice(int index) {
    setState(() => prices.removeAt(index));
    widget.onChanged(prices);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: selectedProvider?.id,
                hint: const Text("Proveedor", style: TextStyle(fontSize: 13)),
                isExpanded: true,
                items: widget.providers.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (id) {
                  setState(() {
                    selectedProvider = widget.providers.firstWhere((p) => p.id == id);
                  });
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  filled: true, fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "\$ Precio",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true, fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addPrice,
              icon: const Icon(LucideIcons.plusCircle, color: Color(0xFF2563EB)),
              tooltip: "Agregar a la lista",
            )
          ],
        ),
        const SizedBox(height: 12),
        if (prices.isEmpty) 
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text("Agrega proveedores arriba", style: TextStyle(color: Colors.grey, fontSize: 12))),
          )
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: prices.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: idx < prices.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))) : null
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.providerName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      Text("\$${p.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd/MM').format(p.updatedAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 8),
                      InkWell(onTap: () => _removePrice(idx), child: const Icon(LucideIcons.trash2, size: 16, color: Colors.red))
                    ],
                  ),
                );
              }).toList(),
            ),
          )
      ],
    );
  }
}