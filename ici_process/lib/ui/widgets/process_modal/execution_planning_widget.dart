import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/process_model.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../services/user_service.dart';
import '../../../services/tool_service.dart';

class ExecutionPlanningWidget extends StatefulWidget {
  final ProcessModel process;
  final double quotedDays;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onChanged;
  final bool isEditable;

  const ExecutionPlanningWidget({
    super.key,
    required this.process,
    required this.quotedDays,
    this.initialData,
    required this.onChanged,
    required this.isEditable,
  });

  @override
  State<ExecutionPlanningWidget> createState() => _ExecutionPlanningWidgetState();
}

class _ExecutionPlanningWidgetState extends State<ExecutionPlanningWidget> {
  final UserService _userService = UserService();
  final ToolService _toolService = ToolService(); 
  final EventService _eventService = EventService();

  DateTime? _startDate;
  DateTime? _endDate;
  Color _selectedColor = const Color(0xFF2563EB); // Azul principal
  final TextEditingController _justificationCtrl = TextEditingController();
  
  Set<String> _selectedTechIds = {};
  Map<String, String> _techNames = {};
  Set<String> _selectedToolIds = {};

  String? _scheduledEventId;
  bool _isScheduling = false;

  final List<Color> _colorPalette = [
    const Color(0xFF2563EB), const Color(0xFF7C3AED), const Color(0xFF059669),
    const Color(0xFFEA580C), const Color(0xFF0891B2), const Color(0xFF475569),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.initialData == null) return;
    
    final data = widget.initialData!;
    _startDate = data['startDate'] != null ? DateTime.parse(data['startDate']) : null;
    _endDate = data['endDate'] != null ? DateTime.parse(data['endDate']) : null;
    _justificationCtrl.text = data['justification'] ?? '';
    _selectedColor = Color(data['colorValue'] ?? 0xFF2563EB);
    _scheduledEventId = data['eventId'];
    
    _selectedTechIds = Set<String>.from(data['technicianIds'] ?? []);
    final names = List<String>.from(data['technicianNames'] ?? []);
    
    int i = 0;
    for (var id in _selectedTechIds) {
      if (i < names.length) _techNames[id] = names[i];
      i++;
    }
    _selectedToolIds = Set<String>.from(data['toolIds'] ?? []);
  }

  @override
  void dispose() {
    _justificationCtrl.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  bool get _exceedsQuotedDays => _calculatedDays > widget.quotedDays;

  void _notifyData() {
    widget.onChanged({
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'justification': _justificationCtrl.text,
      'colorValue': _selectedColor.value,
      'technicianIds': _selectedTechIds.toList(),
      'technicianNames': _selectedTechIds.map((id) => _techNames[id] ?? '').toList(),
      'toolIds': _selectedToolIds.toList(),
      'eventId': _scheduledEventId,
      'calculatedDays': _calculatedDays,
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? LucideIcons.alertOctagon : LucideIcons.checkCircle2, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        elevation: 4,
      ),
    );
  }

  Future<void> _scheduleEvent() async {
    if (_startDate == null || _endDate == null) {
      _showSnackBar("Por favor, selecciona las fechas del proyecto", isError: true);
      return;
    }
    if (_exceedsQuotedDays && _justificationCtrl.text.trim().isEmpty) {
      _showSnackBar("Se requiere una justificación por exceder los días cotizados", isError: true);
      return;
    }

    setState(() => _isScheduling = true);

    try {
      final event = CalendarEvent(
        id: _scheduledEventId ?? '',
        title: "Ejecución: ${widget.process.title}",
        type: EventType.trabajoExtendido,
        clientName: widget.process.client,
        startDate: _startDate!,
        endDate: _endDate!,
        colorValue: _selectedColor.value,
        technicianIds: _selectedTechIds.toList(),
        technicianNames: _selectedTechIds.map((id) => _techNames[id] ?? '').toList(),
        createdBy: "Logística",
        createdAt: DateTime.now(),
      );

      if (_scheduledEventId != null && _scheduledEventId!.isNotEmpty) {
        await _eventService.updateEvent(event);
        _showSnackBar("Evento sincronizado en el calendario");
      } else {
        final docRef = FirebaseFirestore.instance.collection('calendar_events').doc();
        final newEvent = CalendarEvent(
          id: docRef.id,
          title: event.title,
          type: event.type,
          clientName: event.clientName,
          startDate: event.startDate,
          endDate: event.endDate,
          colorValue: event.colorValue,
          technicianIds: event.technicianIds,
          technicianNames: event.technicianNames,
          createdBy: event.createdBy,
          createdAt: event.createdAt,
        );
        await docRef.set(newEvent.toMap());
        _scheduledEventId = docRef.id; 
        _showSnackBar("Evento agendado exitosamente");
      }
      _notifyData(); 
    } catch (e) {
      _showSnackBar("Hubo un error al procesar la solicitud", isError: true);
    } finally {
      if (mounted) setState(() => _isScheduling = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart 
        ? (_startDate ?? DateTime.now()) 
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2030),
      helpText: isStart ? "SELECCIONA FECHA DE INICIO" : "SELECCIONA FECHA DE FIN",
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: _selectedColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF1E293B),
          ),
          datePickerTheme: const DatePickerThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            headerBackgroundColor: Color(0xFFF8FAFC),
            headerForegroundColor: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!)) _startDate = picked;
      }
    });
    _notifyData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Se quitó la sombra pesada para que no compita con el padre
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // El header visualmente separador
            _buildHeader(),
            Padding(
              // Padding reducido de 28 a 20
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDatesSection(),
                  _buildJustificationSection(),
                  const SizedBox(height: 20),
                  _buildResourcesSection(),
                  const SizedBox(height: 24),
                  _buildFooterActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SECCIONES MODULARES ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      // Padding reducido
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.layoutList, color: _selectedColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            "Detalles de Agendamiento",
            // Tamaño igualado al de LogisticsSection
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("CRONOGRAMA", style: _labelStyle()),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildDateCard("Inicio", _startDate, () => _pickDate(true))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(LucideIcons.arrowRight, size: 16, color: Color(0xFFCBD5E1)),
                  ),
                  Expanded(child: _buildDateCard("Fin", _endDate, () => _pickDate(false))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: _buildDaysSummaryCard(),
        ),
      ],
    );
  }

  Widget _buildJustificationSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      child: _exceedsQuotedDays
          ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.shieldAlert, color: Color(0xFFE11D48), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Justificación por exceso de días",
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFBE123C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _justificationCtrl,
                      enabled: widget.isEditable,
                      onChanged: (_) => _notifyData(),
                      maxLines: 2,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4C0519)),
                      decoration: InputDecoration(
                        hintText: "Ej. Retraso por clima...",
                        hintStyle: TextStyle(color: const Color(0xFFE11D48).withOpacity(0.4)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFECDD3))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFECDD3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildResourcesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildResourceContainer(
            title: "EQUIPO TÉCNICO",
            icon: LucideIcons.users,
            stream: _userService.getUsersStream(),
            builder: (data) {
              final techs = data.where((u) => u.role == UserRole.technician).toList();
              return _buildSelectableList(
                items: techs,
                emptyIcon: LucideIcons.userX,
                emptyMessage: "No hay técnicos",
                itemBuilder: (tech) => _buildModernTile(
                  title: tech.name,
                  subtitle: "Técnico",
                  icon: LucideIcons.userCheck,
                  isSelected: _selectedTechIds.contains(tech.id),
                  onTap: () {
                    if (!widget.isEditable) return;
                    setState(() {
                      if (_selectedTechIds.contains(tech.id)) {
                        _selectedTechIds.remove(tech.id);
                        _techNames.remove(tech.id);
                      } else {
                        _selectedTechIds.add(tech.id);
                        _techNames[tech.id] = tech.name;
                      }
                    });
                    _notifyData();
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildResourceContainer(
            title: "HERRAMIENTAS",
            icon: LucideIcons.wrench,
            stream: _toolService.getTools(),
            builder: (tools) {
              return _buildSelectableList(
                items: tools,
                emptyIcon: LucideIcons.box,
                emptyMessage: "Inventario vacío",
                itemBuilder: (tool) => _buildModernTile(
                  title: tool.name,
                  subtitle: tool.brand,
                  icon: LucideIcons.hammer, 
                  isSelected: _selectedToolIds.contains(tool.id),
                  onTap: () {
                    if (!widget.isEditable) return;
                    setState(() {
                      _selectedToolIds.contains(tool.id) 
                          ? _selectedToolIds.remove(tool.id) 
                          : _selectedToolIds.add(tool.id);
                    });
                    _notifyData();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ETIQUETA", style: _labelStyle()),
            const SizedBox(height: 10),
            Row(
              children: _colorPalette.map((color) => GestureDetector(
                onTap: widget.isEditable ? () {
                  setState(() => _selectedColor = color);
                  _notifyData();
                } : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.only(right: 12),
                  // Círculos de color ligeramente más pequeños
                  width: _selectedColor == color ? 28 : 22,
                  height: _selectedColor == color ? 28 : 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: _selectedColor == color ? 2 : 1),
                    boxShadow: [
                      if (_selectedColor == color)
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 3))
                      else
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1))
                    ],
                  ),
                  child: _selectedColor == color 
                      ? const Icon(LucideIcons.check, size: 12, color: Colors.white) 
                      : null,
                ),
              )).toList(),
            ),
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 44, // Botón más delgado para no verse tosco
          child: ElevatedButton.icon(
            onPressed: widget.isEditable && !_isScheduling ? _scheduleEvent : null,
            icon: _isScheduling 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(_scheduledEventId != null ? LucideIcons.refreshCw : LucideIcons.calendarPlus, size: 18),
            label: Text(
              _scheduledEventId != null ? "Sincronizar" : "Guardar Evento", 
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2)
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedColor,
              foregroundColor: Colors.white,
              elevation: _isScheduling ? 0 : 2,
              shadowColor: _selectedColor.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── WIDGETS DE APOYO (UI COMPONENTS) ─────────────────────────────────────

  Widget _buildDateCard(String label, DateTime? date, VoidCallback onTap) {
    final hasDate = date != null;
    return InkWell(
      onTap: widget.isEditable ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasDate ? _selectedColor.withOpacity(0.3) : const Color(0xFFE2E8F0), width: hasDate ? 1.2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(LucideIcons.calendar, size: 16, color: hasDate ? _selectedColor : const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(
                  hasDate ? DateFormat('dd MMM, yy').format(date) : "Seleccionar",
                  style: GoogleFonts.inter(
                    fontSize: 13, 
                    fontWeight: hasDate ? FontWeight.bold : FontWeight.w500, 
                    color: hasDate ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSummaryCard() {
    double progress = 0.0;
    if (widget.quotedDays > 0) {
      progress = (_calculatedDays / widget.quotedDays).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(16), // Padding reducido
      decoration: BoxDecoration(
        color: _exceedsQuotedDays ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _exceedsQuotedDays ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DÍAS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5)),
              if (_exceedsQuotedDays)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(4)),
                  child: Text("Excedido", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$_calculatedDays", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _exceedsQuotedDays ? const Color(0xFFBE123C) : const Color(0xFF0F172A))), // Número más pequeño
              Text(" / ${widget.quotedDays.toInt()} cotizados", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(_exceedsQuotedDays ? const Color(0xFFE11D48) : _selectedColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceContainer<T>({required String title, required IconData icon, required Stream<List<T>> stream, required Widget Function(List<T>) builder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF475569)),
            const SizedBox(width: 8),
            Text(title, style: _labelStyle()),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 170, // Altura reducida (antes 220) para que no ocupe media pantalla
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: StreamBuilder<List<T>>(
            stream: stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snap.hasError) {
                return Center(child: Text("Error al cargar", style: GoogleFonts.inter(color: Colors.red)));
              }
              return builder(snap.data ?? []);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableList<T>({required List<T> items, required IconData emptyIcon, required String emptyMessage, required Widget Function(T) itemBuilder}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 32, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Text(emptyMessage, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: itemBuilder(items[i]),
      ),
    );
  }

  Widget _buildModernTile({required String title, required String subtitle, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Padding interno más compacto
        decoration: BoxDecoration(
          color: isSelected ? _selectedColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? _selectedColor.withOpacity(0.5) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? _selectedColor : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF0F172A))), // Fuente reducida
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, color: _selectedColor, size: 18)
            else
              const Icon(LucideIcons.circle, color: Color(0xFFCBD5E1), size: 18),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: const Color(0xFF64748B));
} 