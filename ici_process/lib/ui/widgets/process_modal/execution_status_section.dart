import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../models/process_model.dart';
import '../../../services/tool_service.dart';
import '../../../services/event_service.dart';
import '../../pdf/work_order_pdf_generator.dart';

class ExecutionStatusSection extends StatefulWidget {
  final ProcessModel process;
  final Map<String, dynamic>? logisticsData;

  const ExecutionStatusSection({
    super.key,
    required this.process,
    this.logisticsData,
  });

  @override
  State<ExecutionStatusSection> createState() => _ExecutionStatusSectionState();
}

class _ExecutionStatusSectionState extends State<ExecutionStatusSection> {
  final ToolService _toolService = ToolService();
  final EventService _eventService = EventService();
  final _dateFmt = DateFormat('dd MMM, yyyy', 'es');

  bool _isLoadingPdf = false;
  DateTime? _realCompletionDate;
  bool _isCheckingEvent = true;

  // Datos extraídos del executionPlanning
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _technicianNames = [];
  List<String> _toolIds = [];
  String? _eventId;

  @override
  void initState() {
    super.initState();
    _loadExecutionData();
  }

  void _loadExecutionData() {
    final planning = widget.logisticsData?['executionPlanning'];
    if (planning == null) {
      setState(() => _isCheckingEvent = false);
      return;
    }

    _startDate = planning['startDate'] != null
        ? DateTime.tryParse(planning['startDate'])
        : null;
    _endDate = planning['endDate'] != null
        ? DateTime.tryParse(planning['endDate'])
        : null;
    _technicianNames = List<String>.from(planning['technicianNames'] ?? []);
    _toolIds = List<String>.from(planning['toolIds'] ?? []);
    _eventId = planning['eventId'];

    // Verificar si el evento ya fue finalizado para obtener la fecha real
    _checkEventFinalization();
  }

  Future<void> _checkEventFinalization() async {
    if (_eventId == null || _eventId!.isEmpty) {
      setState(() => _isCheckingEvent = false);
      return;
    }

    try {
      final events = await _eventService.getEventsStream().first;
      final matchingEvent = events.where((e) => e.id == _eventId).toList();

      if (matchingEvent.isNotEmpty) {
        // Verificar en Firestore si tiene campo finalizedAt
        final doc = await _eventService.getEventDoc(_eventId!);
        if (doc != null && doc['isFinalized'] == true && doc['finalizedAt'] != null) {
          _realCompletionDate = (doc['finalizedAt'] as dynamic).toDate();
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isCheckingEvent = false);
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
      case 'Finalizado':
        return const Color(0xFF059669);
      case 'En Curso':
        return const Color(0xFF2563EB);
      case 'Programado':
        return const Color(0xFFF59E0B);
      case 'Vencido':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon() {
    switch (_getExecutionStatus()) {
      case 'Finalizado':
        return LucideIcons.checkCircle2;
      case 'En Curso':
        return LucideIcons.play;
      case 'Programado':
        return LucideIcons.clock;
      case 'Vencido':
        return LucideIcons.alertTriangle;
      default:
        return LucideIcons.helpCircle;
    }
  }

  int get _daysRemaining {
    if (_endDate == null) return 0;
    final now = DateTime.now();
    return _endDate!.difference(now).inDays;
  }

  Future<void> _generateWorkOrderPdf() async {
    setState(() => _isLoadingPdf = true);

    try {
      // Obtener nombres de herramientas desde la BD
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

      // Obtener lista de materiales del logisticsData
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
        technicianNames: _technicianNames,
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
    if (_isCheckingEvent) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFC2410C)),
        ),
      );
    }

    final status = _getExecutionStatus();
    final statusColor = _getStatusColor();

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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────
          _buildHeader(status, statusColor),

          const SizedBox(height: 24),

          // ── Fechas programadas ───────────────────────────
          _buildDatesRow(statusColor),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── Personal en sitio ───────────────────────────
          _buildPersonnelSection(),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── Fecha real de término ───────────────────────
          _buildCompletionSection(),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          // ── Botón PDF ──────────────────────────────────
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFC2410C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.hardHat, color: Color(0xFFC2410C), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Estatus de Ejecución",
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFC2410C),
              ),
            ),
          ),
          // Badge de estatus
          Container(
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
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FECHAS ────────────────────────────────────────────────
  Widget _buildDatesRow(Color statusColor) {
    return Row(
      children: [
        Expanded(
          child: _buildDateCard(
            label: "INICIO PROGRAMADO",
            date: _startDate,
            icon: LucideIcons.calendarCheck,
            accentColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateCard(
            label: "FIN PROGRAMADO",
            date: _endDate,
            icon: LucideIcons.calendarClock,
            accentColor: const Color(0xFFC2410C),
          ),
        ),
        const SizedBox(width: 16),
        // Días restantes o finalizados
        Expanded(
          child: Container(
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
                    Text(
                      _realCompletionDate != null ? "COMPLETADO" : "DÍAS RESTANTES",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor.withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _realCompletionDate != null
                      ? "Terminado"
                      : _endDate != null
                          ? "${_daysRemaining >= 0 ? _daysRemaining : 'Vencido ${-_daysRemaining}'} ${_daysRemaining >= 0 ? 'días' : 'días'}"
                          : "—",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color accentColor,
  }) {
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
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date != null ? _dateFmt.format(date) : "Sin asignar",
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: date != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ── PERSONAL ──────────────────────────────────────────────
  Widget _buildPersonnelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFC2410C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.users, size: 16, color: Color(0xFFC2410C)),
            ),
            const SizedBox(width: 10),
            Text(
              "PERSONAL EN SITIO",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFC2410C),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFC2410C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_technicianNames.length}",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_technicianNames.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.userX, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 10),
                Text(
                  "Sin personal asignado en la planificación",
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _technicianNames.map((name) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFC2410C).withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'T',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFC2410C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ── FECHA REAL DE TÉRMINO ─────────────────────────────────
  Widget _buildCompletionSection() {
    final isCompleted = _realCompletionDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF059669).withOpacity(0.1)
                    : const Color(0xFF64748B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted ? LucideIcons.checkCircle2 : LucideIcons.clock,
                size: 16,
                color: isCompleted ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "FECHA REAL DE TÉRMINO",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCompleted ? const Color(0xFF059669) : const Color(0xFF64748B),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
            ),
          ),
          child: isCompleted
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.calendarCheck, size: 20, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateFmt.format(_realCompletionDate!),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Servicio finalizado desde el calendario",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF065F46),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Días que tomó
                    if (_startDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${_realCompletionDate!.difference(_startDate!).inDays + 1}",
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF059669),
                              ),
                            ),
                            Text(
                              "días",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(LucideIcons.info, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "La fecha de término se registrará automáticamente al finalizar el servicio desde el Calendario.",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ── BOTÓN PDF ─────────────────────────────────────────────
  Widget _buildPdfButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoadingPdf ? null : _generateWorkOrderPdf,
        icon: _isLoadingPdf
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(LucideIcons.printer, size: 18),
        label: Text(
          _isLoadingPdf ? "Generando..." : "Imprimir Orden de Trabajo (PDF)",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
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