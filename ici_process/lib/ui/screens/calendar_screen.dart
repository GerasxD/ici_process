import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/process_model.dart';
import '../../services/process_service.dart';
import '../../core/constants/app_constants.dart';

class CalendarScreen extends StatefulWidget {
  final UserModel currentUser;

  const CalendarScreen({super.key, required this.currentUser});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  bool _sidebarVisible = true;
  final ProcessService _processService = ProcessService();

  static const double _cellMinHeight = 88.0;

  void _previousMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
        _selectedDay = null;
      });

  void _nextMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
        _selectedDay = null;
      });

  void _goToday() => setState(() {
        _focusedMonth = DateTime.now();
        _selectedDay = DateTime.now();
      });

  List<DateTime?> _buildCalendarDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    int startOffset = firstDay.weekday - 1;
    int totalCells = startOffset + lastDay.day;
    int remainder = totalCells % 7;
    if (remainder != 0) totalCells += 7 - remainder;

    return List.generate(totalCells, (i) {
      final dayIndex = i - startOffset + 1;
      if (dayIndex < 1 || dayIndex > lastDay.day) return null;
      return DateTime(_focusedMonth.year, _focusedMonth.month, dayIndex);
    });
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime? d) {
    if (d == null || _selectedDay == null) return false;
    return d.year == _selectedDay!.year &&
        d.month == _selectedDay!.month &&
        d.day == _selectedDay!.day;
  }

  List<ProcessModel> _processesForDay(DateTime day, List<ProcessModel> all) {
    return all.where((p) {
      return p.updatedAt.year == day.year &&
          p.updatedAt.month == day.month &&
          p.updatedAt.day == day.day;
    }).toList();
  }

  Color _stageColor(ProcessStage stage) =>
      stageConfigs[stage]?.textColor ?? const Color(0xFF64748B);

  Color _stageBg(ProcessStage stage) =>
      stageConfigs[stage]?.color ?? const Color(0xFFF1F5F9);

  String _stageLabel(ProcessStage stage) =>
      stageConfigs[stage]?.title ?? stage.name;

  List<ProcessModel> _selectedDayProcesses(List<ProcessModel> all) {
    if (_selectedDay == null) return [];
    return _processesForDay(_selectedDay!, all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<ProcessModel>>(
        stream: _processService.getProcessesStream(),
        builder: (context, snapshot) {
          final allProcesses = snapshot.data ?? [];
          final calDays = _buildCalendarDays();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Columna principal ──────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildCalendarCard(calDays, allProcesses),
                    ],
                  ),
                ),
              ),

              // ── Sidebar colapsable con animación ───────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                width: _sidebarVisible ? 320 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: 320,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              left: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: _buildSidePanel(allProcesses),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(LucideIcons.calendarDays,
              color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Calendario de Proyectos",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                "Visualiza la actividad del equipo por fecha.",
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        // Botón Hoy
        _buildPillButton(
          label: "Hoy",
          icon: LucideIcons.locate,
          onTap: _goToday,
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(width: 8),
        // Toggle sidebar
        Tooltip(
          message: _sidebarVisible ? "Ocultar panel" : "Mostrar panel",
          child: InkWell(
            onTap: () => setState(() => _sidebarVisible = !_sidebarVisible),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _sidebarVisible
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _sidebarVisible
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                _sidebarVisible
                    ? LucideIcons.panelRightClose
                    : LucideIcons.panelRightOpen,
                size: 17,
                color:
                    _sidebarVisible ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── CALENDARIO ────────────────────────────────────────────
  Widget _buildCalendarCard(
      List<DateTime?> days, List<ProcessModel> allProcesses) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _buildMonthNavigation(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildWeekdayRow(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildDaysGrid(days, allProcesses),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    final monthName = DateFormat('MMMM', 'es').format(_focusedMonth);
    final capitalized = monthName[0].toUpperCase() + monthName.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "$capitalized ",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: _focusedMonth.year.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildNavArrow(LucideIcons.chevronLeft, _previousMonth),
          const SizedBox(width: 8),
          _buildNavArrow(LucideIcons.chevronRight, _nextMonth),
        ],
      ),
    );
  }

  Widget _buildNavArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF8FAFC),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF475569)),
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: days.map((d) {
          final isWeekend = d == 'Sáb' || d == 'Dom';
          return Expanded(
            child: Center(
              child: Text(
                d,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isWeekend
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── GRID ─────────────────────────────────────────────────
  // Usamos IntrinsicHeight por fila para que todas las celdas de
  // una semana tengan la misma altura (determinada por la celda más alta).
  Widget _buildDaysGrid(
      List<DateTime?> days, List<ProcessModel> allProcesses) {
    final int weeks = days.length ~/ 7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        children: List.generate(weeks, (weekIndex) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(7, (dayIndex) {
                final cellIndex = weekIndex * 7 + dayIndex;
                final day = cellIndex < days.length ? days[cellIndex] : null;
                final processes = day != null
                    ? _processesForDay(day, allProcesses)
                    : <ProcessModel>[];

                return Expanded(
                  child: _buildDayCell(day, dayIndex, processes),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  // ── CELDA ─────────────────────────────────────────────────
  Widget _buildDayCell(
      DateTime? day, int weekdayIndex, List<ProcessModel> processes) {
    final today = _isToday(day);
    final selected = _isSelected(day);
    final isWeekend = weekdayIndex >= 5;
    final isEmpty = day == null;
    final hasProcesses = processes.isNotEmpty;

    return GestureDetector(
      onTap: day != null ? () => setState(() => _selectedDay = day) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // minHeight garantiza que días sin actividad tengan la misma altura mínima
        constraints: BoxConstraints(minHeight: _cellMinHeight),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isEmpty
              ? Colors.transparent
              : selected
                  ? const Color(0xFF2563EB)
                  : today
                      ? const Color(0xFFEFF6FF)
                      : isWeekend
                          ? const Color(0xFFFAFAFC)
                          : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isEmpty
              ? null
              : Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : today
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFE2E8F0),
                  width: selected || today ? 1.5 : 1,
                ),
        ),
        child: isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Número del día
                    // Número del día
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4, // Esto reemplaza al SizedBox(width: 4)
                      runSpacing: 4, // Espacio vertical si hace salto de línea
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withOpacity(0.2)
                                : today
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              "${day.day}",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: today || selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : today
                                        ? Colors.white
                                        : isWeekend
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                        // Quitamos el spread operator (...) y el SizedBox porque el Wrap ya maneja el spacing
                        if (hasProcesses)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withOpacity(0.25)
                                  : const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${processes.length}",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Procesos (solo si los hay → no agrega espacio vacío)
                    if (hasProcesses) ...[
                      const SizedBox(height: 4),
                      ...processes
                          .take(3)
                          .map((p) => _buildProcessDot(p, selected)),
                      if (processes.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "+${processes.length - 3} más",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: selected
                                  ? Colors.white70
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProcessDot(ProcessModel p, bool onSelected) {
    final color = _stageColor(p.stage);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: onSelected ? Colors.white.withOpacity(0.8) : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: onSelected
                    ? Colors.white.withOpacity(0.9)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PANEL LATERAL ─────────────────────────────────────────
  Widget _buildSidePanel(List<ProcessModel> allProcesses) {
    final selected = _selectedDay;
    final processes = _selectedDayProcesses(allProcesses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 12, 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected != null
                          ? DateFormat("EEEE, d 'de' MMMM", 'es')
                              .format(selected)
                          : "Selecciona un día",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        "${processes.length} actividad${processes.length != 1 ? 'es' : ''}",
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              // X desde el panel
              Tooltip(
                message: "Ocultar panel",
                child: InkWell(
                  onTap: () => setState(() => _sidebarVisible = false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.x,
                        size: 15, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: selected == null
              ? _buildEmptySideState()
              : processes.isEmpty
                  ? _buildNothingState(selected)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: processes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _buildSidePanelCard(processes[i]),
                    ),
        ),
        _buildStageLegend(),
      ],
    );
  }

  Widget _buildSidePanelCard(ProcessModel p) {
    final color = _stageColor(p.stage);
    final bg = _stageBg(p.stage);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              _stageLabel(p.stage),
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.building2,
                  size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPriorityChip(p.priority),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(p.updatedAt),
                style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'urgente':
        color = const Color(0xFFDC2626);
        break;
      case 'alta':
        color = const Color(0xFFEA580C);
        break;
      case 'media':
        color = const Color(0xFFF59E0B);
        break;
      default:
        color = const Color(0xFF10B981);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(priority,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildStageLegend() {
    final stages = [
      ProcessStage.E1,
      ProcessStage.E2,
      ProcessStage.E4,
      ProcessStage.E5,
      ProcessStage.E6,
      ProcessStage.E8,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ETAPAS",
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: stages.map((s) {
              final color = _stageColor(s);
              final cfg = stageConfigs[s]!;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: cfg.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(s.name,
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySideState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.calendarSearch,
              size: 44, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text("Toca un día",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text("para ver sus actividades",
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildNothingState(DateTime day) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.calendarX2,
              size: 44, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text("Sin actividad",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text("el ${DateFormat('d MMMM', 'es').format(day)}",
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}