import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/tool_model.dart';
import '../../services/tool_service.dart';

class ToolCatalogScreen extends StatefulWidget {
  final UserModel currentUser;
  const ToolCatalogScreen({super.key, required this.currentUser});

  @override
  State<ToolCatalogScreen> createState() => _ToolCatalogScreenState();
}

class _ToolCatalogScreenState extends State<ToolCatalogScreen> {
  final ToolService _toolService = ToolService();

  late Stream<List<ToolItem>> _toolsStream;

  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _selectedStatus = 'Disponible';
  String _filterStatus = 'Todos';
  String _searchQuery = '';
  bool _isUploading = false;

  final List<String> _statusOptions = [
    'Disponible',
    'En Uso',
    'Mantenimiento',
    'Extraviada'
  ];

  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFFF59E0B);

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_tools');

  @override
  void initState() {
    super.initState();
    _toolsStream = _toolService.getTools();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _serialCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disponible': return const Color(0xFF10B981);
      case 'En Uso': return const Color(0xFF3B82F6);
      case 'Mantenimiento': return const Color(0xFFF59E0B);
      case 'Extraviada': return const Color(0xFFEF4444);
      default: return _textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Disponible': return LucideIcons.checkCircle2;
      case 'En Uso': return LucideIcons.activity;
      case 'Mantenimiento': return LucideIcons.wrench;
      case 'Extraviada': return LucideIcons.alertTriangle;
      default: return LucideIcons.circle;
    }
  }

  List<ToolItem> _applyFilters(List<ToolItem> tools) {
    return tools.where((tool) {
      final matchesStatus = _filterStatus == 'Todos' || tool.status == _filterStatus;
      if (!matchesStatus) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return tool.name.toLowerCase().contains(q) ||
            tool.brand.toLowerCase().contains(q) ||
            tool.serialNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Map<String, int> _countByStatus(List<ToolItem> tools) {
    final counts = <String, int>{'Todos': tools.length};
    for (var s in _statusOptions) {
      counts[s] = tools.where((t) => t.status == s).length;
    }
    return counts;
  }

  Future<void> _quickUpdateStatus(ToolItem item, String newStatus) async {
    if (item.status == newStatus) return;
    try {
      final updatedTool = ToolItem(
        id: item.id,
        name: item.name,
        brand: item.brand,
        serialNumber: item.serialNumber,
        status: newStatus,
      );
      await _toolService.updateTool(updatedTool);
      _showSnack("Estado actualizado a: $newStatus");
    } catch (e) {
      _showSnack("Error al actualizar estado", isSuccess: false);
    }
  }

  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    if (_nameCtrl.text.isEmpty || _brandCtrl.text.isEmpty) {
      _showSnack("Nombre y Marca son obligatorios", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final tool = ToolItem(
        id: docId ?? '',
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim(),
        status: _selectedStatus,
      );

      if (docId == null) {
        await _toolService.addTool(tool);
        _resetForm();
        _showSnack("Herramienta registrada correctamente");
      } else {
        await _toolService.updateTool(tool);
        if (mounted) Navigator.pop(context);
        _showSnack("Herramienta actualizada");
      }
    } catch (e) {
      _showSnack("Error al guardar: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _brandCtrl.clear();
    _serialCtrl.clear();
    setState(() => _selectedStatus = 'Disponible');
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
              StreamBuilder<List<ToolItem>>(
                stream: _toolsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allTools = snapshot.data ?? [];
                  final filtered = _applyFilters(allTools);
                  final counts = _countByStatus(allTools);

                  final listSection = Column(
                    children: [
                      _buildSearchAndFilters(counts),
                      const SizedBox(height: 20),
                      _buildListResults(filtered, allTools.length),
                    ],
                  );

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: listSection),
                        const SizedBox(width: 40),
                        if (canEdit) Expanded(flex: 4, child: _buildForm()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        if (canEdit) ...[_buildForm(), const SizedBox(height: 40)],
                        listSection,
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

  // ── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.wrench, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Inventario de Herramientas", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
            Text("Control de equipo, estado y asignaciones.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
          ],
        ),
      ],
    );
  }

  // ── BÚSQUEDA + FILTROS ───────────────────────────────────────────────────

  Widget _buildSearchAndFilters(Map<String, int> counts) {
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
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
            decoration: InputDecoration(
              hintText: "Buscar por nombre, marca o serie...",
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
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

          // Filtros por estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Todos', ..._statusOptions].map((status) {
                final isActive = _filterStatus == status;
                final count = counts[status] ?? 0;
                final color = status == 'Todos' ? _primaryBlue : _getStatusColor(status);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _filterStatus = status),
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
                          if (status != 'Todos') ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? color : _textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? color.withOpacity(0.15) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$count",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive ? color : _textSecondary,
                              ),
                            ),
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

  // ── RESULTADOS DE LA LISTA ───────────────────────────────────────────────

  Widget _buildListResults(List<ToolItem> filtered, int totalCount) {
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
                _searchQuery.isNotEmpty ? LucideIcons.searchX : LucideIcons.packageX,
                size: 44,
                color: const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty
                    ? "Sin resultados para \"$_searchQuery\""
                    : _filterStatus != 'Todos'
                        ? "Sin herramientas en estado \"$_filterStatus\""
                        : "Sin herramientas registradas",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
              ),
              if (_searchQuery.isNotEmpty || _filterStatus != 'Todos') ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _filterStatus = 'Todos';
                    });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contador de resultados
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            filtered.length == totalCount
                ? "$totalCount herramienta${totalCount == 1 ? '' : 's'}"
                : "${filtered.length} de $totalCount herramienta${totalCount == 1 ? '' : 's'}",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _buildCard(filtered[index]),
        ),
      ],
    );
  }

  // ── TARJETA ──────────────────────────────────────────────────────────────

  Widget _buildCard(ToolItem item) {
    Color statusColor = _getStatusColor(item.status);

    Widget statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(item.status.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
          if (canEdit) ...[
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 12, color: statusColor),
          ],
        ],
      ),
    );

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.hammer, color: _accentColor, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(
                  "${item.brand}  •  Serie: ${item.serialNumber.isEmpty ? 'S/N' : item.serialNumber}",
                  style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                ),
                const SizedBox(height: 12),
                if (canEdit)
                  PopupMenuButton<String>(
                    tooltip: "Cambiar estado rápidamente",
                    offset: const Offset(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    initialValue: item.status,
                    onSelected: (newStatus) => _quickUpdateStatus(item, newStatus),
                    itemBuilder: (context) => _statusOptions.map((status) {
                      Color c = _getStatusColor(status);
                      return PopupMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            Icon(_getStatusIcon(status), size: 14, color: c),
                            const SizedBox(width: 10),
                            Text(status, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: c)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: statusBadge,
                  )
                else
                  statusBadge,
              ],
            ),
          ),
          if (canEdit)
            Row(
              children: [
                IconButton(icon: const Icon(LucideIcons.edit3, size: 20, color: Colors.blue), onPressed: () => _showEditDialog(item)),
                IconButton(icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red), onPressed: () => _confirmDelete(item)),
              ],
            ),
        ],
      ),
    );
  }

  // ── FORMULARIO ───────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(LucideIcons.plus, color: _primaryBlue, size: 20)),
              const SizedBox(width: 12),
              Text("Alta de Herramienta", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          _input(_nameCtrl, "Nombre de la Herramienta", LucideIcons.wrench),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _input(_brandCtrl, "Marca", LucideIcons.tag)),
              const SizedBox(width: 12),
              Expanded(child: _input(_serialCtrl, "No. Serie", LucideIcons.hash)),
            ],
          ),
          const SizedBox(height: 24),
          Text("ESTADO ACTUAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: _getStatusColor(status), shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(status, style: GoogleFonts.inter(fontSize: 14, color: _textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val!),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : () => _handleSave(docId: null),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                  : Text("Guardar Herramienta", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS ──────────────────────────────────────────────────────────────

  void _showEditDialog(ToolItem item) {
    _nameCtrl.text = item.name;
    _brandCtrl.text = item.brand;
    _serialCtrl.text = item.serialNumber;
    String tempStatus = item.status;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                          decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                          child: const Center(child: Icon(LucideIcons.hammer, color: Colors.white, size: 24)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Editar Herramienta", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
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
                          Text("NOMBRE DE LA HERRAMIENTA", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(_nameCtrl, "Ej. Taladro Percutor", LucideIcons.wrench),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text("MARCA", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                                  const SizedBox(height: 8),
                                  _input(_brandCtrl, "Ej. DeWalt", LucideIcons.tag),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text("NO. SERIE", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                                  const SizedBox(height: 8),
                                  _input(_serialCtrl, "Ej. SN-12345", LucideIcons.hash),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text("ESTADO ACTUAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: tempStatus,
                                isExpanded: true,
                                icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
                                items: _statusOptions.map((status) {
                                  return DropdownMenuItem(value: status, child: Row(children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _getStatusColor(status), shape: BoxShape.circle)),
                                    const SizedBox(width: 10),
                                    Text(status, style: GoogleFonts.inter(fontSize: 14, color: _textPrimary)),
                                  ]));
                                }).toList(),
                                onChanged: (val) { setModalState(() => tempStatus = val!); _selectedStatus = val!; },
                              ),
                            ),
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
                            onPressed: _isUploading ? null : () { _selectedStatus = tempStatus; _handleSave(docId: item.id); },
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

  void _confirmDelete(ToolItem item) {
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
                          Text("Eliminar Herramienta", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
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
                            decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(LucideIcons.hammer, size: 16, color: _accentColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text("${item.brand} · Serie: ${item.serialNumber.isEmpty ? 'S/N' : item.serialNumber}", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            child: Text("La herramienta será dada de baja permanentemente del catálogo de inventario.", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500, height: 1.4)),
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
                          _toolService.deleteTool(item.id);
                          Navigator.pop(ctx);
                          _showSnack("Herramienta dada de baja");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text("Eliminar Herramienta", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}