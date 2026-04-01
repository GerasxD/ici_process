import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:ici_process/ui/pdf/purchase_order_pdf_generator.dart';
import 'package:ici_process/ui/widgets/process_modal/execution_planning_widget.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../models/material_model.dart';
import '../../../models/purchase_order_model.dart';
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
  double actualUnitPrice;   // precio al que se COMPRÓ al proveedor
  double quotedUnitPrice;   // precio de la cotización
  double stockUnitPrice;    // ← NUEVO: precio al que está valorado el stock
  DateTime? purchaseDate;
  List<PurchaseOrder>? purchaseOrders;
  bool isStockReserved;       // ¿ya se apartó el stock?
  double reservedStockQty;    // cantidad que se apartó
 
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
    this.stockUnitPrice = 0,  
    this.purchaseDate,
    this.purchaseOrders,
     this.isStockReserved = false,   
    this.reservedStockQty = 0, 
  });
 
  double get toBuyQty => (requiredQty - stockQty).clamp(0.0, double.infinity);
  double get pendingQty =>
      (requiredQty - stockQty - purchasedQty).clamp(0.0, double.infinity);
  bool get coveredByStock => stockQty >= requiredQty;
  bool get fullyCovered => stockQty + purchasedQty >= requiredQty;
 
  // ── Costos separados ─────────────────────────────────────
  double get stockCost {
    final used = stockQty.clamp(0.0, requiredQty);
    return used * stockUnitPrice;
  }
 
  double get purchasedCost {
    final stockUsed = stockQty.clamp(0.0, requiredQty);
    final purchasedUsed =
        purchasedQty.clamp(0.0, (requiredQty - stockUsed).clamp(0.0, double.infinity));
    return purchasedUsed * actualUnitPrice;
  }
 
  double get totalCost => stockCost + purchasedCost;
 
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
        'stockUnitPrice': stockUnitPrice,   // ← NUEVO
        'purchaseDate': purchaseDate?.toIso8601String(),
        'purchaseOrders': purchaseOrders?.map((o) => o.toMap()).toList() ?? [],
        'isStockReserved': isStockReserved,     
        'reservedStockQty': reservedStockQty,
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
        stockUnitPrice: (map['stockUnitPrice'] ?? 0).toDouble(),   // ← NUEVO
        purchaseDate: map['purchaseDate'] != null
            ? DateTime.tryParse(map['purchaseDate'])
            : null,
        purchaseOrders: (map['purchaseOrders'] as List? ?? [])
            .map((e) => PurchaseOrder.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        isStockReserved: map['isStockReserved'] ?? false,         
        reservedStockQty: (map['reservedStockQty'] ?? 0).toDouble(), 
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
  final bool canViewFinancials;
  final String currentUserName;
  final UserRole currentUserRole;

  const LogisticsSection({
    super.key,
    required this.process,
    required this.isEditable,
    this.initialData,
    required this.onDataChanged,
    required this.canViewFinancials,
    required this.currentUserName,
    required this.currentUserRole,
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
  double get _realCostSubtotal =>
    _items.fold(0.0, (sum, item) => sum + item.totalCost);
 
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
        _notesController.text = widget.initialData!['notes'] ?? '';
        final rawItems = (widget.initialData!['items'] as List? ?? []);
        final loadedItems = rawItems
            .map((e) => LogisticsItem.fromMap(Map<String, dynamic>.from(e)))
            .toList();
  
        // ── Actualizar stock Y stockUnitPrice desde la BD ──────────────
        for (final item in loadedItems) {
          try {
            final dbMat = _materialsDB.firstWhere(
              (m) =>
                  m.id == item.materialId ||
                  m.name.toLowerCase() == item.materialName.toLowerCase(),
            );
 
            // ★ FIX: Solo refrescar stock desde la BD cuando estamos en E5 (editable).
            // En E6+ el stock ya fue descontado de la BD, así que si recargamos
            // veríamos 0. Mantenemos el valor guardado que refleja lo que SE USÓ.
            if (widget.isEditable) {
              if (!item.isStockReserved) {
                // No reservado → mostrar stock disponible actual de la BD
                item.stockQty = dbMat.availableStock;
              } else {
                // Ya reservado → mostrar la cantidad que apartamos
                item.stockQty = item.reservedStockQty;
              }
            }
            // Si !widget.isEditable (E6+), NO tocamos item.stockQty
            // Se queda con el valor que se guardó en Firestore.
 
            if (item.stockUnitPrice == 0) {
              item.stockUnitPrice = _resolveStockPrice(dbMat, item.quotedUnitPrice);
            }
          } catch (_) {}
        }
  
        if (mounted) setState(() { _items = loadedItems; _isLoading = false; });
      } else {
        _initFromQuotation();
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Función para calcular los días cotizados basándose en la mano de obra
  double _calculateQuotedDays() {
    if (widget.process.quotationData == null) return 0.0;
    try {
      final q = QuotationModel.fromMap(widget.process.quotationData!);
      double maxDays = 0;
      for (var labor in q.labor) {
        if (labor.days > maxDays) maxDays = labor.days;
      }
      return maxDays;
    } catch (e) {
      return 0.0;
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
        stockQty: dbMat?.availableStock ?? 0,  // ★ Usar stock disponible (sin reservas)
        quotedUnitPrice: qItem.unitPrice,
        actualUnitPrice: qItem.unitPrice,
        // ★ FIX: usar el helper centralizado
        stockUnitPrice: _resolveStockPrice(dbMat, qItem.unitPrice),
      );
  
      if (dbMat != null && dbMat.prices.length == 1) {
        logItem.selectedProviderId = dbMat.prices.first.providerId;
        logItem.selectedProviderName = dbMat.prices.first.providerName;
        logItem.actualUnitPrice = dbMat.prices.first.price;
      }
  
      items.add(logItem);
    }
    _items = items;
  }

  double _resolveStockPrice(MaterialItem? dbMat, double quotedPrice) {
    return quotedPrice > 0 ? quotedPrice : 0;
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

  Future<void> _reserveAllStock() async {
    final itemsToReserve = _items.where(
      (i) => !i.isStockReserved && i.stockQty > 0 && i.requiredQty > 0
    ).toList();
 
    if (itemsToReserve.isEmpty) {
      _showSnack("No hay materiales pendientes de apartar", isError: true);
      return;
    }
 
    // Confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.packageCheck, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 12),
            Text("Apartar Stock", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Se reservará el stock disponible para ${itemsToReserve.length} material(es). "
              "El stock quedará apartado para este proyecto pero NO se descontará hasta que avance a Ejecución.",
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 16),
            // Lista resumida de lo que se va a apartar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: itemsToReserve.map((item) {
                  final toReserve = item.stockQty.clamp(0.0, item.requiredQty);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.package, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.materialName, 
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text("${_fmtQty(toReserve)} ${item.unit}", 
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(LucideIcons.packageCheck, size: 16),
            label: Text("Apartar Stock", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
 
    if (confirm != true) return;
 
    // Ejecutar las reservas
    int successCount = 0;
    for (final item in itemsToReserve) {
      final toReserve = item.stockQty.clamp(0.0, item.requiredQty);
      if (toReserve > 0) {
        final success = await _materialService.reserveStock(item.materialId, toReserve);
        if (success) {
          setState(() {
            item.isStockReserved = true;
            item.reservedStockQty = toReserve;
          });
          successCount++;
        }
      }
    }
 
    _notifyChanged();
 
    if (successCount > 0) {
      _showSnack("✓ Stock apartado para $successCount material(es)");
    } else {
      _showSnack("No se pudo apartar el stock", isError: true);
    }
  }
 
  /// Helper para mostrar snackbar desde LogisticsSection
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
 
  static String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(2);
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

    final allowedRoles = [UserRole.superAdmin, UserRole.admin, UserRole.accountant, UserRole.purchasing];

    final bool canViewPurchases = allowedRoles.contains(widget.currentUserRole);

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
 
          // ★ NUEVO: Botón de Apartar Stock
          if (widget.isEditable && _items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildReserveStockButton(),
          ],

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── 4. Gestión de Compras ────────────────────────
          if (canViewPurchases) ...[
            _buildSectionTitle(
                "Gestión de Compras a Proveedores", LucideIcons.shoppingCart),
            const SizedBox(height: 16),
            _buildPurchasesSection(),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          ],

          // ── 5. Planificación de Ejecución ────────────────
          _buildSectionTitle(
              "Planificación de Ejecución", LucideIcons.calendarClock),
          const SizedBox(height: 16),
          ExecutionPlanningWidget(
            process: widget.process,
            quotedDays: _calculateQuotedDays(), // Usa la función que acabamos de agregar
            isEditable: widget.isEditable,
            initialData: widget.initialData?['executionPlanning'],
            onChanged: (planningData) {
              // Actualizamos y mandamos TODA la data (Logística + Planificación)
              final currentData = {
                'notes': _notesController.text,
                'status': _logisticsStatus,
                'realCostSubtotal': _realCostSubtotal,
                'realCostTotal': _realCostTotal,
                'items': _items.map((e) => e.toMap()).toList(),
                'executionPlanning': planningData, // <-- Guardamos los datos de planificación aquí
              };
              widget.onDataChanged(currentData);
            },
          ),
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
                  Expanded(
                    flex: 2, 
                    child: Column(
                      children: [
                        _buildQtyCell(
                          "${item.stockQty.toStringAsFixed(item.stockQty.truncateToDouble() == item.stockQty ? 0 : 2)}", 
                          const Color(0xFF2563EB),
                        ),
                        // ★ Indicador visual de reserva
                        if (item.isStockReserved)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Apartado",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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

  Widget _buildReserveStockButton() {
    final hasUnreserved = _items.any(
      (i) => !i.isStockReserved && i.stockQty > 0 && i.requiredQty > 0
    );
    final allReserved = _items.isNotEmpty && 
      _items.where((i) => i.stockQty > 0 && i.requiredQty > 0).every((i) => i.isStockReserved);
 
    if (allReserved && _items.any((i) => i.isStockReserved)) {
      // Ya todo está apartado — mostrar badge de éxito
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.shieldCheck, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Stock Apartado",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  Text(
                    "El material en stock ya está reservado para este proyecto. "
                    "Se descontará al avanzar a Ejecución.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
 
    if (!hasUnreserved) return const SizedBox.shrink();
 
    // Botón para apartar
    return InkWell(
      onTap: _reserveAllStock,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.packageCheck, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              "Apartar Stock del Almacén",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
          child: PurchaseCard(
            item: item,
            dbMaterial: dbMat,
            isEditable: widget.isEditable,
            currFmt: _currFmt,
            onChanged: () {
              setState(() {});
              _notifyChanged();
            }, 
            process: widget.process, 
            currentUserName: widget.currentUserName
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
    // 👇 EVALUAMOS SI TIENE PERMISO
    final bool canView = widget.canViewFinancials;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              // Opcional: Mostrar un candadito si no tiene permiso
              if (!canView)
                const Icon(LucideIcons.lock, size: 12, color: Color(0xFF94A3B8)),
            ],
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
                // 👇 SI canView ES FALSE, MOSTRAMOS *** EN VEZ DEL NÚMERO
                canView ? amount.toStringAsFixed(2) : "***.**",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: highlight ? const Color(0xFF0369A1) : const Color(0xFF334155),
                  // Opcional: Cambiamos un poco el estilo de los asteriscos
                  letterSpacing: canView ? 0 : 2.0, 
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

// ─────────────────────────────────────────────────────────────
//  HELPER: genera un folio legible  OC-2026-0001
// ─────────────────────────────────────────────────────────────
String _generateFolio() {
  final now = DateTime.now();
  final ms = now.millisecondsSinceEpoch.toString();
  return 'OC-${now.year}-${ms.substring(ms.length - 4)}';
}
 
// ─────────────────────────────────────────────────────────────
//  WIDGET PRINCIPAL: _PurchaseCard
// ─────────────────────────────────────────────────────────────
class PurchaseCard extends StatefulWidget {
  final LogisticsItem item;
  final MaterialItem? dbMaterial;
  final bool isEditable;
  final NumberFormat currFmt;
  final VoidCallback onChanged;
  // Datos del proceso para el PDF
  final ProcessModel process;
  final String currentUserName;
 
  const PurchaseCard({
    super.key,
    required this.item,
    required this.dbMaterial,
    required this.isEditable,
    required this.currFmt,
    required this.onChanged,
    required this.process,
    required this.currentUserName,
  });
 
  @override
  State<PurchaseCard> createState() => _PurchaseCardState();
}
 
class _PurchaseCardState extends State<PurchaseCard> {
  late TextEditingController _purchasedCtrl;
  late TextEditingController _priceCtrl;
 
  // Estado de la orden actual (antes de registrar)
  bool _isRegistering = false; // muestra el formulario de registro
  final TextEditingController _justificationCtrl = TextEditingController();
  bool _isSavingOrder = false;
  bool _isGeneratingPdf = false;
 
  List<PriceEntry> get _prices => widget.dbMaterial?.prices ?? [];
 
  // ── Historial de órdenes del item ───────────────────────
  List<PurchaseOrder> get _orders =>
      widget.item.purchaseOrders ?? [];
 
  // ── Excedente de la cantidad actual ─────────────────────
  bool get _hasExcess =>
      (double.tryParse(_purchasedCtrl.text) ?? 0) >
      widget.item.toBuyQty;
 
  double get _excessQty =>
      ((double.tryParse(_purchasedCtrl.text) ?? 0) -
          widget.item.toBuyQty)
          .clamp(0.0, double.infinity);
 
  @override
  void initState() {
    super.initState();
    _purchasedCtrl = TextEditingController(
      text: widget.item.purchasedQty > 0
          ? widget.item.purchasedQty.toString()
          : '',
    );
    _priceCtrl = TextEditingController(
      text: widget.item.actualUnitPrice > 0
          ? widget.item.actualUnitPrice.toStringAsFixed(2)
          : '',
    );
 
    if (_prices.length == 1 &&
        widget.item.selectedProviderId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectProvider(_prices.first);
      });
    }
  }
 
  @override
  void dispose() {
    _purchasedCtrl.dispose();
    _priceCtrl.dispose();
    _justificationCtrl.dispose();
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
 
  // ── Registrar nueva orden ────────────────────────────────
  Future<void> _registerOrder() async {
    final qty = double.tryParse(_purchasedCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
 
    if (qty <= 0) {
      _showSnack("Ingresa una cantidad válida", isError: true);
      return;
    }
    if (widget.item.selectedProviderName == null ||
        widget.item.selectedProviderName!.isEmpty) {
      _showSnack("Selecciona un proveedor", isError: true);
      return;
    }
    if (_hasExcess && _justificationCtrl.text.trim().isEmpty) {
      _showSnack(
          "Ingresa la justificación del excedente", isError: true);
      return;
    }
 
    setState(() => _isSavingOrder = true);
 
    final newOrder = PurchaseOrder(
      id: _generateFolio(),
      materialId: widget.item.materialId,
      materialName: widget.item.materialName,
      unit: widget.item.unit,
      providerName: widget.item.selectedProviderName!,
      providerId: widget.item.selectedProviderId ?? '',
      quantity: qty,
      quotedQuantity: widget.item.toBuyQty,
      unitPrice: price,
      totalPrice: qty * price,
      date: DateTime.now(),
      justification: _hasExcess
          ? _justificationCtrl.text.trim()
          : null,
      hasExcess: _hasExcess,
    );
 
    setState(() {
      widget.item.purchaseOrders = [
        ...(_orders),
        newOrder,
      ];
      widget.item.purchasedQty = qty;
      _isRegistering = false;
      _justificationCtrl.clear();
      _isSavingOrder = false;
    });
 
    widget.onChanged();
    _showSnack("Orden registrada correctamente");
  }
 
  // ── Descargar PDF ────────────────────────────────────────
  Future<void> _downloadPdf(PurchaseOrder order) async {
    setState(() => _isGeneratingPdf = true);
    try {
      await PurchaseOrderPdfGenerator.generateAndPrint(
        order: order,
        projectTitle: widget.process.title,
        clientName: widget.process.client,
        folio: order.id,
        generatedBy: widget.currentUserName,
      );
    } catch (e) {
      _showSnack("Error al generar PDF: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }
 
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }
 
  // ─────────────────────────────────────────────────────────
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
          color: isCovered
              ? const Color(0xFF6EE7B7)
              : const Color(0xFFFCA5A5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header del material ────────────────────────
            _buildMaterialHeader(item, isCovered, pending),
 
            const SizedBox(height: 12),
 
            // ── Chips de cantidad ──────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(
                    "Requerido",
                    "${_fmtQty(item.requiredQty)} ${item.materialName}",
                    const Color(0xFF64748B)),
                _buildChip(
                    "En Stock",
                    "${_fmtQty(item.stockQty)} ${item.materialName}",
                    const Color(0xFF2563EB)),
                _buildChip(
                    "A Comprar",
                    "${_fmtQty(item.toBuyQty)} ${item.materialName}",
                    const Color(0xFFEA580C)),
              ],
            ),
 
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
 
            // ── Formulario de selección (proveedor, qty, precio, fecha) ──
            _buildPurchaseForm(item),
 
            // ── Comparativa precio ─────────────────────────
            if (item.selectedProviderId != null) ...[
              const SizedBox(height: 12),
              _buildPriceComparison(item),
            ],

            _buildCostBreakdown(),
 
            // ── Botón: Registrar Orden ─────────────────────
            if (widget.isEditable && !_isRegistering) ...[
              const SizedBox(height: 16),
              _buildRegisterButton(),
            ],
 
            // ── Formulario de registro de orden ───────────
            if (_isRegistering) ...[
              const SizedBox(height: 16),
              _buildOrderForm(),
            ],
 
            // ── Historial de órdenes ───────────────────────
            if (_orders.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildOrderHistory(),
            ],
          ],
        ),
      ),
    );
  }
 
  // ── HEADER MATERIAL ───────────────────────────────────────
  Widget _buildMaterialHeader(
      LogisticsItem item, bool isCovered, double pending) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.package,
              size: 16, color: Color(0xFF64748B)),
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
                Text(item.unit,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isCovered
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCovered
                  ? const Color(0xFF6EE7B7)
                  : const Color(0xFFFCA5A5),
            ),
          ),
          child: Text(
            isCovered
                ? "✓ Cubierto"
                : "Pendiente: ${_fmtQty(pending)} ${item.materialName}",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isCovered
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
            ),
          ),
        ),
      ],
    );
  }
 
  // ── FORMULARIO DE COMPRA ──────────────────────────────────
  Widget _buildPurchaseForm(LogisticsItem item) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600;
      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("PROVEEDOR"),
            const SizedBox(height: 8),
            _buildProviderSelector(),
            const SizedBox(height: 12),
            Row(children: [
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
            ]),
          ],
        );
      }
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
    });
  }
 
  // ── PROVEEDOR ─────────────────────────────────────────────
  Widget _buildProviderSelector() {
    if (_prices.isEmpty) {
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
    return DropdownButtonFormField<String>(
      value: _prices
              .any((p) => p.providerId == widget.item.selectedProviderId)
          ? widget.item.selectedProviderId
          : null,
      isExpanded: true,
      hint: Text("Seleccionar proveedor...",
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      items: _prices.map((price) {
        return DropdownMenuItem<String>(
          value: price.providerId,
          child: Row(children: [
            Expanded(
              child: Text(price.providerName,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "\$${price.price.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700),
              ),
            ),
          ]),
        );
      }).toList(),
      onChanged: widget.isEditable
          ? (id) {
              if (id == null) return;
              final price =
                  _prices.firstWhere((p) => p.providerId == id);
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
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        widget.item.purchasedQty = double.tryParse(val) ?? 0;
        setState(() {}); // para actualizar _hasExcess
        widget.onChanged();
      },
      style: GoogleFonts.inter(fontSize: 13),
      decoration: _inputDeco("0"),
    );
  }
 
  Widget _buildPriceField() {
    return TextField(
      controller: _priceCtrl,
      enabled: widget.isEditable,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        widget.item.actualUnitPrice = double.tryParse(val) ?? 0;
        widget.onChanged();
      },
      style: GoogleFonts.inter(fontSize: 13),
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
                    colorScheme: const ColorScheme.light(
                        primary: Color(0xFFB45309)),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          const Icon(LucideIcons.calendar,
              size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.item.purchaseDate != null
                  ? DateFormat('dd/MM/yy')
                      .format(widget.item.purchaseDate!)
                  : DateFormat('dd/MM/yy').format(DateTime.now()),
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF1E293B)),
            ),
          ),
        ]),
      ),
    );
  }
 
  // ── COMPARATIVA DE PRECIO ─────────────────────────────────
  Widget _buildPriceComparison(LogisticsItem item) {
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
      text =
          "Precio igual al cotizado: ${widget.currFmt.format(item.quotedUnitPrice)}";
    }
 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(fontSize: 11, color: iconColor)),
        ),
      ]),
    );
  }

  /// Muestra el desglose: costo de stock vs costo de compra
Widget _buildCostBreakdown() {
  final item = widget.item;
 
  // Solo mostrar si hay algo que comparar
  final hasStock = item.stockQty > 0;
  final hasPurchased = item.purchasedQty > 0;
  if (!hasStock && !hasPurchased) return const SizedBox.shrink();
 
  // ¿Los precios difieren? (para resaltar la diferencia)
  final pricesDiffer =
      (item.stockUnitPrice - item.actualUnitPrice).abs() > 0.01;
 
  return Container(
    margin: const EdgeInsets.only(top: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              const Icon(LucideIcons.calculator,
                  size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                "DESGLOSE DE COSTO",
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              if (pricesDiffer) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    "precios distintos",
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
 
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
 
        // Fila: Stock
        if (hasStock)
          _costRow(
            icon: LucideIcons.package,
            iconColor: const Color(0xFF2563EB),
            label: "Stock existente",
            detail:
                "${_fmtQty(item.stockQty.clamp(0, item.requiredQty))} ${item.materialName} × "
                "${widget.currFmt.format(item.stockUnitPrice)}",
            total: item.stockCost,
            totalColor: const Color(0xFF2563EB),
            currFmt: widget.currFmt,
          ),
 
        // Separador interno
        if (hasStock && hasPurchased)
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
 
        // Fila: Comprado
        if (hasPurchased)
          _costRow(
            icon: LucideIcons.shoppingCart,
            iconColor: const Color(0xFF059669),
            label: "Compra a proveedor",
            detail:
                "${_fmtQty(item.purchasedQty.clamp(0, (item.requiredQty - item.stockQty).clamp(0, double.infinity)))} ${item.materialName} × "
                "${widget.currFmt.format(item.actualUnitPrice)}",
            total: item.purchasedCost,
            totalColor: const Color(0xFF059669),
            currFmt: widget.currFmt,
          ),
 
        // Total
        if (hasStock && hasPurchased) ...[
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total material",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.currFmt.format(item.totalCost),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
 
/// Fila de costo individual (stock o compra)
Widget _costRow({
  required IconData icon,
  required Color iconColor,
  required String label,
  required String detail,
  required double total,
  required Color totalColor,
  required NumberFormat currFmt,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        Text(
          currFmt.format(total),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: totalColor,
          ),
        ),
      ],
    ),
  );
}

 
  // ── BOTÓN REGISTRAR ORDEN ─────────────────────────────────
  Widget _buildRegisterButton() {
    return InkWell(
      onTap: () => setState(() => _isRegistering = true),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.clipboardCheck,
              size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text("Registrar Orden de Compra",
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }
 
  // ── FORMULARIO DE ORDEN (con justificación) ───────────────
  Widget _buildOrderForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.clipboardCheck,
                size: 16, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            Text("Nueva Orden de Compra",
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A))),
          ]),
 
          const SizedBox(height: 14),
 
          // Resumen de la orden que se va a crear
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              Expanded(
                child: _summaryItem("Material",
                    widget.item.materialName)),
              Expanded(
                  child: _summaryItem(
                      "Proveedor",
                      widget.item.selectedProviderName ??
                          "No seleccionado")),
              _summaryItem(
                  "Cantidad",
                  "${_purchasedCtrl.text.isNotEmpty ? _purchasedCtrl.text : '0'} "
                      "${widget.item.materialName}"),
              _summaryItem(
                  "Total",
                  widget.currFmt.format(
                      (double.tryParse(_purchasedCtrl.text) ?? 0) *
                          widget.item.actualUnitPrice)),
            ]),
          ),
 
          // Alerta de excedente
          if (_hasExcess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Estás comprando ${_fmtQty(_excessQty)} ${widget.item.materialName} más de lo cotizado. "
                    "Se requiere justificación.",
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFFDC2626)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text("JUSTIFICACIÓN DEL EXCEDENTE *",
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _justificationCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: _inputDeco(
                  "Explica el motivo de la compra adicional..."),
            ),
          ],
 
          const SizedBox(height: 16),
 
          Row(children: [
            TextButton(
              onPressed: () =>
                  setState(() {
                    _isRegistering = false;
                    _justificationCtrl.clear();
                  }),
              child: Text("Cancelar",
                  style: GoogleFonts.inter(
                      color: const Color(0xFF64748B))),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isSavingOrder ? null : _registerOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: _isSavingOrder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.checkCircle2, size: 16),
              label: Text("Confirmar y Registrar",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ),
    );
  }
 
  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
 
  // ── HISTORIAL DE ÓRDENES ──────────────────────────────────
  Widget _buildOrderHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de sección
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(LucideIcons.history,
                size: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 8),
          Text("HISTORIAL DE ÓRDENES",
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF475569),
                letterSpacing: 0.6,
              )),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text("${_orders.length}",
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ]),
 
        const SizedBox(height: 10),
 
        // Lista de órdenes
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: _orders.asMap().entries.map((entry) {
              final i = entry.key;
              final order = entry.value;
              final isLast = i == _orders.length - 1;
              return _buildOrderRow(order, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }
 
  Widget _buildOrderRow(PurchaseOrder order, bool isLast) {
    final dateFmt = DateFormat('d/M/yyyy');
 
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: order.hasExcess
            ? const Color(0xFFFFF7ED)
            : Colors.white,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(9),
                bottomRight: Radius.circular(9))
            : null,
      ),
      child: Column(
        children: [
          Row(children: [
            // Folio
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(order.id,
                  style: GoogleFonts.robotoMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
              )),
            ),
            const SizedBox(width: 8),
            // Proveedor + fecha
            Expanded(
              child: Row(children: [
                Text(order.providerName,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B))),
                const SizedBox(width: 8),
                Text("| ${dateFmt.format(order.date)}",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8))),
              ]),
            ),
            // Total
            Text(
              widget.currFmt.format(order.totalPrice),
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF059669)),
            ),
            const SizedBox(width: 12),
            // Botón PDF
            Tooltip(
              message: "Descargar Orden de Compra (PDF)",
              child: InkWell(
                onTap: _isGeneratingPdf
                    ? null
                    : () => _downloadPdf(order),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: _isGeneratingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5))
                      : const Icon(LucideIcons.fileDown,
                          size: 16, color: Color(0xFF475569)),
                ),
              ),
            ),
          ]),
 
          // Excedente + justificación (si aplica)
          if (order.hasExcess && order.justification != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(LucideIcons.alertTriangle,
                        size: 12, color: Color(0xFFEA580C)),
                    const SizedBox(width: 6),
                    Text(
                      "Excedente: +${_fmtQty(order.quantity - order.quotedQuantity)} ${order.materialName}",
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEA580C)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    order.justification!,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF7C2D12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
 
  // ── HELPERS UI ────────────────────────────────────────────
  Widget _buildChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
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
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
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
        hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade400, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          borderSide: const BorderSide(
              color: Color(0xFFB45309), width: 1.5),
        ),
      );
 
  static String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(2);
  }
}