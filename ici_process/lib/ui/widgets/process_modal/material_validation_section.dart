import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../models/process_model.dart';
import '../../../models/quotation_model.dart';
import '../../../models/material_model.dart';
import '../../../models/user_model.dart';
import '../../../services/material_service.dart';
import '../../../services/user_service.dart';

// ============================================================
//  DATA MODEL: MaterialValidationItem
// ============================================================
class MaterialValidationItem {
  String materialId;
  String materialName;
  String unit;
  double quotedQty;
  double validatedQty;
  double unitPrice;
  String providerName;
  String notes;
  bool isNew;       // true si fue agregado manualmente (no viene de cotización)
  bool isRemoved;   // true si el usuario lo marcó para eliminar

  MaterialValidationItem({
    required this.materialId,
    required this.materialName,
    this.unit = '',
    required this.quotedQty,
    required this.validatedQty,
    this.unitPrice = 0,
    this.providerName = '',
    this.notes = '',
    this.isNew = false,
    this.isRemoved = false,
  });

  double get difference => validatedQty - quotedQty;
  bool get wasModified => difference.abs() > 0.001 || isNew || isRemoved;

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'materialName': materialName,
        'unit': unit,
        'quotedQty': quotedQty,
        'validatedQty': validatedQty,
        'unitPrice': unitPrice,
        'providerName': providerName,
        'notes': notes,
        'isNew': isNew,
        'isRemoved': isRemoved,
      };

  factory MaterialValidationItem.fromMap(Map<String, dynamic> map) =>
      MaterialValidationItem(
        materialId: map['materialId'] ?? '',
        materialName: map['materialName'] ?? '',
        unit: map['unit'] ?? '',
        quotedQty: (map['quotedQty'] ?? 0).toDouble(),
        validatedQty: (map['validatedQty'] ?? 0).toDouble(),
        unitPrice: (map['unitPrice'] ?? 0).toDouble(),
        providerName: map['providerName'] ?? '',
        notes: map['notes'] ?? '',
        isNew: map['isNew'] ?? false,
        isRemoved: map['isRemoved'] ?? false,
      );
}

// ============================================================
//  MAIN WIDGET: MaterialValidationSection
// ============================================================
class MaterialValidationSection extends StatefulWidget {
  final ProcessModel process;
  final bool isEditable;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onDataChanged;
  final String currentUserName;

  const MaterialValidationSection({
    super.key,
    required this.process,
    required this.isEditable,
    this.initialData,
    required this.onDataChanged,
    required this.currentUserName,
  });

  @override
  State<MaterialValidationSection> createState() =>
      _MaterialValidationSectionState();
}

class _MaterialValidationSectionState extends State<MaterialValidationSection> {
  final MaterialService _materialService = MaterialService();
  final UserService _userService = UserService();
  final _currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  List<MaterialValidationItem> _items = [];
  List<MaterialItem> _materialsDB = [];
  bool _isLoading = true;

  // Estado de validación
  bool _isValidated = false;
  String? _validatedBy;
  DateTime? _validatedAt;
  String? _assignedValidatorId;
  String? _assignedValidatorName;
  String _validationNotes = '';

  bool _isSendingNotification = false;

  // ── Controllers persistentes para cantidades validadas ────
  final Map<String, TextEditingController> _qtyControllers = {};

  TextEditingController _getQtyController(String key, double value) {
    if (!_qtyControllers.containsKey(key)) {
      _qtyControllers[key] = TextEditingController(text: _fmtQty(value));
    }
    return _qtyControllers[key]!;
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  // ── Colores del tema (violeta/púrpura para E4) ────────────
  static const Color _accentDark = Color(0xFF6D28D9);
  static const Color _accentMid = Color(0xFF7C3AED);
  // ignore: unused_field
  static const Color _accentLight = Color(0xFF8B5CF6);
  static const Color _bgTint = Color(0xFFF5F3FF);
  static const Color _borderAccent = Color(0xFFDDD6FE);

  // ── Resumen calculado ─────────────────────────────────────
  int get _totalItems => _items.where((i) => !i.isRemoved).length;
  int get _modifiedItems =>
      _items.where((i) => i.wasModified && !i.isRemoved).length;
  int get _removedItems => _items.where((i) => i.isRemoved).length;
  int get _addedItems => _items.where((i) => i.isNew && !i.isRemoved).length;

  double get _quotedTotal =>
      _items.where((i) => !i.isNew).fold(0, (s, i) => s + i.quotedQty * i.unitPrice);
  double get _validatedTotal =>
      _items.where((i) => !i.isRemoved).fold(0, (s, i) => s + i.validatedQty * i.unitPrice);
  double get _costDifference => _validatedTotal - _quotedTotal;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final mats = await _materialService.getMaterials().first;
      if (!mounted) return;
      setState(() => _materialsDB = mats);

      if (widget.initialData != null && widget.initialData!.isNotEmpty) {
        _loadFromSavedData();
      } else {
        _loadFromQuotation();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadFromSavedData() {
    final data = widget.initialData!;
    _isValidated = data['isValidated'] ?? false;
    _validatedBy = data['validatedBy'];
    _validatedAt = data['validatedAt'] != null
        ? DateTime.tryParse(data['validatedAt'])
        : null;
    _assignedValidatorId = data['assignedValidatorId'];
    _assignedValidatorName = data['assignedValidatorName'];
    _validationNotes = data['validationNotes'] ?? '';

    final rawItems = (data['items'] as List? ?? []);
    _items = rawItems
        .map((e) =>
            MaterialValidationItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _loadFromQuotation() {
    if (widget.process.quotationData == null) return;
    final quotation = QuotationModel.fromMap(widget.process.quotationData!);

    for (final qItem in quotation.materials) {
      if (qItem.name.isEmpty) continue;

      MaterialItem? dbMat;
      try {
        dbMat = _materialsDB.firstWhere(
          (m) => m.name.toLowerCase() == qItem.name.toLowerCase(),
        );
      } catch (_) {}

      String providerName = '';
      if (dbMat != null && dbMat.prices.isNotEmpty) {
        // Buscar el proveedor que coincida con el precio cotizado
        try {
          final matchingPrice = dbMat.prices.firstWhere(
            (p) => (p.price - qItem.unitPrice).abs() < 0.01,
          );
          providerName = matchingPrice.providerName;
        } catch (_) {
          providerName = dbMat.prices.first.providerName;
        }
      }

      _items.add(MaterialValidationItem(
        materialId: dbMat?.id ?? qItem.id,
        materialName: qItem.name,
        unit: dbMat?.unit ?? '',
        quotedQty: qItem.quantity,
        validatedQty: qItem.quantity, // Inicia igual a lo cotizado
        unitPrice: qItem.unitPrice,
        providerName: providerName,
      ));
    }
  }

  void _notifyChanged() {
    widget.onDataChanged({
      'isValidated': _isValidated,
      'validatedBy': _validatedBy,
      'validatedAt': _validatedAt?.toIso8601String(),
      'assignedValidatorId': _assignedValidatorId,
      'assignedValidatorName': _assignedValidatorName,
      'validationNotes': _validationNotes,
      'items': _items.map((e) => e.toMap()).toList(),
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? LucideIcons.alertOctagon : LucideIcons.checkCircle2,
          color: Colors.white, size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    ));
  }

  // ── AGREGAR MATERIAL MANUALMENTE ──────────────────────────
  void _addMaterial() {
    final qtyCtrl = TextEditingController(text: '1');
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    // Filtrar materiales que no están ya en la lista
    final existingIds = _items.map((i) => i.materialId).toSet();
    final availableMats = _materialsDB.where((m) => !existingIds.contains(m.id)).toList();

    MaterialItem? selectedMat;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Agregar Material",
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A))),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancelar",
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: const Color(0xFF64748B))),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SELECCIONAR DEL CATÁLOGO",
                              style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.6)),
                          const SizedBox(height: 10),

                          // ── Lista de materiales como tiles ───────
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: availableMats.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Center(
                                      child: Text("Todos los materiales ya están en la lista",
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    shrinkWrap: true,
                                    itemCount: availableMats.length,
                                    itemBuilder: (_, i) {
                                      final mat = availableMats[i];
                                      final isSelected = selectedMat?.id == mat.id;
                                      final bestPrice = mat.prices.isNotEmpty
                                          ? mat.prices.map((p) => p.price).reduce((a, b) => a < b ? a : b)
                                          : 0.0;

                                      return InkWell(
                                        onTap: () {
                                          setSheetState(() {
                                            selectedMat = mat;
                                            nameCtrl.text = mat.name;
                                            unitCtrl.text = mat.unit;
                                            if (mat.prices.isNotEmpty) {
                                              priceCtrl.text = mat.prices.first.price.toStringAsFixed(2);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected ? _accentMid.withOpacity(0.06) : Colors.transparent,
                                            border: Border(
                                              bottom: BorderSide(color: const Color(0xFFF1F5F9), width: i < availableMats.length - 1 ? 1 : 0),
                                            ),
                                          ),
                                          child: Row(children: [
                                            Container(
                                              width: 32, height: 32,
                                              decoration: BoxDecoration(
                                                color: isSelected ? _accentMid : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  mat.unit.isNotEmpty ? mat.unit.substring(0, mat.unit.length > 2 ? 2 : mat.unit.length).toUpperCase() : 'M',
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800,
                                                      color: isSelected ? Colors.white : const Color(0xFF64748B)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(mat.name,
                                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                                          color: isSelected ? _accentMid : const Color(0xFF1E293B)),
                                                      overflow: TextOverflow.ellipsis),
                                                  if (mat.unit.isNotEmpty)
                                                    Text(mat.unit,
                                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                                ],
                                              ),
                                            ),
                                            if (bestPrice > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF059669).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text("\$${bestPrice.toStringAsFixed(2)}",
                                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                                              ),
                                            const SizedBox(width: 8),
                                            if (isSelected)
                                              Icon(LucideIcons.checkCircle2, size: 18, color: _accentMid)
                                            else
                                              const Icon(LucideIcons.circle, size: 18, color: Color(0xFFCBD5E1)),
                                          ]),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(height: 20),
                          Text("O ESCRIBIR MANUALMENTE",
                              style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.6)),
                          const SizedBox(height: 10),
                          _sheetInput(nameCtrl, "Nombre del material", LucideIcons.package),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _sheetInput(unitCtrl, "Unidad", LucideIcons.ruler)),
                            const SizedBox(width: 10),
                            Expanded(child: _sheetInput(qtyCtrl, "Cantidad", LucideIcons.layers, isNumber: true)),
                          ]),
                          const SizedBox(height: 10),
                          _sheetInput(priceCtrl, "Precio unitario", LucideIcons.dollarSign, isNumber: true),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (nameCtrl.text.trim().isEmpty) {
                                  _showSnack("Ingresa un nombre de material", isError: true);
                                  return;
                                }
                                final qty = double.tryParse(qtyCtrl.text) ?? 1;
                                final price = double.tryParse(priceCtrl.text) ?? 0;

                                String provName = '';
                                if (selectedMat != null && selectedMat!.prices.isNotEmpty) {
                                  provName = selectedMat!.prices.first.providerName;
                                }

                                setState(() {
                                  _items.add(MaterialValidationItem(
                                    materialId: selectedMat?.id ?? 'manual_${DateTime.now().millisecondsSinceEpoch}',
                                    materialName: nameCtrl.text.trim(),
                                    unit: unitCtrl.text.trim(),
                                    quotedQty: 0,
                                    validatedQty: qty,
                                    unitPrice: price,
                                    providerName: provName,
                                    isNew: true,
                                  ));
                                  if (_isValidated) {
                                    _isValidated = false;
                                    _validatedBy = null;
                                    _validatedAt = null;
                                  }
                                });
                                _notifyChanged();
                                Navigator.pop(ctx);
                                _showSnack("Material agregado a la validación");
                              },
                              icon: const Icon(LucideIcons.plusCircle, size: 18),
                              label: Text("Agregar Material",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentMid,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      qtyCtrl.dispose();
      nameCtrl.dispose();
      unitCtrl.dispose();
      priceCtrl.dispose();
    });
  }

  Widget _sheetInput(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide: BorderSide(color: _accentMid, width: 1.5),
        ),
      ),
    );
  }

  // ── CONFIRMAR VALIDACIÓN ──────────────────────────────────
  Future<void> _confirmValidation() async {
    final activeItems = _items.where((i) => !i.isRemoved).toList();
    if (activeItems.isEmpty) {
      _showSnack("No hay materiales para validar", isError: true);
      return;
    }

    // Verificar que todas las cantidades sean > 0
    final invalidItems = activeItems.where((i) => i.validatedQty <= 0).toList();
    if (invalidItems.isNotEmpty) {
      _showSnack("Hay materiales con cantidad 0. Ajusta o elimínalos.", isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 480,
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
                  gradient: LinearGradient(
                    colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentMid.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.shieldCheck, color: _accentMid, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Confirmar Validación",
                              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text("$_totalItems materiales · $_modifiedItems modificados",
                              style: GoogleFonts.inter(fontSize: 13, color: _accentMid, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    // Resumen
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(children: [
                        _summaryRow("Materiales activos", "$_totalItems", const Color(0xFF0F172A)),
                        if (_addedItems > 0) _summaryRow("Agregados nuevos", "+$_addedItems", const Color(0xFF059669)),
                        if (_removedItems > 0) _summaryRow("Eliminados", "-$_removedItems", const Color(0xFFDC2626)),
                        if (_modifiedItems > 0) _summaryRow("Modificados", "$_modifiedItems", const Color(0xFFF59E0B)),
                        const Divider(height: 16),
                        _summaryRow("Costo validado", _currFmt.format(_validatedTotal), _accentDark),
                        if (_costDifference.abs() > 0.01)
                          _summaryRow(
                            "Diferencia vs cotizado",
                            "${_costDifference > 0 ? '+' : ''}${_currFmt.format(_costDifference)}",
                            _costDifference > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _bgTint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderAccent),
                      ),
                      child: Row(children: [
                        const Icon(LucideIcons.info, size: 16, color: _accentDark),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Al validar, los materiales quedarán confirmados y se usarán como base para la etapa de Logística (E5).",
                            style: GoogleFonts.inter(fontSize: 12, color: _accentDark, fontWeight: FontWeight.w500, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(children: [
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
                      child: Text("Cancelar",
                          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentMid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(LucideIcons.shieldCheck, size: 18),
                        const SizedBox(width: 8),
                        Text("Confirmar Validación",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _isValidated = true;
        _validatedBy = widget.currentUserName;
        _validatedAt = DateTime.now();
      });
      _notifyChanged();
      _showSnack("✓ Materiales validados correctamente");
    }
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ]),
    );
  }

  // ── REVOCAR VALIDACIÓN ────────────────────────────────────
  void _revokeValidation() {
    if (!widget.isEditable) return;
    setState(() {
      _isValidated = false;
      _validatedBy = null;
      _validatedAt = null;
    });
    _notifyChanged();
    _showSnack("Validación revocada. Puedes hacer cambios nuevamente.");
  }

  // ── ENVIAR NOTIFICACIÓN AL VALIDADOR ──────────────────────
  Future<void> _sendValidatorNotification() async {
    if (_assignedValidatorId == null || _assignedValidatorId!.isEmpty) {
      _showSnack("Selecciona un validador primero", isError: true);
      return;
    }

    setState(() => _isSendingNotification = true);

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'targetUserId': _assignedValidatorId,
        'title': 'Validación de Materiales Requerida',
        'body': 'Proyecto: ${widget.process.title}\nCliente: ${widget.process.client}\nSe requiere tu validación de materiales antes de avanzar.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'senderName': widget.currentUserName,
        'processId': widget.process.id,
        'type': 'material_validation',
      });

      _showSnack("Notificación enviada a $_assignedValidatorName");
    } catch (e) {
      _showSnack("Error al enviar notificación: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSendingNotification = false);
    }
  }

  static String _fmtQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: CircularProgressIndicator(color: _accentMid)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),

          // ── Asignar validador ──────────────────────────
          _buildAssignValidator(),
          const SizedBox(height: 20),

          // ── Estado de validación ───────────────────────
          if (_isValidated) ...[
            _buildValidatedBanner(),
            const SizedBox(height: 20),
          ],

          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── Resumen de costos ──────────────────────────
          _buildCostSummary(),
          const SizedBox(height: 20),

          // ── Tabla de materiales ─────────────────────────
          _buildSectionLabel("MATERIALES A VALIDAR", LucideIcons.clipboardList),
          const SizedBox(height: 14),
          _buildMaterialsList(),

          // ── Botones de acción ──────────────────────────
          if (widget.isEditable) ...[
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _bgTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderAccent),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.clipboardCheck, color: _accentDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Validación de Materiales",
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _accentDark)),
                const SizedBox(height: 2),
                Text(
                  "$_totalItems materiales · ${_isValidated ? 'Validado' : 'Pendiente de validación'}",
                  style: GoogleFonts.inter(fontSize: 12, color: _accentMid, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isValidated ? const Color(0xFF059669).withOpacity(0.12) : const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isValidated ? const Color(0xFF059669).withOpacity(0.3) : const Color(0xFFFCD34D).withOpacity(0.5),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _isValidated ? LucideIcons.checkCircle2 : LucideIcons.clock,
                size: 14,
                color: _isValidated ? const Color(0xFF059669) : const Color(0xFFB45309),
              ),
              const SizedBox(width: 6),
              Text(
                _isValidated ? "Validado" : "Pendiente",
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: _isValidated ? const Color(0xFF059669) : const Color(0xFFB45309),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── ASIGNAR VALIDADOR ─────────────────────────────────────
  Widget _buildAssignValidator() {
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentMid.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.userCheck, size: 16, color: _accentMid),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text("ASIGNAR VALIDADOR",
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B), letterSpacing: 0.6)),
            ),
            if (_assignedValidatorName != null && _assignedValidatorName!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentMid.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentMid.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.checkCircle2, size: 12, color: _accentMid),
                  const SizedBox(width: 4),
                  Text("Asignado", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _accentMid)),
                ]),
              ),
          ]),
          const SizedBox(height: 14),

          // ── Validador seleccionado (tarjeta) ──────────────
          if (_assignedValidatorId != null && _assignedValidatorName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _accentMid.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentMid.withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _accentMid,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _assignedValidatorName!.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join(),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_assignedValidatorName!,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text("Responsable de validación",
                          style: GoogleFonts.inter(fontSize: 11, color: _accentMid)),
                    ],
                  ),
                ),
                // Botón notificar
                _buildNotifyButton(),
                if (widget.isEditable) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: "Cambiar validador",
                    child: InkWell(
                      onTap: () => _openValidatorSelector(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(LucideIcons.repeat, size: 16, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ]),
            )
          else
            // ── Botón para seleccionar ──────────────────────
            InkWell(
              onTap: widget.isEditable ? () => _openValidatorSelector() : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentMid.withOpacity(0.3), style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentMid.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.userPlus, size: 18, color: _accentMid),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Seleccionar Validador",
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _accentMid)),
                        Text("Toca para asignar un responsable",
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                    const Spacer(),
                    Icon(LucideIcons.chevronRight, size: 18, color: _accentMid.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openValidatorSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Seleccionar Validador",
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text("¿Quién será responsable de validar los materiales?",
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Cerrar", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _accentMid)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: _userService.getUsersStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _accentMid, strokeWidth: 2));
                    }
                    final users = snap.data ?? [];
                    if (users.isEmpty) {
                      return Center(child: Text("No hay usuarios disponibles",
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8))));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final user = users[i];
                        final isSelected = user.id == _assignedValidatorId;
                        final initials = user.name.trim().split(' ').take(2)
                            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _assignedValidatorId = user.id;
                                _assignedValidatorName = user.name;
                              });
                              _notifyChanged();
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? _accentMid.withOpacity(0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? _accentMid.withOpacity(0.4) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected ? _accentMid : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(initials,
                                        style: GoogleFonts.inter(
                                          fontSize: 14, fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                                        )),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 14, fontWeight: FontWeight.w700,
                                            color: isSelected ? _accentMid : const Color(0xFF0F172A),
                                          )),
                                      const SizedBox(height: 2),
                                      Text(user.email,
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(LucideIcons.checkCircle2, color: _accentMid, size: 20)
                                else
                                  const Icon(LucideIcons.circle, color: Color(0xFFCBD5E1), size: 20),
                              ]),
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
        );
      },
    );
  }

  Widget _buildNotifyButton() {
    return ElevatedButton.icon(
      onPressed: _isSendingNotification ? null : _sendValidatorNotification,
      icon: _isSendingNotification
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(LucideIcons.bellRing, size: 16),
      label: Text(_isSendingNotification ? "Enviando..." : "Notificar",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentMid,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  // ── BANNER DE VALIDADO ─────────────────────────────────────
  Widget _buildValidatedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.shieldCheck, color: Color(0xFF059669), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Materiales Validados",
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                const SizedBox(height: 4),
                Text(
                  "Por: ${_validatedBy ?? 'Desconocido'} · ${_validatedAt != null ? DateFormat('dd MMM yyyy, HH:mm').format(_validatedAt!) : ''}",
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF065F46)),
                ),
              ],
            ),
          ),
          if (widget.isEditable)
            Tooltip(
              message: "Revocar validación",
              child: InkWell(
                onTap: _revokeValidation,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Icon(LucideIcons.undo2, size: 16, color: Color(0xFFDC2626)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── RESUMEN DE COSTOS ─────────────────────────────────────
  Widget _buildCostSummary() {
    final diffColor = _costDifference > 0.01
        ? const Color(0xFFDC2626)
        : _costDifference < -0.01
            ? const Color(0xFF059669)
            : const Color(0xFF64748B);

    return _isMobile
        ? Column(children: [
            Row(children: [
              Expanded(child: _buildCostCard("COTIZADO", _quotedTotal, const Color(0xFF64748B))),
              const SizedBox(width: 10),
              Expanded(child: _buildCostCard("VALIDADO", _validatedTotal, _accentDark)),
            ]),
            const SizedBox(height: 10),
            _buildCostCard("DIFERENCIA", _costDifference, diffColor, showSign: true),
          ])
        : Row(children: [
            Expanded(child: _buildCostCard("COSTO COTIZADO", _quotedTotal, const Color(0xFF64748B))),
            const SizedBox(width: 12),
            Expanded(child: _buildCostCard("COSTO VALIDADO", _validatedTotal, _accentDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildCostCard("DIFERENCIA", _costDifference, diffColor, showSign: true)),
          ]);
  }

  Widget _buildCostCard(String label, double amount, Color color, {bool showSign = false}) {
    String displayAmount;
    if (showSign && amount > 0) {
      displayAmount = "+${_currFmt.format(amount)}";
    } else {
      displayAmount = _currFmt.format(amount);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: color.withOpacity(0.7), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(displayAmount,
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ── LISTA DE MATERIALES ───────────────────────────────────
  Widget _buildMaterialsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(children: [
            const Icon(LucideIcons.packageX, size: 40, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text("Sin materiales en la cotización",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 4),
            Text("Completa el cotizador primero.",
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFCBD5E1))),
          ]),
        ),
      );
    }

    if (_isMobile) return _buildMaterialCards();
    return _buildMaterialTable();
  }

  Widget _buildMaterialTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            Expanded(flex: 4, child: _tableLabel("Material")),
            Expanded(flex: 2, child: _tableLabel("Cotizado", align: TextAlign.center)),
            Expanded(flex: 2, child: _tableLabel("Validado", align: TextAlign.center, color: _accentDark)),
            Expanded(flex: 2, child: _tableLabel("P. Unit.", align: TextAlign.center)),
            Expanded(flex: 2, child: _tableLabel("Subtotal", align: TextAlign.center, color: const Color(0xFF059669))),
            if (widget.isEditable && !_isValidated) const SizedBox(width: 44),
          ]),
        ),
        // Items
        ...List.generate(_items.length, (i) {
          final item = _items[i];
          final isLast = i == _items.length - 1;
          return _buildTableRow(item, i, isLast);
        }),
      ]),
    );
  }

  Widget _buildTableRow(MaterialValidationItem item, int index, bool isLast) {
    final isRemoved = item.isRemoved;
    final isNew = item.isNew;
    final subtotal = item.validatedQty * item.unitPrice;
    final qtyKey = 'qty_$index';

    Color? rowBg;
    if (isRemoved) {
      rowBg = const Color(0xFFFEF2F2);
    } else if (isNew) {
      rowBg = const Color(0xFFF0FDF4);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(11)) : null,
      ),
      child: Opacity(
        opacity: isRemoved ? 0.4 : 1.0,
        child: Row(children: [
          // Material info
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(item.materialName,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                            decoration: isRemoved ? TextDecoration.lineThrough : null)),
                  ),
                  if (isNew)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("Nuevo",
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                    ),
                  if (isRemoved)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("Eliminado",
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                    ),
                ]),
                if (item.unit.isNotEmpty)
                  Text(item.unit, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                if (item.providerName.isNotEmpty)
                  Text(item.providerName,
                      style: GoogleFonts.inter(fontSize: 10, color: _accentMid, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Cotizado
          Expanded(
            flex: 2,
            child: Text(_fmtQty(item.quotedQty),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          ),
          // Validado (editable con controller persistente)
          Expanded(
            flex: 2,
            child: (widget.isEditable && !_isValidated && !isRemoved)
                ? SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _getQtyController(qtyKey, item.validatedQty),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _accentDark),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: _accentDark.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentDark.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentDark.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentMid, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        item.validatedQty = double.tryParse(val) ?? 0;
                        setState(() {});
                        _notifyChanged();
                      },
                    ),
                  )
                : Text(_fmtQty(item.validatedQty),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _accentDark)),
          ),
          // Precio unitario
          Expanded(
            flex: 2,
            child: Text(_currFmt.format(item.unitPrice),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569))),
          ),
          // Subtotal
          Expanded(
            flex: 2,
            child: Text(_currFmt.format(subtotal),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
          ),
          // Eliminar/Restaurar
          if (widget.isEditable && !_isValidated)
            SizedBox(
              width: 44,
              child: isRemoved
                  ? IconButton(
                      onPressed: () {
                        setState(() => item.isRemoved = false);
                        _notifyChanged();
                      },
                      icon: const Icon(LucideIcons.undo2, size: 15, color: Color(0xFF059669)),
                      tooltip: "Restaurar",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    )
                  : IconButton(
                      onPressed: () {
                        if (item.isNew) {
                          _qtyControllers.remove(qtyKey)?.dispose();
                          setState(() => _items.removeAt(index));
                        } else {
                          setState(() => item.isRemoved = true);
                        }
                        _notifyChanged();
                      },
                      icon: const Icon(LucideIcons.trash2, size: 15, color: Color(0xFFDC2626)),
                      tooltip: "Eliminar",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
            ),
        ]),
      ),
    );
  }

  // ── MOBILE CARDS ──────────────────────────────────────────
  Widget _buildMaterialCards() {
    return Column(
      children: _items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final subtotal = item.validatedQty * item.unitPrice;
        final qtyKey = 'qty_$i';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRemoved
                ? const Color(0xFFFEF2F2)
                : item.isNew
                    ? const Color(0xFFF0FDF4)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Opacity(
            opacity: item.isRemoved ? 0.4 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accentMid.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.package, size: 14, color: _accentMid),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.materialName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A),
                                decoration: item.isRemoved ? TextDecoration.lineThrough : null)),
                        if (item.providerName.isNotEmpty)
                          Text(item.providerName,
                              style: GoogleFonts.inter(fontSize: 10, color: _accentMid)),
                      ],
                    ),
                  ),
                  if (widget.isEditable && !_isValidated)
                    item.isRemoved
                        ? IconButton(
                            onPressed: () {
                              setState(() => item.isRemoved = false);
                              _notifyChanged();
                            },
                            icon: const Icon(LucideIcons.undo2, size: 16, color: Color(0xFF059669)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          )
                        : IconButton(
                            onPressed: () {
                              if (item.isNew) {
                                _qtyControllers.remove(qtyKey)?.dispose();
                                setState(() => _items.removeAt(i));
                              } else {
                                setState(() => item.isRemoved = true);
                              }
                              _notifyChanged();
                            },
                            icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFDC2626)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _miniCell("Cotizado", _fmtQty(item.quotedQty), const Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: (widget.isEditable && !_isValidated && !item.isRemoved)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Validado",
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _accentDark.withOpacity(0.7))),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _getQtyController(qtyKey, item.validatedQty),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _accentDark),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    filled: true,
                                    fillColor: _accentDark.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: _accentDark.withOpacity(0.2)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: _accentDark.withOpacity(0.2)),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    item.validatedQty = double.tryParse(val) ?? 0;
                                    setState(() {});
                                    _notifyChanged();
                                  },
                                ),
                              ),
                            ],
                          )
                        : _miniCell("Validado", _fmtQty(item.validatedQty), _accentDark),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _miniCell("P. Unitario", _currFmt.format(item.unitPrice), const Color(0xFF475569))),
                  const SizedBox(width: 8),
                  Expanded(child: _miniCell("Subtotal", _currFmt.format(subtotal), const Color(0xFF059669))),
                ]),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _miniCell(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ── BOTONES DE ACCIÓN ─────────────────────────────────────
  Widget _buildActionButtons() {
    if (_isValidated) return const SizedBox.shrink();

    return _isMobile
        ? Column(children: [
            SizedBox(
              width: double.infinity,
              child: _buildAddMaterialButton(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _buildValidateButton(),
            ),
          ])
        : Row(children: [
            _buildAddMaterialButton(),
            const Spacer(),
            _buildValidateButton(),
          ]);
  }

  Widget _buildAddMaterialButton() {
    return OutlinedButton.icon(
      onPressed: _addMaterial,
      icon: const Icon(LucideIcons.plusCircle, size: 16),
      label: Text("Agregar Material",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentMid,
        side: BorderSide(color: _accentMid.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildValidateButton() {
    return ElevatedButton.icon(
      onPressed: _confirmValidation,
      icon: const Icon(LucideIcons.shieldCheck, size: 18),
      label: Text("Validar Materiales",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentMid,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────
  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _accentDark.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _accentDark),
      ),
      const SizedBox(width: 10),
      Text(text,
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: _accentDark, letterSpacing: 0.6)),
    ]);
  }

  Widget _tableLabel(String text, {TextAlign align = TextAlign.left, Color? color}) {
    return Text(text,
        textAlign: align,
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: color ?? const Color(0xFF64748B), letterSpacing: 0.5));
  }
}