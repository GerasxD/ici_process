import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/ui/widgets/calendar/event_detail_dialog.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/process_model.dart';
import '../../models/event_model.dart';
import '../../services/process_service.dart';
import '../../services/event_service.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/calendar/event_form_dialog.dart';

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
  final EventService _eventService = EventService();

  static const double _cellMinHeight = 90.0;

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

  List<CalendarEvent> _eventsForDay(DateTime day, List<CalendarEvent> all) {
    return all.where((e) => e.coversDay(day)).toList();
  }

  Color _stageColor(ProcessStage stage) =>
      stageConfigs[stage]?.textColor ?? const Color(0xFF64748B);

  Color _stageBg(ProcessStage stage) =>
      stageConfigs[stage]?.color ?? const Color(0xFFF1F5F9);

  String _stageLabel(ProcessStage stage) =>
      stageConfigs[stage]?.title ?? stage.name;

  void _openCreateEvent([DateTime? date]) async {
    await showDialog(
      context: context,
      builder: (_) => EventFormDialog(
        currentUser: widget.currentUser,
        initialDate: date ?? _selectedDay ?? DateTime.now(),
      ),
    );
  }

  void _openEventDetail(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (_) => EventDetailDialog(
        event: event,
        onEdit: () => _openEditEvent(event),
      ),
    );
  }

  void _openEditEvent(CalendarEvent event) async {
    await showDialog(
      context: context,
      builder: (_) => EventFormDialog(
        currentUser: widget.currentUser,
        eventToEdit: event,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateEvent(),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 2,
        icon: const Icon(LucideIcons.calendarPlus, color: Colors.white, size: 20),
        label: Text("Nuevo Evento",
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<ProcessModel>>(
        stream: _processService.getProcessesStream(),
        builder: (context, procSnap) {
          final allProcesses = procSnap.data ?? [];
          return StreamBuilder<List<CalendarEvent>>(
            stream: _eventService.getEventsStream(),
            builder: (context, evSnap) {
              final allEvents = evSnap.data ?? [];
              final calDays = _buildCalendarDays();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 28),
                          _buildCalendarCard(calDays, allProcesses, allEvents),
                        ],
                      ),
                    ),
                  ),
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
                              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: _buildSidePanel(allProcesses, allEvents),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

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
          child: const Icon(LucideIcons.calendarDays, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Calendario de Proyectos",
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5)),
              Text("Visualiza la actividad del equipo por fecha.",
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            ],
          ),
        ),
        _buildPillButton(
          label: "Hoy",
          icon: LucideIcons.locate,
          onTap: _goToday,
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _sidebarVisible ? "Ocultar panel" : "Mostrar panel",
          child: InkWell(
            onTap: () => setState(() => _sidebarVisible = !_sidebarVisible),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _sidebarVisible ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _sidebarVisible
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                _sidebarVisible ? LucideIcons.panelRightClose : LucideIcons.panelRightOpen,
                size: 17,
                color: _sidebarVisible ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard(List<DateTime?> days,
      List<ProcessModel> allProcesses, List<CalendarEvent> allEvents) {
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
          _buildDaysGrid(days, allProcesses, allEvents),
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
            text: TextSpan(children: [
              TextSpan(
                  text: "$capitalized ",
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5)),
              TextSpan(
                  text: _focusedMonth.year.toString(),
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: -0.5)),
            ]),
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
              child: Text(d,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isWeekend
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF64748B),
                      letterSpacing: 0.5)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDaysGrid(List<DateTime?> days, List<ProcessModel> allProcesses,
      List<CalendarEvent> allEvents) {
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
                final events =
                    day != null ? _eventsForDay(day, allEvents) : <CalendarEvent>[];
                return Expanded(
                  child: _buildDayCell(day, dayIndex, processes, events),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  // ── CELDA ─────────────────────────────────────────────────
  // CAMBIO 1: La celda seleccionada ya NO se rellena de azul.
  // Ahora usa un borde azul más grueso + fondo muy sutil,
  // manteniendo el texto y chips con su color original.
  Widget _buildDayCell(DateTime? day, int weekdayIndex,
      List<ProcessModel> processes, List<CalendarEvent> events) {
    final today = _isToday(day);
    final selected = _isSelected(day);
    final isWeekend = weekdayIndex >= 5;
    final isEmpty = day == null;
    final hasContent = processes.isNotEmpty || events.isNotEmpty;
    final totalCount = processes.length + events.length;

    // ── Colores de celda según estado (sin azul sólido en selected) ──
    Color cellBg() {
      if (isEmpty) return Colors.transparent;
      if (today) return const Color(0xFFEFF6FF);
      if (selected) return const Color(0xFFF0F7FF); // azul muy suave
      if (isWeekend) return const Color(0xFFFAFAFC);
      return Colors.white;
    }

    Color borderColor() {
      if (isEmpty) return Colors.transparent;
      if (selected) return const Color(0xFF2563EB);
      if (today) return const Color(0xFF93C5FD);
      return const Color(0xFFE2E8F0);
    }

    double borderWidth() => selected ? 2.0 : (today ? 1.5 : 1.0);

    return GestureDetector(
      onTap: day != null ? () => setState(() => _selectedDay = day) : null,
      onDoubleTap: day != null ? () => _openCreateEvent(day) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(minHeight: _cellMinHeight),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cellBg(),
          borderRadius: BorderRadius.circular(12),
          border: isEmpty
              ? null
              : Border.all(color: borderColor(), width: borderWidth()),
        ),
        child: isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Número + badge ──
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            // Hoy: círculo azul. Seleccionado: círculo azul outline. Normal: transparente.
                            color: today
                                ? const Color(0xFF2563EB)
                                : selected
                                    ? const Color(0xFF2563EB).withOpacity(0.08)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: selected && !today
                                ? Border.all(
                                    color: const Color(0xFF2563EB), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              "${day.day}",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: today || selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                // El número nunca se vuelve blanco porque el fondo ya no es azul sólido
                                color: today
                                    ? Colors.white
                                    : selected
                                        ? const Color(0xFF2563EB)
                                        : isWeekend
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                        if (hasContent) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "$totalCount",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (hasContent) ...[
                      const SizedBox(height: 5),
                      // CAMBIO 2: chips más grandes y visibles
                      ...events.take(2).map((e) => _buildEventChip(e)),
                      ...processes
                          .take(3 - events.take(2).length)
                          .map((p) => _buildProcessDot(p)),
                      if (totalCount > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            "+${totalCount - 3} más",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF94A3B8),
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

  // ── CHIP DE EVENTO ────────────────────────────────────────
  // CAMBIO 2: padding mayor, texto más grande, borde izquierdo de color,
  // fondo más opaco → más fácil de tocar y leer.
  Widget _buildEventChip(CalendarEvent e) {
    return GestureDetector(
      onTap: () => _openEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: e.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: e.color, width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: e.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DOT DE PROCESO ────────────────────────────────────────
  // También ligeramente más grande para consistencia
  Widget _buildProcessDot(ProcessModel p) {
    final color = _stageColor(p.stage);
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SIDE PANEL ────────────────────────────────────────────
  Widget _buildSidePanel(
      List<ProcessModel> allProcesses, List<CalendarEvent> allEvents) {
    final selected = _selectedDay;
    final processes = selected != null
        ? _processesForDay(selected, allProcesses)
        : <ProcessModel>[];
    final events =
        selected != null ? _eventsForDay(selected, allEvents) : <CalendarEvent>[];
    final totalCount = processes.length + events.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
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
                          ? DateFormat("EEEE, d 'de' MMMM", 'es').format(selected)
                          : "Selecciona un día",
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A)),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        "$totalCount actividad${totalCount != 1 ? 'es' : ''}",
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected != null)
                Tooltip(
                  message: "Agendar evento en este día",
                  child: InkWell(
                    onTap: () => _openCreateEvent(selected),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.calendarPlus,
                          size: 16, color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
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
              : (processes.isEmpty && events.isEmpty)
                  ? _buildNothingState(selected)
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        if (events.isNotEmpty) ...[
                          _buildSideSectionLabel("EVENTOS", LucideIcons.star),
                          const SizedBox(height: 8),
                          ...events.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildEventCard(e),
                              )),
                          if (processes.isNotEmpty) const SizedBox(height: 8),
                        ],
                        if (processes.isNotEmpty) ...[
                          _buildSideSectionLabel(
                              "PROCESOS", LucideIcons.folderKanban),
                          const SizedBox(height: 8),
                          ...processes.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildProcessCard(p),
                              )),
                        ],
                      ],
                    ),
        ),
        _buildStageLegend(),
      ],
    );
  }

  Widget _buildSideSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent e) {
    return InkWell(
      onTap: () => _openEventDetail(e),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: e.color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: e.color.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: e.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: e.color.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.type.icon, size: 11, color: e.color),
                      const SizedBox(width: 5),
                      Text(e.type.label,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: e.color)),
                    ],
                  ),
                ),
                const Spacer(),
                if (!_isSameDay(e.startDate, e.endDate))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${DateFormat('d').format(e.startDate)}-${DateFormat('d MMM', 'es').format(e.endDate)}",
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.building2,
                    size: 11, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(e.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B))),
                ),
              ],
            ),
            if (e.technicianNames.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.users,
                      size: 11, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(e.technicianNames.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF64748B))),
                  ),
                ],
              ),
            ],
            if (e.vehicleModel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.truck,
                      size: 11, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(e.vehicleModel!,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildProcessCard(ProcessModel p) {
    final color = _stageColor(p.stage);
    final bg = _stageBg(p.stage);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(_stageLabel(p.stage),
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 6),
          Text(p.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.building2,
                  size: 11, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(p.client,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF64748B))),
              ),
              _buildPriorityChip(p.priority),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
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
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ETAPAS DE PROCESO",
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: stages.map((s) {
              final color = _stageColor(s);
              final cfg = stageConfigs[s]!;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: cfg.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
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
          Icon(LucideIcons.calendarSearch, size: 44, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text("Toca un día",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
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
          Icon(LucideIcons.calendarX2, size: 44, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text("Sin actividad",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text("el ${DateFormat('d MMMM', 'es').format(day)}",
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFFCBD5E1))),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _openCreateEvent(day),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.plus,
                      size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text("Agendar evento",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB))),
                ],
              ),
            ),
          ),
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