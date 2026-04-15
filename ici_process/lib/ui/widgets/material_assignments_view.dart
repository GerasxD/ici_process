import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/process_service.dart';
import '../../core/constants/app_constants.dart';

/// Modelo ligero: un material dentro de un proyecto
class _AssignedMaterial {
  final String materialId;
  final String materialName;
  final String unit;
  final double requiredQty;
  final double reservedQty;
  final double deductedQty;
  final double purchasedQty;
  final bool isReserved;

  _AssignedMaterial({
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.requiredQty,
    required this.reservedQty,
    required this.deductedQty,
    required this.purchasedQty,
    required this.isReserved,
  });

  bool get isConsumed => deductedQty > 0;
  String get statusLabel =>
      isConsumed ? 'Consumido' : isReserved ? 'Apartado' : 'Pendiente';
  Color get statusColor => isConsumed
      ? const Color(0xFF059669)
      : isReserved
          ? const Color(0xFFD97706)
          : const Color(0xFF94A3B8);
}

/// Modelo ligero: un proyecto con sus materiales asignados
class _ProjectAllocation {
  final String processId;
  final String title;
  final String client;
  final ProcessStage stage;
  final String stageName;
  final Color stageColor;
  final Color stageTextColor;
  final IconData stageIcon;
  final DateTime updatedAt;
  final List<_AssignedMaterial> materials;

  _ProjectAllocation({
    required this.processId,
    required this.title,
    required this.client,
    required this.stage,
    required this.stageName,
    required this.stageColor,
    required this.stageTextColor,
    required this.stageIcon,
    required this.updatedAt,
    required this.materials,
  });

  int get totalMaterials => materials.length;
  int get reservedCount => materials.where((m) => m.isReserved).length;
  int get consumedCount => materials.where((m) => m.isConsumed).length;
  int get pendingCount =>
      materials.where((m) => !m.isReserved && !m.isConsumed).length;
}

class MaterialAssignmentsView extends StatefulWidget {
  const MaterialAssignmentsView({super.key});

  @override
  State<MaterialAssignmentsView> createState() =>
      _MaterialAssignmentsViewState();
}

class _MaterialAssignmentsViewState extends State<MaterialAssignmentsView> {
  final ProcessService _processService = ProcessService();

  bool _isLoading = true;
  List<_ProjectAllocation> _projects = [];

  // Filtros
  String _stageFilter = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Expandidos
  final Set<String> _expandedIds = {};

  // Colores
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _reservedColor = Color(0xFFD97706);
  static const Color _consumedColor = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final processes = await _processService.getProcessesOnce();
      final result = <_ProjectAllocation>[];

      for (final process in processes) {
        if (process.logisticsData == null) continue;
        final items = process.logisticsData!['items'] as List? ?? [];
        if (items.isEmpty) continue;

        final materials = <_AssignedMaterial>[];

        for (final rawItem in items) {
          if (rawItem is! Map) continue;
          final map = Map<String, dynamic>.from(rawItem);
          final name = (map['materialName'] ?? '').toString();
          final requiredQty = (map['requiredQty'] ?? 0).toDouble();
          if (name.isEmpty && requiredQty <= 0) continue;

          materials.add(_AssignedMaterial(
            materialId: map['materialId'] ?? '',
            materialName: name,
            unit: map['unit'] ?? '',
            requiredQty: requiredQty,
            reservedQty: (map['reservedStockQty'] ?? 0).toDouble(),
            deductedQty: (map['deductedStockQty'] ?? 0).toDouble(),
            purchasedQty: (map['purchasedQty'] ?? 0).toDouble(),
            isReserved: map['isStockReserved'] ?? false,
          ));
        }

        if (materials.isEmpty) continue;

        // ★ SINCRONIZAR con validación de E4 si existe
        final validationData = process.materialValidationData;
        if (validationData != null && validationData['isValidated'] == true) {
          final rawValidated = (validationData['items'] as List? ?? []);
          for (final rawV in rawValidated) {
            final vMap = Map<String, dynamic>.from(rawV);
            final vId = vMap['materialId'] ?? '';
            final vName = (vMap['materialName'] ?? '').toString().toLowerCase();
            final vQty = (vMap['validatedQty'] ?? 0).toDouble();
            final vRemoved = vMap['isRemoved'] ?? false;

            for (final mat in materials) {
              if (mat.materialId == vId || mat.materialName.toLowerCase() == vName) {
                // Actualizar requiredQty con el reflejo de un campo mutable
                // Como _AssignedMaterial es inmutable, reconstruimos
                final idx = materials.indexOf(mat);
                if (vRemoved) {
                  materials.removeAt(idx);
                } else if ((vQty - mat.requiredQty).abs() > 0.001) {
                  materials[idx] = _AssignedMaterial(
                    materialId: mat.materialId,
                    materialName: mat.materialName,
                    unit: mat.unit,
                    requiredQty: vQty,
                    reservedQty: mat.reservedQty,
                    deductedQty: mat.deductedQty,
                    purchasedQty: mat.purchasedQty,
                    isReserved: mat.isReserved,
                  );
                }
                break;
              }
            }
          }
        }

        if (materials.isEmpty) continue;

        final cfg = stageConfigs[process.stage];
        result.add(_ProjectAllocation(
          processId: process.id,
          title: process.title,
          client: process.client,
          stage: process.stage,
          stageName: cfg?.title ?? process.stage.name,
          stageColor: cfg?.color ?? const Color(0xFFF1F5F9),
          stageTextColor: cfg?.textColor ?? const Color(0xFF64748B),
          stageIcon: cfg?.icon ?? LucideIcons.circle,
          updatedAt: process.updatedAt,
          materials: materials,
        ));
      }

      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (mounted) {
        setState(() {
          _projects = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando asignaciones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_ProjectAllocation> get _filtered {
    return _projects.where((p) {
      // Filtro por etapa
      if (_stageFilter == 'E5' && p.stage != ProcessStage.E5) return false;
      if (_stageFilter == 'E6' && p.stage != ProcessStage.E6) return false;
      if (_stageFilter == 'E7+' &&
          p.stage != ProcessStage.E7 &&
          p.stage != ProcessStage.E8) return false;

      // Búsqueda
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchProject = p.processId.toLowerCase().contains(q) ||
            p.title.toLowerCase().contains(q) ||
            p.client.toLowerCase().contains(q);
        final matchMaterial =
            p.materials.any((m) => m.materialName.toLowerCase().contains(q));
        return matchProject || matchMaterial;
      }
      return true;
    }).toList();
  }

  // Conteos globales para los filtros
  Map<String, int> get _counts {
    return {
      'Todos': _projects.length,
      'E5': _projects.where((p) => p.stage == ProcessStage.E5).length,
      'E6': _projects.where((p) => p.stage == ProcessStage.E6).length,
      'E7+': _projects
          .where(
              (p) => p.stage == ProcessStage.E7 || p.stage == ProcessStage.E8)
          .length,
    };
  }

  // Resumen global
  int get _totalMaterials =>
      _projects.fold(0, (s, p) => s + p.totalMaterials);
  int get _totalReserved =>
      _projects.fold(0, (s, p) => s + p.reservedCount);
  int get _totalConsumed =>
      _projects.fold(0, (s, p) => s + p.consumedCount);

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _expandAll() => setState(() {
        _expandedIds.addAll(_filtered.map((p) => p.processId));
      });
  void _collapseAll() => setState(() => _expandedIds.clear());

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Resumen global ──────────────────────────
        _buildGlobalSummary(),
        const SizedBox(height: 20),

        // ── Búsqueda + Filtros ──────────────────────
        _buildSearchAndFilters(),
        const SizedBox(height: 16),

        // ── Controles expandir/colapsar ─────────────
        Row(
          children: [
            Text(
              filtered.length == _projects.length
                  ? "${_projects.length} proyecto${_projects.length == 1 ? '' : 's'} con materiales"
                  : "${filtered.length} de ${_projects.length} proyecto${_projects.length == 1 ? '' : 's'}",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary),
            ),
            const Spacer(),
            _buildSmallAction("Expandir todo", LucideIcons.chevronsDown,
                _expandAll),
            const SizedBox(width: 8),
            _buildSmallAction("Colapsar todo", LucideIcons.chevronsUp,
                _collapseAll),
            const SizedBox(width: 8),
            _buildSmallAction(
                "Recargar", LucideIcons.refreshCw, () {
              setState(() => _isLoading = true);
              _loadData();
            }),
          ],
        ),
        const SizedBox(height: 16),

        // ── Lista de proyectos ──────────────────────
        if (filtered.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildProjectCard(filtered[i]),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _buildGlobalSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.layoutDashboard,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Resumen de Asignaciones",
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    "${_projects.length} proyectos activos con materiales",
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildSummaryPill("$_totalMaterials", "Total", Colors.white),
          const SizedBox(width: 8),
          _buildSummaryPill(
              "$_totalReserved", "Apartados", const Color(0xFFFBBF24)),
          const SizedBox(width: 8),
          _buildSummaryPill(
              "$_totalConsumed", "Consumidos", const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 1),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.7),
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final filters = ['Todos', 'E5', 'E6', 'E7+'];
    final filterLabels = {
      'Todos': 'Todos',
      'E5': 'Logística',
      'E6': 'Ejecución',
      'E7+': 'Reporte',
    };
    final filterColors = {
      'Todos': _primaryBlue,
      'E5': const Color(0xFFD97706),
      'E6': const Color(0xFFC2410C),
      'E7+': const Color(0xFF16A34A),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
            decoration: InputDecoration(
              hintText:
                  "Buscar por proyecto, cliente o material...",
              hintStyle: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(LucideIcons.search,
                  size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x,
                          size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: _primaryBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isActive = _stageFilter == f;
                final color = filterColors[f]!;
                final count = _counts[f] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _stageFilter = f),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? color.withOpacity(0.4)
                              : _borderColor,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (f != 'Todos') ...[
                            Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                          ],
                          Text(filterLabels[f]!,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? color
                                      : _textSecondary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? color.withOpacity(0.15)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("$count",
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? color
                                        : _textSecondary)),
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

  Widget _buildSmallAction(
      String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── CARD DE PROYECTO (expandible) ─────────────────────────
  Widget _buildProjectCard(_ProjectAllocation project) {
    final isExpanded = _expandedIds.contains(project.processId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isExpanded
                ? _primaryBlue.withOpacity(0.3)
                : _borderColor),
        boxShadow: [
          BoxShadow(
              color: isExpanded
                  ? _primaryBlue.withOpacity(0.06)
                  : Colors.black.withOpacity(0.02),
              blurRadius: isExpanded ? 16 : 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Header del proyecto ──
          InkWell(
            onTap: () => _toggleExpand(project.processId),
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // ID
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(project.processId,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      // Badge etapa
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: project.stageColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(project.stageIcon,
                                size: 10,
                                color: project.stageTextColor),
                            const SizedBox(width: 4),
                            Text(project.stageName,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: project.stageTextColor)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Contadores rápidos
                      _buildMiniCount(project.totalMaterials.toString(),
                          LucideIcons.package, _primaryBlue),
                      const SizedBox(width: 6),
                      if (project.reservedCount > 0) ...[
                        _buildMiniCount(project.reservedCount.toString(),
                            LucideIcons.lock, _reservedColor),
                        const SizedBox(width: 6),
                      ],
                      if (project.consumedCount > 0)
                        _buildMiniCount(
                            project.consumedCount.toString(),
                            LucideIcons.packageCheck,
                            _consumedColor),
                      const SizedBox(width: 10),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(LucideIcons.chevronDown,
                            size: 16, color: _textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.title,
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(project.client,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yy')
                            .format(project.updatedAt),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Tabla de materiales (expandible) ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild:
                _buildMaterialsTable(project.materials, project),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCount(String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildMaterialsTable(
      List<_AssignedMaterial> materials, _ProjectAllocation project) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
        border:
            const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Cabecera de la tabla
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('MATERIAL',
                        style: _colHeaderStyle())),
                Expanded(
                    flex: 2,
                    child: Text('REQUERIDO',
                        textAlign: TextAlign.center,
                        style: _colHeaderStyle())),
                Expanded(
                    flex: 2,
                    child: Text('APARTADO',
                        textAlign: TextAlign.center,
                        style: _colHeaderStyle())),
                Expanded(
                    flex: 2,
                    child: Text('CONSUMIDO',
                        textAlign: TextAlign.center,
                        style: _colHeaderStyle())),
                Expanded(
                    flex: 2,
                    child: Text('ESTADO',
                        textAlign: TextAlign.center,
                        style: _colHeaderStyle())),
              ],
            ),
          ),
          // Filas
          ...materials.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final isLast = i == materials.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: i.isOdd
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
                borderRadius: isLast
                    ? const BorderRadius.vertical(
                        bottom: Radius.circular(16))
                    : null,
                border: isLast
                    ? null
                    : const Border(
                        bottom:
                            BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  // Nombre + Unidad
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.materialName,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (m.unit.isNotEmpty)
                          Text(m.unit,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  // Requerido
                  Expanded(
                    flex: 2,
                    child: Text(
                      _fmtQty(m.requiredQty),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary),
                    ),
                  ),
                  // Apartado
                  Expanded(
                    flex: 2,
                    child: Text(
                      m.reservedQty > 0
                          ? _fmtQty(m.reservedQty)
                          : '—',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: m.reservedQty > 0
                              ? _reservedColor
                              : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  // Consumido
                  Expanded(
                    flex: 2,
                    child: Text(
                      m.deductedQty > 0
                          ? _fmtQty(m.deductedQty)
                          : '—',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: m.deductedQty > 0
                              ? _consumedColor
                              : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  // Estado
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: m.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  m.statusColor.withOpacity(0.25)),
                        ),
                        child: Text(
                          m.statusLabel,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: m.statusColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? LucideIcons.searchX
                  : LucideIcons.inbox,
              size: 44,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Sin resultados para "$_searchQuery"'
                  : "No hay proyectos con materiales asignados",
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8)),
            ),
            if (_searchQuery.isNotEmpty || _stageFilter != 'Todos') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _searchQuery = '';
                    _stageFilter = 'Todos';
                  });
                },
                icon: Icon(LucideIcons.rotateCcw,
                    size: 14, color: _primaryBlue),
                label: Text("Limpiar filtros",
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _primaryBlue,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _colHeaderStyle() => GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _textSecondary,
      letterSpacing: 0.6);
}