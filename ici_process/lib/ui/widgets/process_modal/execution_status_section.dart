import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/services/worker_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../models/process_model.dart';
import '../../../services/tool_service.dart';
import '../../pdf/work_order_pdf_generator.dart';

class ExecutionStatusSection extends StatefulWidget {
  final ProcessModel process;
  final Map<String, dynamic>? logisticsData;
  final bool isEditable;
  final Function(DateTime?)? onCompletionDateChanged;

  const ExecutionStatusSection({
    super.key,
    required this.process,
    this.logisticsData,
    this.isEditable = false,
    this.onCompletionDateChanged,
  });

  @override
  State<ExecutionStatusSection> createState() => _ExecutionStatusSectionState();
}

class _ExecutionStatusSectionState extends State<ExecutionStatusSection> {
  final ToolService _toolService = ToolService();
  final _dateFmt = DateFormat('dd MMM, yyyy', 'es');

  bool _isLoadingPdf = false;
  DateTime? _realCompletionDate;
  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _technicianNames = [];
  List<String> _toolIds = [];

  @override
  void initState() {
    super.initState();
    _loadExecutionData();
  }

  void _loadExecutionData() {
    final planning = widget.logisticsData?['executionPlanning'];
    if (planning == null) return;

    _startDate = planning['startDate'] != null
        ? DateTime.tryParse(planning['startDate'])
        : null;
    _endDate = planning['endDate'] != null
        ? DateTime.tryParse(planning['endDate'])
        : null;
    _technicianNames = List<String>.from(planning['technicianNames'] ?? []);
    _toolIds = List<String>.from(planning['toolIds'] ?? []);

    // Cargar fecha de término si ya fue guardada
    final savedDate = widget.logisticsData?['realCompletionDate'];
    if (savedDate != null && savedDate is String && savedDate.isNotEmpty) {
      _realCompletionDate = DateTime.tryParse(savedDate);
    }
  }

  String _getExecutionStatus() {
    if (_startDate == null || _endDate == null) return 'Sin Programar';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    if (_realCompletionDate != null) return 'Finalizado';
    if (today.isBefore(start)) return 'Programado';
    if (today.isAfter(end)) return 'Vencido';
    return 'En Curso';
  }

  Color _getStatusColor() {
    switch (_getExecutionStatus()) {
      case 'Finalizado': return const Color(0xFF059669);
      case 'En Curso': return const Color(0xFF2563EB);
      case 'Programado': return const Color(0xFFF59E0B);
      case 'Vencido': return const Color(0xFFDC2626);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon() {
    switch (_getExecutionStatus()) {
      case 'Finalizado': return LucideIcons.checkCircle2;
      case 'En Curso': return LucideIcons.play;
      case 'Programado': return LucideIcons.clock;
      case 'Vencido': return LucideIcons.alertTriangle;
      default: return LucideIcons.helpCircle;
    }
  }

  int get _daysRemaining {
    if (_endDate == null) return 0;
    return _endDate!.difference(DateTime.now()).inDays;
  }

  Future<void> _pickCompletionDate() async {
    final now = DateTime.now();
    final earliest = _startDate ?? DateTime(2020);
    // initialDate no puede ser antes de firstDate
    final initial = _realCompletionDate ?? (now.isBefore(earliest) ? earliest : now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: DateTime(2030),
      helpText: "SELECCIONA FECHA REAL DE TÉRMINO",
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF059669),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
          datePickerTheme: const DatePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            headerBackgroundColor: Color(0xFFECFDF5),
            headerForegroundColor: Color(0xFF059669),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _realCompletionDate = picked);
      widget.onCompletionDateChanged?.call(picked);
    }
  }

  Future<void> _clearCompletionDate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.calendarX2, color: Color(0xFFEA580C), size: 18),
            ),
            const SizedBox(width: 12),
            Text("¿Quitar fecha de término?", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Text(
          "El proceso volverá a mostrarse como en curso o pendiente.",
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text("Quitar Fecha", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _realCompletionDate = null);
      widget.onCompletionDateChanged?.call(null);
    }
  }

  Future<void> _generateWorkOrderPdf() async {
    setState(() => _isLoadingPdf = true);

    try {
      List<String> toolNames = [];
      if (_toolIds.isNotEmpty) {
        final tools = await _toolService.getTools().first;
        for (final id in _toolIds) {
          try {
            final tool = tools.firstWhere((t) => t.id == id);
            toolNames.add("${tool.name} (${tool.brand})");
          } catch (_) {
            toolNames.add("Herramienta ID: $id");
          }
        }
      }

      final workerService = WorkerService();
      final allWorkers = await workerService.getWorkers().first;

      final List<Map<String, String>> technicians = _technicianNames.map((name) {
        try {
          final worker = allWorkers.firstWhere(
            (w) => w.name.trim().toLowerCase() == name.trim().toLowerCase(),
          );
          return {
            'name': worker.name,
            'nss': worker.nss,
            'bloodType': worker.bloodType,
            'emergencyPhone': worker.emergencyPhone,
          };
        } catch (_) {
          return {'name': name, 'nss': '', 'bloodType': '', 'emergencyPhone': ''};
        }
      }).toList();

      List<Map<String, String>> materials = [];
      final items = widget.logisticsData?['items'] as List? ?? [];
      for (final rawItem in items) {
        final map = Map<String, dynamic>.from(rawItem);
        materials.add({
          'name': map['materialName'] ?? '',
          'qty': _fmtQty((map['requiredQty'] ?? 0).toDouble()),
          'unit': map['unit'] ?? '',
        });
      }

      await WorkOrderPdfGenerator.generateAndPrint(
        projectTitle: widget.process.title,
        clientName: widget.process.client,
        description: widget.process.description,
        priority: widget.process.priority,
        startDate: _startDate,
        endDate: _endDate,
        realCompletionDate: _realCompletionDate,
        technicians: technicians,
        toolNames: toolNames,
        materials: materials,
        notes: widget.logisticsData?['notes'] ?? '',
        folio: 'OT-${widget.process.id.substring(widget.process.id.length > 6 ? widget.process.id.length - 6 : 0)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al generar PDF: $e"),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getExecutionStatus();
    final statusColor = _getStatusColor();

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
          _buildHeader(status, statusColor),
          const SizedBox(height: 24),
          _buildDatesRow(statusColor),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),
          _buildPersonnelSection(),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),
          _buildCompletionSection(),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),
          _buildPdfButton(),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: _isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFC2410C).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(LucideIcons.hardHat, color: Color(0xFFC2410C), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Estatus de Ejecución", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFC2410C)))),
                  ],
                ),
                const SizedBox(height: 10),
                _buildStatusBadge(status, statusColor),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFC2410C).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.hardHat, color: Color(0xFFC2410C), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text("Estatus de Ejecución", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFC2410C)))),
                _buildStatusBadge(status, statusColor),
              ],
            ),
    );
  }

  Widget _buildStatusBadge(String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
        ],
      ),
    );
  }

  // ── FECHAS ────────────────────────────────────────────────
  Widget _buildDatesRow(Color statusColor) {
    final startCard = _buildDateCard(label: "INICIO PROGRAMADO", date: _startDate, icon: LucideIcons.calendarCheck, accentColor: const Color(0xFF2563EB));
    final endCard = _buildDateCard(label: "FIN PROGRAMADO", date: _endDate, icon: LucideIcons.calendarClock, accentColor: const Color(0xFFC2410C));

    final daysCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.timer, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _realCompletionDate != null ? "COMPLETADO" : "DÍAS RESTANTES",
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor.withOpacity(0.7), letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _realCompletionDate != null
                ? "Terminado"
                : _endDate != null
                    ? "${_daysRemaining >= 0 ? _daysRemaining : 'Vencido ${-_daysRemaining}'} días"
                    : "—",
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: statusColor),
          ),
        ],
      ),
    );

    if (_isMobile) {
      return Column(children: [
        Row(children: [Expanded(child: startCard), const SizedBox(width: 12), Expanded(child: endCard)]),
        const SizedBox(height: 12),
        daysCard,
      ]);
    }

    return Row(children: [
      Expanded(child: startCard), const SizedBox(width: 16),
      Expanded(child: endCard), const SizedBox(width: 16),
      Expanded(child: daysCard),
    ]);
  }

  Widget _buildDateCard({required String label, required DateTime? date, required IconData icon, required Color accentColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Text(date != null ? _dateFmt.format(date) : "Sin asignar", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: date != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
      ]),
    );
  }

  // ── PERSONAL ──────────────────────────────────────────────
  Widget _buildPersonnelSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFC2410C).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.users, size: 16, color: Color(0xFFC2410C))),
        const SizedBox(width: 10),
        Text("PERSONAL EN SITIO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFC2410C), letterSpacing: 0.6)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFC2410C), borderRadius: BorderRadius.circular(10)), child: Text("${_technicianNames.length}", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
      ]),
      const SizedBox(height: 12),
      if (_technicianNames.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: [
            const Icon(LucideIcons.userX, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Text("Sin personal asignado en la planificación", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
          ]),
        )
      else
        Wrap(
          spacing: 10, runSpacing: 8,
          children: _technicianNames.map((name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFFC2410C).withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFC2410C)))),
              const SizedBox(width: 10),
              Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            ]),
          )).toList(),
        ),
    ]);
  }

  // ── FECHA REAL DE TÉRMINO (SELECCIONABLE) ─────────────────
  Widget _buildCompletionSection() {
    final isCompleted = _realCompletionDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF059669).withOpacity(0.1) : const Color(0xFF64748B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(isCompleted ? LucideIcons.checkCircle2 : LucideIcons.clock, size: 16, color: isCompleted ? const Color(0xFF059669) : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text("FECHA REAL DE TÉRMINO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isCompleted ? const Color(0xFF059669) : const Color(0xFF64748B), letterSpacing: 0.6), overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Si ya tiene fecha ─────────────────────────────
        if (isCompleted)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: _isMobile ? _buildCompletedMobile() : _buildCompletedDesktop(),
          )

        // ── Si NO tiene fecha ─────────────────────────────
        else
          widget.isEditable
              ? InkWell(
                  onTap: _pickCompletionDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.calendarPlus, size: 18, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Registrar fecha de término", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                              const SizedBox(height: 2),
                              Text("Toca para seleccionar la fecha real en que finalizó el servicio", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(children: [
                    const Icon(LucideIcons.info, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 12),
                    Expanded(child: Text("La fecha de término será registrada en la etapa de Ejecución.", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4))),
                  ]),
                ),
      ],
    );
  }

  Widget _buildCompletedDesktop() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: const Icon(LucideIcons.calendarCheck, size: 20, color: Color(0xFF059669)),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_dateFmt.format(_realCompletionDate!), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
          const SizedBox(height: 4),
          Text("Servicio finalizado", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF065F46), fontWeight: FontWeight.w500)),
        ]),
      ),
      if (_startDate != null) _buildDaysBadge(),
      if (widget.isEditable) ...[
        const SizedBox(width: 10),
        _buildDateActions(),
      ],
    ]);
  }

  Widget _buildCompletedMobile() {
    return Column(children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(LucideIcons.calendarCheck, size: 20, color: Color(0xFF059669)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_dateFmt.format(_realCompletionDate!), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
            const SizedBox(height: 2),
            Text("Servicio finalizado", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF065F46), fontWeight: FontWeight.w500)),
          ]),
        ),
        if (_startDate != null) _buildDaysBadge(),
      ]),
      if (widget.isEditable) ...[
        const SizedBox(height: 12),
        _buildDateActions(),
      ],
    ]);
  }

  Widget _buildDateActions() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Tooltip(
        message: "Cambiar fecha",
        child: InkWell(
          onTap: _pickCompletionDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: const Icon(LucideIcons.pencil, size: 14, color: Color(0xFF059669)),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Tooltip(
        message: "Quitar fecha",
        child: InkWell(
          onTap: _clearCompletionDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Icon(LucideIcons.x, size: 14, color: Color(0xFFDC2626)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDaysBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6EE7B7))),
      child: Column(children: [
        Text("${_realCompletionDate!.difference(_startDate!).inDays + 1}", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
        Text("días", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
      ]),
    );
  }

  // ── BOTÓN PDF ─────────────────────────────────────────────
  Widget _buildPdfButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoadingPdf ? null : _generateWorkOrderPdf,
        icon: _isLoadingPdf
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(LucideIcons.printer, size: 18),
        label: Text(
          _isLoadingPdf ? "Generando..." : _isMobile ? "Orden de Trabajo (PDF)" : "Imprimir Orden de Trabajo (PDF)",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: _isMobile ? 13 : 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  static String _fmtQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
}