import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../models/material_model.dart';
import '../../../models/quotation_model.dart';
import '../../../models/process_model.dart';
import '../../../services/material_service.dart';
import '../../../services/provider_service.dart';
import '../../../models/provider_model.dart';

// ============================================================
//  DATA MODEL: LogisticsItem
// ============================================================
class LogisticsItem {
  String materialId;
  String materialName;
  String unit;
  double requiredQty;
  double stockQty;
  double purchasedQty;
  String? selectedProviderId;
  String? selectedProviderName;
  double actualUnitPrice;
  double quotedUnitPrice;
  DateTime? purchaseDate;

  LogisticsItem({
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.requiredQty,
    this.stockQty = 0,
    this.purchasedQty = 0,
    this.selectedProviderId,
    this.selectedProviderName,
    this.actualUnitPrice = 0,
    this.quotedUnitPrice = 0,
    this.purchaseDate,
  });

  // Cuánto hay que comprar (sin contar lo ya comprado)
  double get toBuyQty => (requiredQty - stockQty).clamp(0.0, double.infinity);

  // Lo que aún falta después de stock + comprado
  double get pendingQty =>
      (requiredQty - stockQty - purchasedQty).clamp(0.0, double.infinity);

  // True si el stock solo alcanza
  bool get coveredByStock => stockQty >= requiredQty;

  // True si stock + comprado alcanza
  bool get fullyCovered => stockQty + purchasedQty >= requiredQty;

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'materialName': materialName,
        'unit': unit,
        'requiredQty': requiredQty,
        'stockQty': stockQty,
        'purchasedQty': purchasedQty,
        'selectedProviderId': selectedProviderId,
        'selectedProviderName': selectedProviderName,
        'actualUnitPrice': actualUnitPrice,
        'quotedUnitPrice': quotedUnitPrice,
        'purchaseDate': purchaseDate?.toIso8601String(),
      };

  factory LogisticsItem.fromMap(Map<String, dynamic> map) => LogisticsItem(
        materialId: map['materialId'] ?? '',
        materialName: map['materialName'] ?? '',
        unit: map['unit'] ?? '',
        requiredQty: (map['requiredQty'] ?? 0).toDouble(),
        stockQty: (map['stockQty'] ?? 0).toDouble(),
        purchasedQty: (map['purchasedQty'] ?? 0).toDouble(),
        selectedProviderId: map['selectedProviderId'],
        selectedProviderName: map['selectedProviderName'],
        actualUnitPrice: (map['actualUnitPrice'] ?? 0).toDouble(),
        quotedUnitPrice: (map['quotedUnitPrice'] ?? 0).toDouble(),
        purchaseDate: map['purchaseDate'] != null
            ? DateTime.tryParse(map['purchaseDate'])
            : null,
      );
}

// ============================================================
//  MAIN WIDGET: LogisticsSection
// ============================================================
class LogisticsSection extends StatefulWidget {
  final ProcessModel process;
  final bool isEditable;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onDataChanged;

  const LogisticsSection({
    super.key,
    required this.process,
    required this.isEditable,
    this.initialData,
    required this.onDataChanged,
  });

  @override
  State<LogisticsSection> createState() => _LogisticsSectionState();
}

class _LogisticsSectionState extends State<LogisticsSection> {
  final MaterialService _materialService = MaterialService();
  final ProviderService _providerService = ProviderService();

  final _notesController = TextEditingController();
  List<LogisticsItem> _items = [];
  List<MaterialItem> _materialsDB = [];
  // ignore: unused_field
  List<Provider> _providersDB = [];
  bool _isLoading = true;

  final _currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // ── Estatus calculado automáticamente ────────────────────
  String get _logisticsStatus {
    if (_items.isEmpty) return 'Por Comprar';
    final allByStock = _items.every((i) => i.coveredByStock);
    if (allByStock) return 'Completo';
    final allCovered = _items.every((i) => i.fullyCovered);
    if (allCovered) return 'Por Comprar';
    return 'Incompleto';
  }

  Color get _statusColor {
    switch (_logisticsStatus) {
      case 'Completo':
        return const Color(0xFF10B981);
      case 'Por Comprar':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  // ── Costo real calculado ─────────────────────────────────
  double get _realCostSubtotal {
    return _items.fold(0.0, (sum, item) {
      final covered =
          (item.stockQty + item.purchasedQty).clamp(0.0, item.requiredQty);
      return sum + covered * item.actualUnitPrice;
    });
  }

  double get _realCostTotal => _realCostSubtotal * 1.16;

  // ── Inicialización ───────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final mats = await _materialService.getMaterials().first;
      final provs = await _providerService.getProviders().first;
      if (!mounted) return;
      setState(() {
        _materialsDB = mats;
        _providersDB = provs;
      });

      if (widget.initialData != null && widget.initialData!.isNotEmpty) {
        // Cargar datos guardados previamente
        _notesController.text = widget.initialData!['notes'] ?? '';
        final rawItems = (widget.initialData!['items'] as List? ?? []);
        final loadedItems =
            rawItems.map((e) => LogisticsItem.fromMap(Map<String, dynamic>.from(e))).toList();

        // Actualizar stock con valores actuales de la BD
        for (final item in loadedItems) {
          try {
            final dbMat = _materialsDB.firstWhere(
              (m) =>
                  m.id == item.materialId ||
                  m.name.toLowerCase() == item.materialName.toLowerCase(),
            );
            item.stockQty = dbMat.stock;
          } catch (_) {}
        }

        if (mounted) setState(() { _items = loadedItems; _isLoading = false; });
      } else {
        // Inicializar desde la cotización
        _initFromQuotation();
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initFromQuotation() {
    if (widget.process.quotationData == null) return;
    final quotation = QuotationModel.fromMap(widget.process.quotationData!);
    final List<LogisticsItem> items = [];

    for (final qItem in quotation.materials) {
      if (qItem.name.isEmpty) continue;

      MaterialItem? dbMat;
      try {
        dbMat = _materialsDB.firstWhere(
          (m) => m.name.toLowerCase() == qItem.name.toLowerCase(),
        );
      } catch (_) {}

      final logItem = LogisticsItem(
        materialId: dbMat?.id ?? qItem.id,
        materialName: qItem.name,
        unit: dbMat?.unit ?? '',
        requiredQty: qItem.quantity,
        stockQty: dbMat?.stock ?? 0,
        quotedUnitPrice: qItem.unitPrice,
        actualUnitPrice: qItem.unitPrice,
      );

      // Auto-selección si solo hay un proveedor
      if (dbMat != null && dbMat.prices.length == 1) {
        logItem.selectedProviderId = dbMat.prices.first.providerId;
        logItem.selectedProviderName = dbMat.prices.first.providerName;
        logItem.actualUnitPrice = dbMat.prices.first.price;
      }

      items.add(logItem);
    }
    _items = items;
  }

  void _notifyChanged() {
    widget.onDataChanged({
      'notes': _notesController.text,
      'status': _logisticsStatus,
      'realCostSubtotal': _realCostSubtotal,
      'realCostTotal': _realCostTotal,
      'items': _items.map((e) => e.toMap()).toList(),
    });
  }

  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFB45309)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────
          _buildSectionHeader(),

          const SizedBox(height: 24),

          // ── 1. Indicaciones Especiales ───────────────────
          _buildSectionTitle("Indicaciones Especiales", LucideIcons.clipboardList),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            enabled: widget.isEditable,
            maxLines: 3,
            onChanged: (_) => _notifyChanged(),
            style: GoogleFonts.inter(
                fontSize: 14, color: const Color(0xFF1E293B), height: 1.5),
            decoration: InputDecoration(
              hintText:
                  "Ej: Entregar material en puerta trasera, contactar a Juan antes de enviar...",
              hintStyle:
                  GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(16),
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
                borderSide:
                    const BorderSide(color: Color(0xFFB45309), width: 2),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── 2. Estatus + Costo Real ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel("Estatus de Materiales"),
                    const SizedBox(height: 10),
                    _buildStatusBadge(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel("Costo Real al Momento"),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _buildMoneyDisplay(
                                "SUBTOTAL (SIN IVA)", _realCostSubtotal)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildMoneyDisplay(
                                "TOTAL (CON IVA)", _realCostTotal,
                                highlight: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── 3. Balance de Materiales ─────────────────────
          _buildSectionTitle("Balance de Materiales", LucideIcons.table),
          const SizedBox(height: 16),
          _buildBalanceTable(),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── 4. Gestión de Compras ────────────────────────
          _buildSectionTitle(
              "Gestión de Compras a Proveedores", LucideIcons.shoppingCart),
          const SizedBox(height: 16),
          _buildPurchasesSection(),
        ],
      ),
    );
  }

  // ── SECCIÓN: Balance de Materiales ──────────────────────
  Widget _buildBalanceTable() {
    if (_items.isEmpty) {
      return _buildEmptyState(
        "No se encontraron materiales en la cotización.",
        "Completa el cotizador primero para ver el balance aquí.",
        LucideIcons.package,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header de tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: _buildTableLabel("Material")),
                Expanded(flex: 2, child: _buildTableLabel("Requerido", align: TextAlign.center)),
                Expanded(
                  flex: 2,
                  child: _buildTableLabel("Stock", align: TextAlign.center, color: const Color(0xFF2563EB)),
                ),
                Expanded(
                  flex: 2,
                  child: _buildTableLabel("Comprado", align: TextAlign.center, color: const Color(0xFF10B981)),
                ),
                Expanded(
                  flex: 2,
                  child: _buildTableLabel("Pendiente", align: TextAlign.center, color: const Color(0xFFEF4444)),
                ),
              ],
            ),
          ),
          // Filas
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            final isLast = i == _items.length - 1;
            final pending = item.pendingQty;
            final pendingColor = pending > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.materialName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        if (item.unit.isNotEmpty)
                          Text(
                            item.unit,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: _buildQtyCell("${item.requiredQty.toStringAsFixed(item.requiredQty.truncateToDouble() == item.requiredQty ? 0 : 2)}", null)),
                  Expanded(flex: 2, child: _buildQtyCell("${item.stockQty.toStringAsFixed(item.stockQty.truncateToDouble() == item.stockQty ? 0 : 2)}", const Color(0xFF2563EB))),
                  Expanded(flex: 2, child: _buildQtyCell("${item.purchasedQty.toStringAsFixed(item.purchasedQty.truncateToDouble() == item.purchasedQty ? 0 : 2)}", const Color(0xFF10B981))),
                  Expanded(flex: 2, child: _buildQtyCell(pending.toStringAsFixed(pending.truncateToDouble() == pending ? 0 : 2), pendingColor)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── SECCIÓN: Gestión de Compras ──────────────────────────
  Widget _buildPurchasesSection() {
    final itemsToBuy = _items.where((i) => i.toBuyQty > 0).toList();

    if (itemsToBuy.isEmpty) {
      if (_items.isEmpty) {
        return _buildEmptyState(
          "Sin materiales en cotización",
          "Al completar la cotización aparecerán los materiales aquí.",
          LucideIcons.shoppingCart,
        );
      }
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Color(0xFF059669), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "¡Todo el stock necesario está disponible! No hay compras pendientes.",
                style: GoogleFonts.inter(
                  color: const Color(0xFF065F46),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: itemsToBuy.map((item) {
        // Encontrar el material en la BD para obtener precios/proveedores
        MaterialItem? dbMat;
        try {
          dbMat = _materialsDB.firstWhere(
            (m) =>
                m.id == item.materialId ||
                m.name.toLowerCase() == item.materialName.toLowerCase(),
          );
        } catch (_) {}

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PurchaseCard(
            item: item,
            dbMaterial: dbMat,
            isEditable: widget.isEditable,
            currFmt: _currFmt,
            onChanged: () {
              setState(() {});
              _notifyChanged();
            },
          ),
        );
      }).toList(),
    );
  }

  // ── HELPERS DE UI ────────────────────────────────────────
  Widget _buildSectionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFB45309).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.truck, color: Color(0xFFB45309), size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            "Control de Logística y Ejecución",
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFB45309).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFB45309)),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFB45309),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
      );

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            _logisticsStatus,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _statusColor,
            ),
          ),
          const Spacer(),
          // Icono indicativo
          Icon(
            _logisticsStatus == 'Completo'
                ? LucideIcons.checkCircle2
                : _logisticsStatus == 'Por Comprar'
                    ? LucideIcons.shoppingCart
                    : LucideIcons.alertCircle,
            size: 16,
            color: _statusColor.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyDisplay(String label, double amount, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "\$ ",
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
              Text(
                amount.toStringAsFixed(2),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: highlight ? const Color(0xFF0369A1) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableLabel(String text,
      {TextAlign align = TextAlign.left, Color? color}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color ?? const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildQtyCell(String text, Color? color) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? const Color(0xFF334155),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  PURCHASE CARD (StatefulWidget independiente con controllers)
// ============================================================
class _PurchaseCard extends StatefulWidget {
  final LogisticsItem item;
  final MaterialItem? dbMaterial;
  final bool isEditable;
  final NumberFormat currFmt;
  final VoidCallback onChanged;

  const _PurchaseCard({
    // ignore: unused_element_parameter
    super.key,
    required this.item,
    required this.dbMaterial,
    required this.isEditable,
    required this.currFmt,
    required this.onChanged,
  });

  @override
  State<_PurchaseCard> createState() => _PurchaseCardState();
}

class _PurchaseCardState extends State<_PurchaseCard> {
  late TextEditingController _purchasedCtrl;
  late TextEditingController _priceCtrl;

  List<PriceEntry> get _prices => widget.dbMaterial?.prices ?? [];

  @override
  void initState() {
    super.initState();
    _purchasedCtrl = TextEditingController(
      text: widget.item.purchasedQty > 0 ? widget.item.purchasedQty.toString() : '',
    );
    _priceCtrl = TextEditingController(
      text: widget.item.actualUnitPrice > 0
          ? widget.item.actualUnitPrice.toStringAsFixed(2)
          : '',
    );

    // Auto-seleccionar si solo hay un proveedor y aún no se ha elegido
    if (_prices.length == 1 && widget.item.selectedProviderId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectProvider(_prices.first);
      });
    }
  }

  @override
  void dispose() {
    _purchasedCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _selectProvider(PriceEntry price) {
    setState(() {
      widget.item.selectedProviderId = price.providerId;
      widget.item.selectedProviderName = price.providerName;
      widget.item.actualUnitPrice = price.price;
      _priceCtrl.text = price.price.toStringAsFixed(2);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final pending = item.pendingQty;
    final isCovered = item.fullyCovered;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCovered ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header del material ──────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.package, size: 16, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.materialName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (item.unit.isNotEmpty)
                        Text(
                          item.unit,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCovered ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCovered ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Text(
                    isCovered
                        ? "✓ Cubierto"
                        : "Pendiente: ${pending.toStringAsFixed(pending.truncateToDouble() == pending ? 0 : 2)} ${item.unit}",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isCovered ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Chips de cantidad ───────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip("Requerido",
                    "${item.requiredQty.toStringAsFixed(0)} ${item.unit}",
                    const Color(0xFF64748B)),
                _buildChip("En Stock",
                    "${item.stockQty.toStringAsFixed(0)} ${item.unit}",
                    const Color(0xFF2563EB)),
                _buildChip("A Comprar",
                    "${item.toBuyQty.toStringAsFixed(0)} ${item.unit}",
                    const Color(0xFFEA580C)),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Formulario de compra ────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                // Layout en columna para pantallas pequeñas
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("PROVEEDOR"),
                    const SizedBox(height: 8),
                    _buildProviderSelector(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("COMPRADO"),
                              const SizedBox(height: 8),
                              _buildPurchasedQtyField(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("COSTO UNIT."),
                              const SizedBox(height: 8),
                              _buildPriceField(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("FECHA"),
                              const SizedBox(height: 8),
                              _buildDatePicker(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              // Layout en fila para pantallas grandes
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("PROVEEDOR"),
                        const SizedBox(height: 8),
                        _buildProviderSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("COMPRADO"),
                        const SizedBox(height: 8),
                        _buildPurchasedQtyField(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("COSTO UNIT."),
                        const SizedBox(height: 8),
                        _buildPriceField(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("FECHA"),
                        const SizedBox(height: 8),
                        _buildDatePicker(),
                      ],
                    ),
                  ),
                ],
              );
            }),

            // ── Comparativa de precio / Ahorro ──────────────
            if (item.selectedProviderId != null) ...[
              const SizedBox(height: 12),
              _buildPriceComparison(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    if (_prices.isEmpty) {
      // Sin proveedores en catálogo: input libre
      return TextField(
        enabled: widget.isEditable,
        onChanged: (val) {
          widget.item.selectedProviderName = val;
          widget.onChanged();
        },
        style: GoogleFonts.inter(fontSize: 13),
        decoration: _inputDeco("Nombre del proveedor..."),
      );
    }

    // Con proveedores: dropdown
    return DropdownButtonFormField<String>(
      value: _prices.any((p) => p.providerId == widget.item.selectedProviderId)
          ? widget.item.selectedProviderId
          : null,
      isExpanded: true,
      hint: Text("Seleccionar proveedor...",
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      items: _prices.map((price) {
        return DropdownMenuItem<String>(
          value: price.providerId,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  price.providerName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "\$${price.price.toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: widget.isEditable
          ? (selectedId) {
              if (selectedId == null) return;
              final price = _prices.firstWhere((p) => p.providerId == selectedId);
              _selectProvider(price);
            }
          : null,
      decoration: _inputDeco(""),
    );
  }

  Widget _buildPurchasedQtyField() {
    return TextField(
      controller: _purchasedCtrl,
      enabled: widget.isEditable,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        widget.item.purchasedQty = double.tryParse(val) ?? 0;
        widget.onChanged();
      },
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
      decoration: _inputDeco("0"),
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _priceCtrl,
      enabled: widget.isEditable,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        widget.item.actualUnitPrice = double.tryParse(val) ?? 0;
        widget.onChanged();
      },
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
      decoration: _inputDeco("\$ 0.00").copyWith(prefixText: "\$ "),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: widget.isEditable
          ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.item.purchaseDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(primary: Color(0xFFB45309)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => widget.item.purchaseDate = picked);
                widget.onChanged();
              }
            }
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.item.purchaseDate != null
                    ? DateFormat('dd/MM/yy').format(widget.item.purchaseDate!)
                    : DateFormat('dd/MM/yyyy').format(DateTime.now()),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceComparison() {
    final item = widget.item;
    final savings = item.quotedUnitPrice - item.actualUnitPrice;
    final hasSavings = savings > 0.01;
    final isMore = savings < -0.01;

    Color bgColor;
    Color iconColor;
    IconData icon;
    String text;

    if (hasSavings) {
      bgColor = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF059669);
      icon = LucideIcons.trendingDown;
      text =
          "Ahorro vs. cotización: ${widget.currFmt.format(savings)}/u  •  Precio cotizado: ${widget.currFmt.format(item.quotedUnitPrice)}";
    } else if (isMore) {
      bgColor = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFDC2626);
      icon = LucideIcons.trendingUp;
      text =
          "Costo mayor al cotizado en ${widget.currFmt.format(-savings)}/u  •  Precio cotizado: ${widget.currFmt.format(item.quotedUnitPrice)}";
    } else {
      bgColor = const Color(0xFFF8FAFC);
      iconColor = const Color(0xFF64748B);
      icon = LucideIcons.info;
      text = "Precio igual al cotizado: ${widget.currFmt.format(item.quotedUnitPrice)}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB45309), width: 1.5),
        ),
      );
}