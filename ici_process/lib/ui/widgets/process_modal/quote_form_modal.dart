import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../models/process_model.dart';
import '../../../models/quotation_model.dart';
import '../../../models/material_model.dart';
import '../../../models/service_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/admin_config_model.dart';
import '../../../services/process_service.dart';
import '../../../services/material_service.dart';
import '../../../services/service_rent_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/admin_service.dart';

class QuoteFormModal extends StatefulWidget {
  final ProcessModel process;
  const QuoteFormModal({super.key, required this.process});

  @override
  State<QuoteFormModal> createState() => _QuoteFormModalState();
}

class _QuoteFormModalState extends State<QuoteFormModal> {
  late QuotationModel data;

  final ProcessService _processService = ProcessService();
  final MaterialService _materialService = MaterialService();
  final ServiceRentService _serviceRentService = ServiceRentService();
  final VehicleService _vehicleService = VehicleService();
  final AdminService _adminService = AdminService();

  List<MaterialItem> _materialsDB = [];
  List<ServiceItem> _servicesDB = [];
  List<Vehicle> _vehiclesDB = [];
  List<LaborCategory> _laborCategoriesDB = [];

  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _priceDisplayFormat = NumberFormat('#,##0.00');

  // ─── FLAG PARA DETECTAR CAMBIOS ───
  bool _hasUnsavedChanges = false;
  late String _initialDataSnapshot;

  // --- PALETA DE COLORES ---
  final Color _primaryColor = const Color(0xFF0F172A);
  final Color _accentColor = const Color(0xFF2563EB);
  final Color _bgColor = const Color(0xFFF1F5F9);
  final Color _surfaceColor = Colors.white;
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _textColor = const Color(0xFF334155);
  final Color _labelColor = const Color(0xFF64748B);

  // ─── NUEVO: color de borde más oscuro para dropdowns ───
  final Color _dropdownBorderColor = const Color(0xFF475569); // slate-600
  final Color _dropdownFillColor = const Color(0xFFF8FAFC);  // slate-50

  // Colores por sección (accent lateral)
  static const Color _matColor   = Color(0xFF2563EB); // azul
  static const Color _specColor  = Color(0xFF7C3AED); // violeta
  static const Color _indColor   = Color(0xFFF59E0B); // ámbar
  static const Color _vehColor   = Color(0xFF0D9488); // teal
  static const Color _laborColor = Color(0xFF16A34A); // verde

  // Colores semánticos unificados
  static const Color _sectionTotalColor  = Color(0xFF16A34A);
  static const Color _subtotalColor      = Color(0xFF475569);

  // Secciones expandidas
  final Map<String, bool> _expanded = {
    'mat': false,
    'spec': false,
    'ind': false,
    'veh': false,
    'labor': false,
  };

  // Controllers
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  // ─── NUEVO: formatters reutilizables para campos numéricos ───
  // Solo enteros positivos
  List<TextInputFormatter> get _intOnlyFormatters => [
        FilteringTextInputFormatter.digitsOnly,
      ];

  // Números decimales (permite un solo punto)
  List<TextInputFormatter> get _decimalFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = newValue.text;
          // Solo permite un punto decimal
          if (text.split('.').length > 2) return oldValue;
          return newValue;
        }),
      ];

  // Precios con formato de miles (comas permitidas mientras se edita)
  List<TextInputFormatter> get _priceFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = newValue.text;
          // No permitir más de un punto decimal (ignorando comas)
          final withoutCommas = text.replaceAll(',', '');
          if (withoutCommas.split('.').length > 2) return oldValue;
          return newValue;
        }),
      ];

  String _formatNumber(double value) {
    if (value == 0) return '';
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return double.parse(value.toStringAsFixed(2)).toString();
  }

  @override
  void initState() {
    super.initState();
    if (widget.process.quotationData != null) {
      data = QuotationModel.fromMap(widget.process.quotationData!);
    } else {
      data = QuotationModel();
      data.travel.foodCostPerDay   = 0;
      data.travel.lodgingCostPerDay = 0;
      data.travel.peopleCount      = 0;
      data.travel.days             = 0;
    }
    // Snapshot inicial para detectar cambios
    _initialDataSnapshot = data.toMap().toString();
    _loadCatalogs();
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) c.dispose();
    for (final c in _qtyControllers.values) c.dispose();
    super.dispose();
  }

  // ─── NUEVO: marca cambios pendientes ───
  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      _hasUnsavedChanges = true;
    }
  }

  bool _checkHasChanges() {
    return _hasUnsavedChanges ||
        data.toMap().toString() != _initialDataSnapshot;
  }

  TextEditingController _getPriceController(String id, double value) {
    if (!_priceControllers.containsKey(id)) {
      _priceControllers[id] = TextEditingController(
        text: value == 0 ? '' : _priceDisplayFormat.format(value),
      );
    }
    return _priceControllers[id]!;
  }

  TextEditingController _getQtyController(String id, double value) {
    if (!_qtyControllers.containsKey(id)) {
      _qtyControllers[id] = TextEditingController(text: _formatNumber(value));
    }
    return _qtyControllers[id]!;
  }

  void _updatePriceController(String id, double newPrice) {
    if (_priceControllers.containsKey(id)) {
      _priceControllers[id]!.text =
          newPrice == 0 ? '' : _priceDisplayFormat.format(newPrice);
    }
  }

  double _parsePriceText(String text) =>
      double.tryParse(text.replaceAll(',', '')) ?? 0;

  Future<void> _loadCatalogs() async {
    try {
      final mats  = await _materialService.getMaterials().first;
      final servs = await _serviceRentService.getServices().first;
      final vecs  = await _vehicleService.getVehicles().first;
      final labor = await _adminService.getLaborCategories().first;
      if (mounted) {
        setState(() {
          _materialsDB       = mats;
          _servicesDB        = servs;
          _vehiclesDB        = vecs;
          _laborCategoriesDB = labor;
          _isLoading         = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- APOYO ---
  String _getProviderName(String itemName, double unitPrice, bool isService) {
    try {
      dynamic item = isService
          ? _servicesDB.firstWhere((s) => s.name == itemName)
          : _materialsDB.firstWhere((m) => m.name == itemName);
      final priceEntry = item.prices.firstWhere((p) => p.price == unitPrice);
      return priceEntry.providerName;
    } catch (_) {
      return 'Proveedor manual / No encontrado';
    }
  }

  void _onMaterialSelected(int index, MaterialItem item) {
    _markAsChanged();
    setState(() {
      data.materials[index].name = item.name;
      if (item.prices.isNotEmpty) {
        final sorted = List.from(item.prices)
          ..sort((a, b) => a.price.compareTo(b.price));
        data.materials[index].unitPrice = sorted.first.price;
        _updatePriceController('mat_price_$index', sorted.first.price);
      } else {
        data.materials[index].unitPrice = 0;
        _updatePriceController('mat_price_$index', 0);
      }
    });
  }

  void _onServiceSelected(int index, ServiceItem item) {
    _markAsChanged();
    setState(() {
      data.indirects[index].name = item.name;
      if (item.prices.isNotEmpty) {
        final sorted = List.from(item.prices)
          ..sort((a, b) => a.price.compareTo(b.price));
        data.indirects[index].unitPrice = sorted.first.price;
        _updatePriceController('ind_price_$index', sorted.first.price);
      } else {
        data.indirects[index].unitPrice = 0;
        _updatePriceController('ind_price_$index', 0);
      }
    });
  }

  // --- CÁLCULOS ---
  double get materialTotal  => data.materials.fold(0, (s, i) => s + i.quantity * i.unitPrice);
  double get specialtyTotal => data.specialties.fold(0, (s, i) => s + i.quantity * i.unitPrice);
  double get indirectTotal  => data.indirects.fold(0, (s, i) => s + i.quantity * i.unitPrice);

  double _calculateVehicleRow(VehicleQuote v) {
    try {
      final obj = _vehiclesDB.firstWhere((db) => db.id == v.vehicleId);
      final fuel = obj.kmPerLiter > 0
          ? (v.distance / obj.kmPerLiter) * obj.gasPrice
          : 0.0;
      return fuel + v.distance * obj.costPerKm + v.tolls;
    } catch (_) {
      return 0;
    }
  }

  double get vehicleTotal =>
      data.vehicles.fold(0, (s, v) => s + _calculateVehicleRow(v));

  double _calculateLaborRow(LaborQuote l) {
    try {
      final cat = _laborCategoriesDB.firstWhere((c) => c.id == l.categoryId);
      return cat.baseDailySalary * l.quantity * l.days * 1.27;
    } catch (_) {
      return 0;
    }
  }

  double get laborTotal =>
      data.labor.fold(0, (s, l) => s + _calculateLaborRow(l));

  double get travelTotal {
    if (!data.travel.enabled) return 0;
    return (data.travel.foodCostPerDay + data.travel.lodgingCostPerDay) *
        data.travel.days *
        data.travel.peopleCount;
  }

  double get directCostTotal =>
      materialTotal + specialtyTotal + indirectTotal + vehicleTotal + laborTotal + travelTotal;
  double get finalPrice => directCostTotal * (1 + data.protectionRate);

  // --- GUARDAR ---
  Future<void> _handleSave() async {
    final updated = ProcessModel(
      id: widget.process.id,
      title: widget.process.title,
      client: widget.process.client,
      requestedBy: widget.process.requestedBy,
      requestDate: widget.process.requestDate,
      stage: widget.process.stage,
      description: widget.process.description,
      priority: widget.process.priority,
      history: widget.process.history,
      comments: widget.process.comments,
      updatedAt: DateTime.now(),
      amount: finalPrice,
      estimatedCost: directCostTotal,
      quotationData: data.toMap(),
    );
    await _processService.updateProcess(updated);
    _hasUnsavedChanges = false;
    if (mounted) Navigator.pop(context);
  }

  // ─── NUEVO: DIÁLOGO DE CONFIRMACIÓN AL CERRAR SIN GUARDAR ───
  Future<bool> _confirmClose() async {
    if (!_checkHasChanges()) return true;

    final result = await showDialog<bool>(
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

              // ── HEADER ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFEF2F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.alertTriangle,
                        color: Color(0xFFEA580C),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cambios sin guardar',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'La cotización tiene modificaciones pendientes',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(
                        LucideIcons.x,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // ── CONTENIDO ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Tarjeta identificadora del proceso
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
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
                              color: _accentColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              LucideIcons.calculator,
                              size: 16,
                              color: _accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.process.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cotizador activo · cambios no confirmados',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _labelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Advertencia de pérdida de datos
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Si sales ahora, todos los cambios realizados en materiales, costos, mano de obra y viáticos se perderán de forma permanente.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tip informativo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.info,
                            size: 14,
                            color: Color(0xFF0369A1),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF0C4A6E),
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                                children: const [
                                  TextSpan(text: 'Presiona '),
                                  TextSpan(
                                    text: '"Guardar Cotización"',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  TextSpan(
                                      text: ' antes de cerrar para conservar tu trabajo.'),
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

              // ── FOOTER ───────────────────────────────────────
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
                          'Seguir editando',
                          style: GoogleFonts.inter(
                            color: _labelColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(LucideIcons.logOut, size: 16),
                        label: Text(
                          'Salir sin guardar',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
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

    return result ?? false;
  }

  Future<void> _handleClose() async {
    final canClose = await _confirmClose();
    if (canClose && mounted) Navigator.pop(context);
  }

  // --- DIALOG PROVEEDOR ---
  void _showProviderSelectionDialog(QuoteItem item, bool isService,
      {String? priceControllerId}) {
    dynamic dbItem;
    if (isService) {
      try { dbItem = _servicesDB.firstWhere((s) => s.name == item.name); } catch (_) {}
    } else {
      try { dbItem = _materialsDB.firstWhere((m) => m.name == item.name); } catch (_) {}
    }

    if (dbItem == null || dbItem.prices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(LucideIcons.alertCircle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text("No hay proveedores para '${item.name}'",
              style: GoogleFonts.inter()),
        ]),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final prices = dbItem.prices as List;
    final bestPrice =
        prices.map((p) => p.price as double).reduce((a, b) => a < b ? a : b);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.all(24),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.all(24),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(
                isService ? LucideIcons.briefcase : LucideIcons.package,
                color: Colors.blue.shade700,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seleccionar Proveedor',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(item.name,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
        content: SizedBox(
          width: 450,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: prices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final p = prices[i];
              final isSelected = item.unitPrice == p.price;
              final isBest = p.price == bestPrice;
              return InkWell(
                onTap: () {
                  _markAsChanged();
                  setState(() => item.unitPrice = p.price);
                  if (priceControllerId != null)
                    _updatePriceController(priceControllerId, p.price);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? Colors.blue.shade50 : Colors.white,
                    border: Border.all(
                        color: isSelected
                            ? Colors.blue.shade300
                            : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected
                            ? _accentColor
                            : Colors.grey.shade400,
                        size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.providerName,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: _textColor)),
                            Text(
                                'Actualizado: ${DateFormat('dd/MM/yy').format(p.updatedAt)}',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: Colors.grey)),
                          ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text(currencyFormat.format(p.price),
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _primaryColor)),
                      if (isBest)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('Mejor Precio',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700)),
                        ),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancelar')),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final screenWidth = MediaQuery.of(context).size.width;
    final bool mobile = screenWidth < 800;

    // ─── NUEVO: PopScope para interceptar el back del sistema/ESC ───
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canClose = await _confirmClose();
        if (canClose && mounted) Navigator.pop(context);
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _bgColor,
        insetPadding: EdgeInsets.all(mobile ? 0 : 20),
        child: SizedBox(
          width: mobile ? double.infinity : 900,
          height: mobile ? double.infinity : 920,
          child: Column(children: [
            _buildHeader(),
            Expanded(child: _buildBody(mobile)),
            _buildStickyTotalBar(),
            _buildFooter(mobile),
          ]),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final mobile = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: mobile ? 16 : 28, vertical: mobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(LucideIcons.calculator,
              color: _accentColor, size: mobile ? 18 : 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Cotizador',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _labelColor,
                    letterSpacing: 0.6)),
            Text(widget.process.title,
                style: GoogleFonts.inter(
                    fontSize: mobile ? 14 : 17,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconButton(
            onPressed: _handleClose,
            icon: Icon(LucideIcons.x, color: _labelColor, size: 20)),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  BODY
  // ────────────────────────────────────────────────────────────────
  Widget _buildBody(bool mobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(mobile ? 14 : 24),
      child: Column(children: [
        _buildAccordionSection(
          key: 'mat',
          title: 'Insumos y Materiales',
          icon: LucideIcons.package,
          accentColor: _matColor,
          itemCount: data.materials.length,
          subtotal: materialTotal,
          child: _buildMaterialList(data.materials),
        ),
        const SizedBox(height: 10),
        _buildAccordionSection(
          key: 'spec',
          title: 'Especialidades / Subcontratos',
          icon: LucideIcons.wrench,
          accentColor: _specColor,
          itemCount: data.specialties.length,
          subtotal: specialtyTotal,
          child: _buildSpecialtiesList(data.specialties),
        ),
        const SizedBox(height: 10),
        _buildAccordionSection(
          key: 'ind',
          title: 'Servicios Indirectos (Rentas)',
          icon: LucideIcons.briefcase,
          accentColor: _indColor,
          itemCount: data.indirects.length,
          subtotal: indirectTotal,
          child: _buildIndirectList(data.indirects),
        ),
        const SizedBox(height: 10),
        _buildAccordionSection(
          key: 'veh',
          title: 'Logística y Transporte',
          icon: LucideIcons.truck,
          accentColor: _vehColor,
          itemCount: data.vehicles.length,
          subtotal: vehicleTotal,
          child: _buildVehiclesSection(),
        ),
        const SizedBox(height: 10),
        _buildAccordionSection(
          key: 'labor',
          title: 'Mano de Obra y Viáticos',
          icon: LucideIcons.users,
          accentColor: _laborColor,
          itemCount: data.labor.length,
          subtotal: laborTotal + travelTotal,
          child: _buildLaborBody(),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  ACORDEÓN
  // ────────────────────────────────────────────────────────────────
  Widget _buildAccordionSection({
    required String key,
    required String title,
    required IconData icon,
    required Color accentColor,
    required int itemCount,
    required double subtotal,
    required Widget child,
  }) {
    final bool expanded = _expanded[key] ?? true;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded[key] = !expanded),
          borderRadius: expanded
              ? const BorderRadius.vertical(top: Radius.circular(14))
              : BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: expanded
                  ? const BorderRadius.vertical(top: Radius.circular(13))
                  : BorderRadius.circular(13),
            ),
            child: Row(children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: accentColor, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                          letterSpacing: 0.7)),
                  const SizedBox(height: 1),
                  Text('$itemCount partida${itemCount != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _labelColor)),
                ]),
              ),
              if (subtotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _sectionTotalColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: _sectionTotalColor.withOpacity(0.25))),
                  child: Text(
                    currencyFormat.format(subtotal),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _sectionTotalColor),
                  ),
                )
              else
                Text('Sin cargo',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _labelColor)),
              const SizedBox(width: 10),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(LucideIcons.chevronDown,
                    size: 16, color: _labelColor),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(children: [
            Divider(height: 1, color: _borderColor),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ]),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  LISTAS GENÉRICAS
  // ────────────────────────────────────────────────────────────────
  Widget _buildMaterialList(List<QuoteItem> items) {
    return _buildGenericList(
      items: items,
      total: materialTotal,
      addButtonText: 'Agregar Material',
      isService: false,
      idPrefix: 'mat',
      accentColor: _matColor,
      itemBuilder: (index, item) {
        final providerName =
            _getProviderName(item.name, item.unitPrice, false);
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Autocomplete<MaterialItem>(
            optionsBuilder: (tv) => tv.text.isEmpty
                ? _materialsDB
                : _materialsDB.where((m) =>
                    m.name.toLowerCase().contains(tv.text.toLowerCase())),
            displayStringForOption: (o) => o.name,
            onSelected: (s) => _onMaterialSelected(index, s),
            fieldViewBuilder: (ctx, ctrl, fn, oec) {
              if (ctrl.text.isEmpty && item.name.isNotEmpty && !fn.hasFocus)
                ctrl.text = item.name;
              return _buildInput(ctrl, 'Buscar material...',
                  focusNode: fn,
                  onChanged: (v) { _markAsChanged(); item.name = v; });
            },
            optionsViewBuilder: (ctx, onSel, opts) =>
                _buildDropdownOptions(ctx, onSel, opts),
          ),
          if (item.name.isNotEmpty)
            _buildProviderBadge(
              providerName,
              item.unitPrice,
              () => _showProviderSelectionDialog(item, false,
                  priceControllerId: 'mat_price_$index'),
            ),
        ]);
      },
    );
  }

  Widget _buildIndirectList(List<QuoteItem> items) {
    return _buildGenericList(
      items: items,
      total: indirectTotal,
      addButtonText: 'Agregar Servicio Indirecto',
      isService: true,
      idPrefix: 'ind',
      accentColor: _indColor,
      itemBuilder: (index, item) {
        final providerName =
            _getProviderName(item.name, item.unitPrice, true);
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Autocomplete<ServiceItem>(
            optionsBuilder: (tv) => tv.text.isEmpty
                ? _servicesDB
                : _servicesDB.where((s) =>
                    s.name.toLowerCase().contains(tv.text.toLowerCase())),
            displayStringForOption: (o) => o.name,
            onSelected: (s) => _onServiceSelected(index, s),
            fieldViewBuilder: (ctx, ctrl, fn, oec) {
              if (ctrl.text.isEmpty && item.name.isNotEmpty && !fn.hasFocus)
                ctrl.text = item.name;
              return _buildInput(ctrl, 'Buscar servicio...',
                  focusNode: fn,
                  onChanged: (v) { _markAsChanged(); item.name = v; });
            },
            optionsViewBuilder: (ctx, onSel, opts) =>
                _buildDropdownOptions(ctx, onSel, opts),
          ),
          if (item.name.isNotEmpty)
            _buildProviderBadge(
              providerName,
              item.unitPrice,
              () => _showProviderSelectionDialog(item, true,
                  priceControllerId: 'ind_price_$index'),
              isService: true,
            ),
        ]);
      },
    );
  }

  Widget _buildSpecialtiesList(List<QuoteItem> items) {
    return _buildGenericList(
      items: items,
      total: specialtyTotal,
      addButtonText: 'Agregar Especialidad',
      isService: false,
      idPrefix: 'spec',
      accentColor: _specColor,
      itemBuilder: (index, item) => TextFormField(
        initialValue: item.name,
        onChanged: (val) { _markAsChanged(); item.name = val; },
        decoration: _inputDecoration('Descripción...'),
        style: GoogleFonts.inter(fontSize: 13),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  LISTA GENÉRICA
  // ────────────────────────────────────────────────────────────────
  Widget _buildGenericList({
    required List<QuoteItem> items,
    required double total,
    required String addButtonText,
    required bool isService,
    required String idPrefix,
    required Color accentColor,
    required Widget Function(int, QuoteItem) itemBuilder,
  }) {
    final mobile = MediaQuery.of(context).size.width < 800;

    return Column(children: [
      if (!mobile && items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          child: Row(children: [
            Expanded(flex: 5,
                child: Text('DESCRIPCIÓN',
                    style: _colHeader())),
            const SizedBox(width: 12),
            SizedBox(
                width: 80,
                child: Text('CANT.',
                    textAlign: TextAlign.center,
                    style: _colHeader())),
            const SizedBox(width: 12),
            Expanded(
                flex: 2,
                child: Text('P. UNIT.',
                    textAlign: TextAlign.center,
                    style: _colHeader())),
            const SizedBox(width: 40),
          ]),
        ),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => mobile
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: _borderColor, height: 1))
            : const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final priceCtrl =
              _getPriceController('${idPrefix}_price_$i', item.unitPrice);
          final qtyCtrl =
              _getQtyController('${idPrefix}_qty_$i', item.quantity);

          if (mobile) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(child: itemBuilder(i, item)),
                _deleteButton(() {
                  _markAsChanged();
                  _priceControllers.remove('${idPrefix}_price_$i')?.dispose();
                  _qtyControllers.remove('${idPrefix}_qty_$i')?.dispose();
                  setState(() => items.removeAt(i));
                }),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: _decimalFormatters, // ← SOLO NÚMEROS
                    onChanged: (v) {
                      _markAsChanged();
                      setState(() => item.quantity = double.tryParse(v) ?? 0);
                    },
                    decoration:
                        _inputDecoration('Cantidad', isCenter: true),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: _priceFormatters, // ← SOLO NÚMEROS
                    onChanged: (v) {
                      _markAsChanged();
                      setState(
                          () => item.unitPrice = _parsePriceText(v));
                    },
                    onEditingComplete: () {
                      priceCtrl.text = item.unitPrice == 0
                          ? ''
                          : _priceDisplayFormat.format(item.unitPrice);
                    },
                    decoration: _inputDecoration('\$ P.U.').copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.search, size: 14),
                        onPressed: () => _showProviderSelectionDialog(
                            item, isService,
                            priceControllerId: '${idPrefix}_price_$i'),
                      ),
                    ),
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ]);
          }

          // Desktop row
          return Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Expanded(flex: 5, child: itemBuilder(i, item)),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalFormatters, // ← SOLO NÚMEROS
                onChanged: (v) {
                  _markAsChanged();
                  setState(() => item.quantity = double.tryParse(v) ?? 0);
                },
                decoration: _inputDecoration('Cant.', isCenter: true),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _priceFormatters, // ← SOLO NÚMEROS
                onChanged: (v) {
                  _markAsChanged();
                  setState(() => item.unitPrice = _parsePriceText(v));
                },
                onEditingComplete: () {
                  priceCtrl.text = item.unitPrice == 0
                      ? ''
                      : _priceDisplayFormat.format(item.unitPrice);
                },
                decoration: _inputDecoration('\$ PU').copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(LucideIcons.search, size: 14),
                    onPressed: () => _showProviderSelectionDialog(
                        item, isService,
                        priceControllerId: '${idPrefix}_price_$i'),
                    tooltip: 'Ver proveedores',
                  ),
                ),
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            _deleteButton(() {
              _markAsChanged();
              _priceControllers.remove('${idPrefix}_price_$i')?.dispose();
              _qtyControllers.remove('${idPrefix}_qty_$i')?.dispose();
              setState(() => items.removeAt(i));
            }),
          ]);
        },
      ),
      const SizedBox(height: 12),
      Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        TextButton.icon(
          onPressed: () {
            _markAsChanged();
            setState(
                () => items.add(QuoteItem(id: DateTime.now().toString())));
          },
          icon: Icon(LucideIcons.plusCircle, size: 15, color: accentColor),
          label: Text(
            mobile ? 'Agregar' : addButtonText,
            style: GoogleFonts.inter(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: mobile ? 12 : 13),
          ),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        if (total > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _subtotalColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _subtotalColor.withOpacity(0.2))),
            child: Text(
              'Subtotal: ${currencyFormat.format(total)}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _subtotalColor),
            ),
          ),
      ]),
    ]);
  }

  // ────────────────────────────────────────────────────────────────
  //  VEHÍCULOS
  // ────────────────────────────────────────────────────────────────
  Widget _buildVehiclesSection() {
    final mobile = MediaQuery.of(context).size.width < 800;
    return Column(children: [
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.vehicles.length,
        separatorBuilder: (_, __) =>
            Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: _borderColor)),
        itemBuilder: (ctx, i) {
          final v = data.vehicles[i];
          final rowTotal = _calculateVehicleRow(v);
          return Column(children: [
            Row(children: [
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: _vehiclesDB.any((x) => x.id == v.vehicleId)
                      ? v.vehicleId
                      : null,
                  expandedInsets: EdgeInsets.zero,
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(_surfaceColor),
                    elevation: WidgetStateProperty.all(8),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    filled: true,
                    fillColor: _surfaceColor,          // ← blanco, igual que los otros campos
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,     // ← sin borde por defecto
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _borderColor, width: 1.0), // ← gris suave
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _accentColor, width: 1.8), // ← azul al enfocar
                    ),
                  ),
                  textStyle: GoogleFonts.inter(fontSize: 13, color: _textColor),
                  trailingIcon: Icon(
                      LucideIcons.chevronDown, size: 16, color: _dropdownBorderColor),
                  selectedTrailingIcon: Icon(
                      LucideIcons.chevronUp, size: 16, color: _dropdownBorderColor),
                  dropdownMenuEntries: _vehiclesDB
                      .map((db) => DropdownMenuEntry<String>(
                            value: db.id,
                            label: mobile
                                ? db.model
                                : '${db.model} (${db.kmPerLiter}km/l)',
                            style: MenuItemButton.styleFrom(
                              textStyle: GoogleFonts.inter(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onSelected: (val) {
                    if (val != null) {
                      _markAsChanged();
                      setState(() => v.vehicleId = val);
                    }
                  },
                ),
              ),
              _deleteButton(() {
                _markAsChanged();
                setState(() => data.vehicles.remove(v));
              }),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _buildInput(null, 'Días',
                      initialValue: _formatNumber(v.days),
                      numericType: NumericType.decimal,
                      onChanged: (val) {
                        _markAsChanged();
                        setState(
                            () => v.days = double.tryParse(val) ?? 0);
                      })),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildInput(null, 'Km Total',
                      initialValue: _formatNumber(v.distance),
                      numericType: NumericType.decimal,
                      onChanged: (val) {
                        _markAsChanged();
                        setState(
                            () => v.distance = double.tryParse(val) ?? 0);
                      })),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildInput(null, 'Casetas \$',
                      initialValue: _formatNumber(v.tolls),
                      numericType: NumericType.decimal,
                      onChanged: (val) {
                        _markAsChanged();
                        setState(
                            () => v.tolls = double.tryParse(val) ?? 0);
                      })),
            ]),
            if (rowTotal > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      'Costo: ${currencyFormat.format(rowTotal)}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _subtotalColor)),
                ),
              ),
          ]);
        },
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () {
          _markAsChanged();
          setState(() => data.vehicles.add(VehicleQuote(
              id: DateTime.now().toString(),
              vehicleId: _vehiclesDB.isNotEmpty ? _vehiclesDB.first.id : '')));
        },
        icon: Icon(LucideIcons.plusCircle, size: 15, color: _vehColor),
        label: Text('Agregar Vehículo',
            style: GoogleFonts.inter(
                color: _vehColor,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      if (vehicleTotal > 0) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _subtotalColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _subtotalColor.withOpacity(0.2))),
            child: Text(
              'Subtotal: ${currencyFormat.format(vehicleTotal)}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _subtotalColor),
            ),
          ),
        ]),
      ],
    ]);
  }

  // ────────────────────────────────────────────────────────────────
  //  MANO DE OBRA
  // ────────────────────────────────────────────────────────────────
  Widget _buildLaborBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4, right: 44),
        child: Row(children: [
          Expanded(flex: 4, child: Text('PUESTO', style: _colHeader())),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: Text('CANT.',
                  textAlign: TextAlign.center, style: _colHeader())),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: Text('DÍAS',
                  textAlign: TextAlign.center, style: _colHeader())),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: Text('COSTO',
                  textAlign: TextAlign.right, style: _colHeader())),
        ]),
      ),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.labor.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final l = data.labor[i];
          final rowCost = _calculateLaborRow(l);
          return Row(children: [
            Expanded(
              flex: 4,
              child: DropdownMenu<String>(
                initialSelection:
                    _laborCategoriesDB.any((c) => c.id == l.categoryId)
                        ? l.categoryId
                        : null,
                expandedInsets: EdgeInsets.zero,
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(_surfaceColor),
                  elevation: WidgetStateProperty.all(8),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  filled: true,
                  fillColor: _surfaceColor,          // ← blanco, igual que los otros campos
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,     // ← sin borde por defecto
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor, width: 1.0), // ← gris suave
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _accentColor, width: 1.8), // ← azul al enfocar
                  ),
                ),
                textStyle: GoogleFonts.inter(fontSize: 13, color: _textColor),
                trailingIcon: Icon(
                    LucideIcons.chevronDown, size: 16, color: _dropdownBorderColor),
                selectedTrailingIcon: Icon(
                    LucideIcons.chevronUp, size: 16, color: _dropdownBorderColor),
                dropdownMenuEntries: _laborCategoriesDB
                    .map((c) => DropdownMenuEntry<String>(
                          value: c.id,
                          label: c.name,
                          style: MenuItemButton.styleFrom(
                            textStyle: GoogleFonts.inter(fontSize: 13),
                          ),
                        ))
                    .toList(),
                onSelected: (val) {
                  if (val != null) {
                    _markAsChanged();
                    setState(() => l.categoryId = val);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _buildInput(null, '1',
                    isCenter: true,
                    initialValue: _formatNumber(l.quantity),
                    numericType: NumericType.decimal,
                    onChanged: (val) {
                      _markAsChanged();
                      setState(
                          () => l.quantity = double.tryParse(val) ?? 0);
                    })),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _buildInput(null, '1',
                    isCenter: true,
                    initialValue: _formatNumber(l.days),
                    numericType: NumericType.decimal,
                    onChanged: (val) {
                      _markAsChanged();
                      setState(
                          () => l.days = double.tryParse(val) ?? 0);
                    })),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(currencyFormat.format(rowCost),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _sectionTotalColor)),
            ),
            _deleteButton(() {
              _markAsChanged();
              setState(() => data.labor.remove(l));
            }),
          ]);
        },
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () {
          _markAsChanged();
          setState(() => data.labor.add(LaborQuote(
              id: DateTime.now().toString(),
              categoryId: _laborCategoriesDB.isNotEmpty
                  ? _laborCategoriesDB.first.id
                  : '')));
        },
        icon: Icon(LucideIcons.plusCircle, size: 15, color: _laborColor),
        label: Text('Agregar Puesto',
            style: GoogleFonts.inter(
                color: _laborColor,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      const SizedBox(height: 16),
      // ── Viáticos ──
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _laborColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _laborColor.withOpacity(0.15))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: data.travel.enabled,
                activeColor: _laborColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged: (v) {
                  _markAsChanged();
                  setState(() => data.travel.enabled = v!);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('Incluir Viáticos (Comidas y Hospedaje)',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _laborColor)),
          ]),
          if (data.travel.enabled) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _buildInput(null, 'Comidas (\$/día/pers)',
                      initialValue: _formatNumber(
                          data.travel.foodCostPerDay),
                      numericType: NumericType.decimal,
                      onChanged: (v) {
                        _markAsChanged();
                        setState(() =>
                            data.travel.foodCostPerDay =
                                double.tryParse(v) ?? 0);
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInput(null, 'Hospedaje (\$/día/pers)',
                      initialValue: _formatNumber(
                          data.travel.lodgingCostPerDay),
                      numericType: NumericType.decimal,
                      onChanged: (v) {
                        _markAsChanged();
                        setState(() =>
                            data.travel.lodgingCostPerDay =
                                double.tryParse(v) ?? 0);
                      })),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _buildInput(null, 'No. Personas',
                      initialValue:
                          _formatNumber(data.travel.peopleCount),
                      numericType: NumericType.integer,
                      onChanged: (v) {
                        _markAsChanged();
                        setState(() =>
                            data.travel.peopleCount =
                                double.tryParse(v) ?? 0);
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInput(null, 'No. Días',
                      initialValue: _formatNumber(data.travel.days),
                      numericType: NumericType.integer,
                      onChanged: (v) {
                        _markAsChanged();
                        setState(() =>
                            data.travel.days =
                                double.tryParse(v) ?? 0);
                      })),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                  'Viáticos Total: ${currencyFormat.format(travelTotal)}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _laborColor)),
            ),
          ],
        ]),
      ),
      if (laborTotal + travelTotal > 0) ...[
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _subtotalColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _subtotalColor.withOpacity(0.2))),
            child: Text(
              'Subtotal: ${currencyFormat.format(laborTotal + travelTotal)}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _subtotalColor),
            ),
          ),
        ]),
      ],
    ]);
  }

  // ────────────────────────────────────────────────────────────────
  //  BARRA TOTAL STICKY
  // ────────────────────────────────────────────────────────────────
  Widget _buildStickyTotalBar() {
    final mobile = MediaQuery.of(context).size.width < 800;
    final marginPercent = (data.protectionRate * 100).round();
    final profit = finalPrice - directCostTotal;

    if (mobile) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _marginField(marginPercent, compact: true),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _totalLabel(
                    'Costo', directCostTotal, Colors.white70)),
            _totalLabel('Utilidad', profit, const Color(0xFF60A5FA)),
          ]),
          const SizedBox(height: 8),
          _finalTotalBox(),
        ]),
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(children: [
        _marginField(marginPercent, compact: false),
        _vSeparator(),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('COSTO DIRECTO',
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(currencyFormat.format(directCostTotal),
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
        _vSeparator(),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('UTILIDAD ',
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 0.8)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
              child: Text('+$marginPercent%',
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF60A5FA))),
            ),
          ]),
          const SizedBox(height: 2),
          Text(currencyFormat.format(profit),
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF60A5FA))),
        ]),
        const Spacer(),
        _finalTotalBox(),
      ]),
    );
  }

  Widget _marginField(int marginPercent, {required bool compact}) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.shieldCheck,
            size: 15, color: Colors.amber.shade300),
        const SizedBox(width: 8),
        Text('Margen',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade200)),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 28,
          child: TextField(
            controller: TextEditingController(text: marginPercent.toString())
              ..selection = TextSelection.collapsed(
                  offset: marginPercent.toString().length),
            keyboardType: TextInputType.number,
            inputFormatters: _intOnlyFormatters, // ← SOLO ENTEROS
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.amber.shade200),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              _markAsChanged();
              setState(() =>
                  data.protectionRate =
                      (double.tryParse(val) ?? 0) / 100);
            },
          ),
        ),
        Text(' %',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.amber.shade300)),
      ]),
    );
  }

  Widget _vSeparator() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.1));

  Widget _totalLabel(String label, double value, Color color) => Row(
        children: [
          Text('$label: ',
              style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white38)),
          Text(currencyFormat.format(value),
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );

  Widget _finalTotalBox() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4ADE80).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF4ADE80).withOpacity(0.25)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL COTIZACIÓN',
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4ADE80).withOpacity(0.7),
                    letterSpacing: 1)),
            Text('Sin IVA',
                style: GoogleFonts.inter(
                    fontSize: 9, color: Colors.white24)),
          ]),
          const SizedBox(width: 16),
          Text(
            currencyFormat.format(finalPrice),
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4ADE80),
                letterSpacing: -0.5),
          ),
        ]),
      );

  // ────────────────────────────────────────────────────────────────
  //  FOOTER
  // ────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool mobile) {
    return Container(
      padding: EdgeInsets.all(mobile ? 12 : 20),
      decoration: BoxDecoration(
          color: _surfaceColor,
          border: Border(top: BorderSide(color: _borderColor))),
      child: Row(children: [
        TextButton(
          onPressed: _handleClose, // ← USA CONFIRMACIÓN
          style: TextButton.styleFrom(foregroundColor: _labelColor),
          child: Text(mobile ? 'Cancelar' : 'Descartar cambios',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: mobile ? 20 : 28,
                vertical: mobile ? 14 : 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          icon: const Icon(LucideIcons.save, size: 17),
          label: Text(
              mobile ? 'Guardar' : 'Guardar Cotización',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HELPERS VISUALES
  // ────────────────────────────────────────────────────────────────
  TextStyle _colHeader() => GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _labelColor,
      letterSpacing: 0.6);

  Widget _deleteButton(VoidCallback onPressed) => IconButton(
        icon: const Icon(LucideIcons.trash2,
            size: 15, color: Colors.redAccent),
        onPressed: onPressed,
        tooltip: 'Eliminar',
        padding: const EdgeInsets.all(8),
        constraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
      );

  Widget _buildProviderBadge(
    String providerName,
    double price,
    VoidCallback onTap, {
    bool isService = false,
  }) {
    if (providerName.contains('No encontrado')) return const SizedBox.shrink();
    final color = isService ? const Color(0xFF7C3AED) : _accentColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(top: 5),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.store, size: 11, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(providerName,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 9, color: color.withOpacity(0.3)),
          const SizedBox(width: 6),
          Text('Cambiar',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                  decoration: TextDecoration.underline)),
        ]),
      ),
    );
  }

  /// ─── NUEVO: helper extendido con tipo numérico e indicador de dropdown ───
  Widget _buildInput(
    TextEditingController? ctrl,
    String hint, {
    String? initialValue,
    Function(String)? onChanged,
    FocusNode? focusNode,
    bool isCenter = false,
    bool isDropdown = false,
    NumericType? numericType,
  }) {
    List<TextInputFormatter>? formatters;
    TextInputType? kbType;
    if (numericType == NumericType.integer) {
      formatters = _intOnlyFormatters;
      kbType = TextInputType.number;
    } else if (numericType == NumericType.decimal) {
      formatters = _decimalFormatters;
      kbType = const TextInputType.numberWithOptions(decimal: true);
    }

    return TextFormField(
      controller: ctrl,
      initialValue: initialValue,
      onChanged: onChanged,
      focusNode: focusNode,
      keyboardType: kbType,
      inputFormatters: formatters,
      textAlign: isCenter ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.inter(fontSize: 13),
      decoration:
          _inputDecoration(hint, isCenter: isCenter, isDropdown: isDropdown),
    );
  }

  /// ─── MODIFICADO: isDropdown aplica marco más oscuro ───
  InputDecoration _inputDecoration(String hint,
      {bool isCenter = false, bool isDropdown = false}) {
    final Color effectiveBorderColor =
        isDropdown ? _dropdownBorderColor : _borderColor;
    final Color effectiveFillColor =
        isDropdown ? _dropdownFillColor : _surfaceColor;
    final double borderWidth = isDropdown ? 1.4 : 1.0;

    return InputDecoration(
      labelText: hint,
      isDense: true,
      labelStyle:
          GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      fillColor: effectiveFillColor,
      filled: true,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: effectiveBorderColor, width: borderWidth)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _accentColor, width: 1.8)),
    );
  }

  Widget _buildDropdownOptions(
      BuildContext context, Function onSelected, Iterable options) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        color: _surfaceColor,
        child: Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: options.length,
            itemBuilder: (ctx, index) {
              final option = options.elementAt(index);
              final name  = (option as dynamic).name;
              final sub   = (option is MaterialItem)
                  ? option.unit
                  : (option is ServiceItem)
                      ? option.unit
                      : '';
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textColor)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _labelColor)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── NUEVO: enum para tipo numérico ───
enum NumericType { integer, decimal }