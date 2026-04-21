// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:ici_process/ui/widgets/import_export_buttons.dart';
import 'package:ici_process/ui/widgets/material_assignments_view.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/material_model.dart';
import '../../models/provider_model.dart';
import '../../services/material_service.dart';
import '../../services/provider_service.dart';

class MaterialCatalogScreen extends StatefulWidget {
  final UserModel currentUser;
  const MaterialCatalogScreen({super.key, required this.currentUser});

  @override
  State<MaterialCatalogScreen> createState() => _MaterialCatalogScreenState();
}

class _MaterialCatalogScreenState extends State<MaterialCatalogScreen> {
  final MaterialService _materialService = MaterialService();
  final ProviderService _providerService = ProviderService();

  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(); // <--- 1. NUEVO CONTROLADOR DE STOCK
  late Stream<List<MaterialItem>> _materialsStream;
  late Stream<List<Provider>> _providersStream;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterStock = 'Todos'; // Todos, Con Stock, Sin Stock, Apartado
  Timer? _debounceTimer;
  
  // Lista temporal para guardar los precios antes de subir a Firebase
  List<PriceEntry> _tempPrices = [];
  bool _isUploading = false;
  String _currentView = 'catalogo'; // 'catalogo' o 'asignaciones'

  // Colores
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF10B981);

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_materials');

  @override
  void initState() {
    super.initState();
    // 2. Inicializamos los streams una sola vez aquí
    _materialsStream = _materialService.getMaterials();
    _providersStream = _providerService.getProviders();
  }
  
  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _stockCtrl.dispose(); // <--- NO OLVIDAR EL DISPOSE
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // --- GUARDAR ---
  Future<void> _handleSave({String? docId}) async {
  if (!canEdit) return;

  if (_nameCtrl.text.trim().isEmpty || _unitCtrl.text.trim().isEmpty) {
    _showSnack("Nombre y Unidad son obligatorios", isSuccess: false);
    return;
  }

  final double stockValue = double.tryParse(_stockCtrl.text) ?? 0.0;

  // Aviso (no bloqueante) si no hay precios
  if (_tempPrices.isEmpty) {
    _showSnack("Advertencia: No has agregado ningún precio/proveedor", isSuccess: false);
  }

  setState(() => _isUploading = true);

  try {
    if (docId == null) {
      final material = MaterialItem(
        id: '',
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        stock: stockValue,
        reservedStock: 0.0,
        prices: _tempPrices,
      );
      await _materialService.addMaterial(material);
      _invalidateCache(); // ★ NUEVO
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _resetForm();
      _showSnack("Material registrado correctamente");
    } else {
      final originalItem = await _materialService.getMaterialById(docId);
      if (originalItem == null) {
        _showSnack("Error: material no encontrado", isSuccess: false);
        return;
      }

      final Map<String, dynamic> updateData = {
        'name': _nameCtrl.text.trim(),
        'unit': _unitCtrl.text.trim(),
        'prices': _tempPrices.map((e) => e.toMap()).toList(),
      };

      if (stockValue != originalItem.stock) {
        updateData['stock'] = stockValue;
      }

      await _materialService.updateMaterialFields(docId, updateData);
      _invalidateCache(); // ★ NUEVO
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _resetForm();
      _showSnack("Material actualizado");
    }
  } catch (e) {
    print("❌ ERROR AL GUARDAR: $e");
    _showSnack("Error: $e", isSuccess: false);
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }
}

  void _resetForm() {
    _nameCtrl.clear();
    _unitCtrl.clear();
    _stockCtrl.clear(); // <--- LIMPIAR STOCK
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

  // ★ CACHÉ (basado en identidad de lista, no en hash)
  List<MaterialItem>? _cachedFiltered;
  Map<String, int>? _cachedCounts;
  List<MaterialItem>? _lastMaterialsRef; // ★ referencia de la lista anterior
  String _lastFilterKey = '';
  List<_MaterialIndex>? _searchIndex;

  // Estructura ligera para búsqueda
  List<_MaterialIndex> _buildIndex(List<MaterialItem> materials) {
    return materials.map((m) => _MaterialIndex(
      material: m,
      nameLower: m.name.toLowerCase(),
      unitLower: m.unit.toLowerCase(),
      providersLower: m.prices.map((p) => p.providerName.toLowerCase()).toList(),
    )).toList();
  }

  Map<String, int> _countByStock(List<MaterialItem> materials) {
    // ★ Identidad de lista: Firebase emite una NUEVA lista cada vez.
    // identical() es O(1) y 100% confiable, a diferencia de un hash.
    if (_cachedCounts != null && identical(materials, _lastMaterialsRef)) {
      return _cachedCounts!;
    }

    int withStock = 0, withoutStock = 0, reserved = 0;
    for (final m in materials) {
      if (m.stock > 0) withStock++; else withoutStock++;
      if (m.reservedStock > 0) reserved++;
    }

    _cachedCounts = {
      'Todos': materials.length,
      'Con Stock': withStock,
      'Sin Stock': withoutStock,
      'Apartado': reserved,
    };
    _lastMaterialsRef = materials;        // ★ guardamos la referencia
    _cachedFiltered = null;               // ★ invalidamos filtrado
    _searchIndex = null;                  // ★ invalidamos índice
    return _cachedCounts!;
  }

  // ★ Fuerza al caché a reconstruirse en el próximo build
  void _invalidateCache() {
    _cachedFiltered = null;
    _cachedCounts = null;
    _lastMaterialsRef = null;
    _searchIndex = null;
    _lastFilterKey = '';
  }

  List<MaterialItem> _applyFilters(List<MaterialItem> materials) {
    final filterKey = '${identityHashCode(materials)}|$_searchQuery|$_filterStock';
    if (_cachedFiltered != null && filterKey == _lastFilterKey) {
      return _cachedFiltered!;
    }

    // ★ Construir/reusar índice en lowercase (evita .toLowerCase() repetido)
    _searchIndex ??= _buildIndex(materials);

    final query = _searchQuery.toLowerCase();
    final hasQuery = query.isNotEmpty;

    final result = <MaterialItem>[];
    for (final idx in _searchIndex!) {
      final m = idx.material;

      if (_filterStock == 'Con Stock' && m.stock <= 0) continue;
      if (_filterStock == 'Sin Stock' && m.stock > 0) continue;
      if (_filterStock == 'Apartado' && m.reservedStock <= 0) continue;

      if (hasQuery) {
        if (idx.nameLower.contains(query)) {
          result.add(m);
          continue;
        }
        if (idx.unitLower.contains(query)) {
          result.add(m);
          continue;
        }
        bool providerMatch = false;
        for (final pl in idx.providersLower) {
          if (pl.contains(query)) { providerMatch = true; break; }
        }
        if (!providerMatch) continue;
      }
      result.add(m);
    }

    _cachedFiltered = result;
    _lastFilterKey = filterKey;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: LayoutBuilder(builder: (context, constraints) {
        // ★ CUSTOMSCROLLVIEW con Slivers = virtualización REAL
        return CustomScrollView(
          slivers: [
            // Header + filtros viajan como "slivers" normales
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            if (_currentView == 'asignaciones')
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: MaterialAssignmentsView(),
                ),
              )
            else
              // ★ StreamBuilder ahora devuelve slivers
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                sliver: StreamBuilder<List<MaterialItem>>(
                  stream: _materialsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(child: Text("Error: ${snapshot.error}"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        )),
                      );
                    }
                    final allMaterials = snapshot.data ?? [];
                    final counts = _countByStock(allMaterials);
                    final filtered = _applyFilters(allMaterials);

                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(child: _buildSearchAndFilters(counts)),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),

                        // Contador
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              filtered.length == allMaterials.length
                                  ? "${allMaterials.length} material${allMaterials.length == 1 ? '' : 'es'}"
                                  : "${filtered.length} de ${allMaterials.length} material${allMaterials.length == 1 ? '' : 'es'}",
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary),
                            ),
                          ),
                        ),

                        // ★ LISTA VIRTUALIZADA DE VERDAD
                        if (filtered.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyState())
                        else
                          SliverList.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final item = filtered[index];
                              // ★ _ProvidersScope: proveedores via InheritedWidget
                              // para no pasarlos por parámetros en cada rebuild
                              return Padding(
                                key: ValueKey('${item.id}_${identityHashCode(item)}'),
                                padding: EdgeInsets.only(
                                  bottom: index < filtered.length - 1 ? 12 : 40,
                                ),
                                child: _MaterialCard(
                                  item: item,
                                  canEdit: canEdit,
                                  accentColor: _accentColor,
                                  cardBg: _cardBg,
                                  borderColor: _borderColor,
                                  bgPage: _bgPage,
                                  textPrimary: _textPrimary,
                                  textSecondary: _textSecondary,
                                  onEdit: () => _showEditDialog(item),
                                  onDelete: () => _confirmDelete(item),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
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
              _searchQuery.isNotEmpty ? LucideIcons.searchX : LucideIcons.packageX,
              size: 44,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? "Sin resultados para \"$_searchQuery\""
                  : _filterStock != 'Todos'
                      ? "Sin materiales \"$_filterStock\""
                      : "Sin materiales registrados",
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
            ),
            if (_searchQuery.isNotEmpty || _filterStock != 'Todos') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() { _searchQuery = ''; _filterStock = 'Todos'; });
                },
                icon: Icon(LucideIcons.rotateCcw, size: 14, color: _primaryBlue),
                label: Text("Limpiar filtros", style: GoogleFonts.inter(fontSize: 13, color: _primaryBlue, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
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
          child: Icon(LucideIcons.packageSearch, color: _accentColor, size: 30),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Catálogo de Materiales", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("Gestiona precios, inventario y proveedores.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
            ],
          ),
        ),

        // ★ NUEVO: BOTÓN "NUEVO MATERIAL" ──────────────────────
        if (canEdit && _currentView == 'catalogo') ...[
          _buildNewMaterialButton(),
          const SizedBox(width: 12),
        ],

        // ── BOTONES IMPORTAR / EXPORTAR ──
        if (canEdit) ...[
          ImportExportButtons(
            onImportComplete: () {
              setState(() {});
            },
          ),
          const SizedBox(width: 12),
        ],

        // ── TOGGLE ──
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton('catalogo', 'Catálogo', LucideIcons.package),
              _buildToggleButton('asignaciones', 'Asignaciones', LucideIcons.gitBranch),
            ],
          ),
        ),
      ],
    );
  }

  // ★ NUEVO MÉTODO: Botón primario "Nuevo Material"
  Widget _buildNewMaterialButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCreateDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryBlue, const Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                "Nuevo Material",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String value, String label, IconData icon) {
    final isActive = _currentView == value;
    return InkWell(
      onTap: () => setState(() => _currentView = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isActive ? Colors.white : _textSecondary),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.white : _textSecondary,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(Map<String, int> counts) {
    final filterOptions = ['Todos', 'Con Stock', 'Sin Stock', 'Apartado'];

    Color _getFilterColor(String filter) {
      switch (filter) {
        case 'Con Stock': return const Color(0xFF059669);
        case 'Sin Stock': return const Color(0xFFEF4444);
        case 'Apartado': return const Color(0xFFD97706);
        default: return _primaryBlue;
      }
    }

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
          // Barra de búsqueda
          TextField(
            controller: _searchCtrl,
            onChanged: (val) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                final trimmed = val.trim();
                if (trimmed == _searchQuery) return; // ★ evita setState innecesario
                setState(() => _searchQuery = trimmed);
              });
            },
            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
            decoration: InputDecoration(
              hintText: "Buscar por nombre, unidad o proveedor...",
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        _debounceTimer?.cancel();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((filter) {
                final isActive = _filterStock == filter;
                final count = counts[filter] ?? 0;
                final color = _getFilterColor(filter);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _filterStock = filter),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? color.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? color.withOpacity(0.4) : _borderColor,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (filter != 'Todos') ...[
                            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                          ],
                          Text(filter, style: GoogleFonts.inter(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? color : _textSecondary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? color.withOpacity(0.15) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("$count", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? color : _textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChip(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(color: _borderColor, thickness: 1, height: 1);
  }

  // ★ DIÁLOGO DE CREACIÓN (equivalente al formulario antiguo)
  void _showCreateDialog() {
    // Limpiar estado antes de abrir
    _nameCtrl.clear();
    _unitCtrl.clear();
    _stockCtrl.clear();
    _tempPrices = [];

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
              constraints: const BoxConstraints(maxHeight: 700),
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
                  // ── HEADER con acento azul (estilo original) ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryBlue.withOpacity(0.08), _primaryBlue.withOpacity(0.02)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.5))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(LucideIcons.package, color: _primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Nuevo Material",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19,
                                  color: _textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Completa los datos del material",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _resetForm();
                            Navigator.pop(ctx);
                          },
                          icon: Icon(LucideIcons.x, color: _textSecondary, size: 20),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // ── CUERPO DEL FORMULARIO ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sección: Identificación
                          _buildSectionChip("Identificación del Material", LucideIcons.package),
                          const SizedBox(height: 12),
                          _input(_nameCtrl, "Nombre del Material", LucideIcons.package),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _input(_unitCtrl, "Unidad (ej: m, pza)", LucideIcons.ruler)),
                              const SizedBox(width: 12),
                              Expanded(child: _input(_stockCtrl, "Stock Actual", LucideIcons.layers, isNumber: true)),
                            ],
                          ),

                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 20),

                          // Sección: Lista de Precios
                          _buildSectionChip("Lista de Precios", LucideIcons.tags),
                          const SizedBox(height: 14),

                          // ★ StreamBuilder LOCAL: los proveedores solo se cargan aquí
                          StreamBuilder<List<Provider>>(
                            stream: _providersStream,
                            builder: (ctx, snap) {
                              final providers = snap.data ?? [];
                              return _PriceManager(
                                providers: providers,
                                initialPrices: _tempPrices,
                                onChanged: (updatedList) {
                                  setModalState(() => _tempPrices = updatedList);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── FOOTER con botones ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _borderColor.withOpacity(0.6))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              _resetForm();
                              Navigator.pop(ctx);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: _borderColor),
                              ),
                            ),
                            child: Text(
                              "Cancelar",
                              style: GoogleFonts.inter(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : () => _handleSave(docId: null),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primaryBlue.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.checkCircle, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Guardar Material",
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
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

  // --- DIÁLOGOS Y HELPERS ---
  void _showEditDialog(MaterialItem item) {
    _nameCtrl.text = item.name;
    _unitCtrl.text = item.unit;
    _stockCtrl.text = item.stock.toString();
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
              constraints: const BoxConstraints(maxHeight: 650),
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
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: const Center(child: Icon(LucideIcons.box, color: Colors.white, size: 24)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Editar Material", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text(item.name, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () { _resetForm(); Navigator.pop(ctx); },
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
                          Text("NOMBRE DEL MATERIAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(_nameCtrl, "Ej. Cemento Cruz Azul", LucideIcons.package),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("UNIDAD", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                                    const SizedBox(height: 8),
                                    _input(_unitCtrl, "Ej. Bulto", LucideIcons.ruler),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("STOCK", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                                    const SizedBox(height: 8),
                                    _input(_stockCtrl, "0.00", LucideIcons.layers, isNumber: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(LucideIcons.dollarSign, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Text("LISTA DE PRECIOS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<List<Provider>>(
                            stream: _providersStream,
                            builder: (ctx, snap) {
                              final providers = snap.data ?? [];
                              return _PriceManager(
                                providers: providers,
                                initialPrices: _tempPrices,
                                onChanged: (updated) {
                                  setModalState(() => _tempPrices = updated);
                                },
                              );
                            },
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
    ).then((_) => _resetForm());
  }

  void _confirmDelete(MaterialItem item) {
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
                          Text("Eliminar Material", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text("Se eliminará del inventario", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
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
                            child: const Icon(LucideIcons.box, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text("${item.unit} · Stock: ${item.stock}", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            child: Text("El material será eliminado permanentemente del catálogo junto con su registro de stock actual.", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500, height: 1.4)),
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
                          _materialService.deleteMaterial(item.id);
                          _invalidateCache(); // ★ NUEVO
                          Navigator.pop(ctx);
                          _showSnack("Material eliminado correctamente");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text("Eliminar Material", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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

  // ACTUALICÉ EL HELPER INPUT PARA ACEPTAR TECLADO NUMÉRICO
  Widget _input(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true, fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

class _PriceManager extends StatefulWidget {
  final List<Provider> providers;
  final List<PriceEntry> initialPrices;
  final Function(List<PriceEntry>) onChanged;

  const _PriceManager({required this.providers, required this.initialPrices, required this.onChanged});

  @override
  State<_PriceManager> createState() => _PriceManagerState();
}

class _PriceManagerState extends State<_PriceManager> {
  Provider? selectedProvider;
  final TextEditingController priceCtrl = TextEditingController();

  @override
  void dispose() {
    priceCtrl.dispose();
    super.dispose();
  }

  // ★ Ya NO mantenemos una copia local de 'prices'.
  // Siempre leemos de widget.initialPrices (que el padre nos pasa)
  // y notificamos cambios vía widget.onChanged.
  List<PriceEntry> get _currentPrices => widget.initialPrices;

  void _addPrice() {
    if (selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un proveedor")),
      );
      return;
    }
    if (priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe un precio")),
      );
      return;
    }

    final val = double.tryParse(priceCtrl.text);
    if (val == null) return;

    final newEntry = PriceEntry(
      providerId: selectedProvider!.id,
      providerName: selectedProvider!.name,
      price: val,
      updatedAt: DateTime.now(),
    );

    // ★ Creamos una NUEVA lista (no mutamos la original)
    final updated = List<PriceEntry>.from(_currentPrices);
    final index = updated.indexWhere((p) => p.providerId == selectedProvider!.id);
    if (index >= 0) {
      updated[index] = newEntry;
    } else {
      updated.add(newEntry);
    }

    // Limpiamos inputs locales
    setState(() {
      priceCtrl.clear();
      selectedProvider = null;
    });

    // ★ Notificamos al padre: él es el dueño de la lista
    widget.onChanged(updated);
  }

  void _removePrice(int index) {
    final updated = List<PriceEntry>.from(_currentPrices)..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    // ★ Siempre renderiza según lo que el padre dice que existe
    final prices = _currentPrices;

    return Column(
      children: [
        // --- FILA DE ENTRADA ---
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
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
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
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addPrice,
              icon: const Icon(LucideIcons.plusCircle, color: Color(0xFF2563EB)),
              tooltip: "Agregar a la lista",
            ),
          ],
        ),

        const SizedBox(height: 12),

        // --- LISTA VISUAL ---
        if (prices.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                "Agrega proveedores y precios arriba 👆",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: prices.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: idx < prices.length - 1
                        ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.providerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Text("\$${p.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd/MM').format(p.updatedAt),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _removePrice(idx),
                        child: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  ★ TARJETA DE MATERIAL (Widget separado para performance)
//  Se extrae del método _buildCard original. Al ser StatelessWidget
//  con key, Flutter puede omitir reconstrucciones innecesarias.
// ═══════════════════════════════════════════════════════════════════════
class _MaterialCard extends StatelessWidget {
  final MaterialItem item;
  final bool canEdit;
  final Color accentColor, cardBg, borderColor, bgPage, textPrimary, textSecondary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MaterialCard({
    required this.item,
    required this.canEdit,
    required this.accentColor,
    required this.cardBg,
    required this.borderColor,
    required this.bgPage,
    required this.textPrimary,
    required this.textSecondary,
    required this.onEdit,
    required this.onDelete,
  });

  // ★ Estilos estáticos: se crean UNA vez en toda la app
  static final _titleStyle = GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16);
  static final _unitBadgeStyle = GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600);
  static final _priceRangeStyle = GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700);
  static final _sectionLabelStyle = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5);
  static final _providerNameStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500);
  static final _providerPriceStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800);
  static final _providerDateStyle = GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8));
  static final _chipLabelStyle = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3);
  static final _chipValueStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800);

  @override
  Widget build(BuildContext context) {
    final bool lowStock = item.stock <= 0;
    final bool hasReserved = item.reservedStock > 0;

    // ★ Calcular min/max en una sola pasada (era 2 pasadas)
    double minPrice = 0, maxPrice = 0;
    if (item.prices.isNotEmpty) {
      minPrice = item.prices.first.price;
      maxPrice = minPrice;
      for (int i = 1; i < item.prices.length; i++) {
        final p = item.prices[i].price;
        if (p < minPrice) minPrice = p;
        if (p > maxPrice) maxPrice = p;
      }
    }

    return RepaintBoundary(
      // ★ RepaintBoundary aísla la pintura de esta tarjeta
      // Si otra tarjeta cambia, esta no se re-pinta
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Fila superior
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withOpacity(0.1), accentColor.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withOpacity(0.15)),
                  ),
                  child: Center(
                    child: Text(
                      item.unit.isNotEmpty ? item.unit.substring(0, min(2, item.unit.length)).toUpperCase() : 'M',
                      style: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: _titleStyle.copyWith(color: textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            child: Text(item.unit, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          if (item.prices.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: accentColor.withOpacity(0.2)),
                              ),
                              child: Text(
                                minPrice == maxPrice
                                    ? "\$${minPrice.toStringAsFixed(2)}"
                                    : "\$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}",
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Acciones
                if (canEdit)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionIcon(LucideIcons.edit3, const Color(0xFF2563EB), onEdit),
                      const SizedBox(width: 4),
                      _actionIcon(LucideIcons.trash2, const Color(0xFFEF4444), onDelete),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // Métricas de inventario
            Row(
              children: [
                _stockChip(
                  icon: LucideIcons.layers,
                  label: "Stock",
                  value: "${item.stock.toStringAsFixed(2)} ${item.unit}",
                  color: lowStock ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                if (hasReserved) ...[
                  _stockChip(
                    icon: LucideIcons.lock,
                    label: "Apartado",
                    value: item.reservedStock.toStringAsFixed(2),
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  _stockChip(
                    icon: LucideIcons.packageCheck,
                    label: "Disponible",
                    value: "${item.availableStock.toStringAsFixed(2)} ${item.unit}",
                    color: const Color(0xFF059669),
                  ),
                ] else
                  _stockChip(
                    icon: LucideIcons.packageCheck,
                    label: "Disponible",
                    value: "${item.availableStock.toStringAsFixed(2)} ${item.unit}",
                    color: const Color(0xFF059669),
                  ),
              ],
            ),

            // Precios por proveedor
            if (item.prices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.store, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text("PRECIOS (${item.prices.length})", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...item.prices.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(width: 5, height: 5, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.providerName, style: GoogleFonts.inter(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500))),
                          Text("\$${p.price.toStringAsFixed(2)}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary)),
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
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
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

  Widget _stockChip({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.7), letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ★ Índice precomputado para búsqueda rápida
class _MaterialIndex {
  final MaterialItem material;
  final String nameLower;
  final String unitLower;
  final List<String> providersLower;

  _MaterialIndex({
    required this.material,
    required this.nameLower,
    required this.unitLower,
    required this.providersLower,
  });
}