import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:ici_process/models/user_model.dart';
import 'package:ici_process/ui/pdf/tools_checkout_pdf_generator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/process_model.dart';
import '../../../models/event_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/event_service.dart';
import '../../../services/user_service.dart';
import '../../../services/tool_service.dart';
import '../../../services/vehicle_service.dart';

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
  State<ExecutionPlanningWidget> createState() =>
      _ExecutionPlanningWidgetState();
}

class _ExecutionPlanningWidgetState extends State<ExecutionPlanningWidget> {
  final UserService _userService = UserService();
  final ToolService _toolService = ToolService();
  final EventService _eventService = EventService();
  final VehicleService _vehicleService = VehicleService();

  DateTime? _startDate;
  DateTime? _endDate;
  Color _selectedColor = const Color(0xFF2563EB); // Azul principal
  final TextEditingController _justificationCtrl = TextEditingController();

  final TextEditingController _toolSearchCtrl = TextEditingController();
  String _toolSearchQuery = '';

  Set<String> _selectedTechIds = {};
  Map<String, String> _techNames = {};
  Set<String> _selectedToolIds = {};

  Set<String> _selectedVehicleIds = {};
  Map<String, String> _vehicleNames = {};

  String? _scheduledEventId;
  bool _isScheduling = false;

  final List<Color> _colorPalette = [
    const Color(0xFF2563EB),
    const Color(0xFF7C3AED),
    const Color(0xFF059669),
    const Color(0xFFEA580C),
    const Color(0xFF0891B2),
    const Color(0xFF475569),
  ];

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.initialData == null) return;

    final data = widget.initialData!;
    _startDate = data['startDate'] != null
        ? DateTime.parse(data['startDate'])
        : null;
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
    _selectedVehicleIds = Set<String>.from(data['vehicleIds'] ?? []);
    final vNames = List<String>.from(data['vehicleNames'] ?? []);
    int vi = 0;
    for (var id in _selectedVehicleIds) {
      if (vi < vNames.length) _vehicleNames[id] = vNames[vi];
      vi++;
    }
  }

  @override
  void dispose() {
    _justificationCtrl.dispose();
    _toolSearchCtrl.dispose();
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
      'technicianNames': _selectedTechIds
          .map((id) => _techNames[id] ?? '')
          .toList(),
      'toolIds': _selectedToolIds.toList(),
      'vehicleIds': _selectedVehicleIds.toList(),
      'vehicleNames': _selectedVehicleIds.map((id) => _vehicleNames[id] ?? '').toList(),
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
            Icon(
              isError ? LucideIcons.alertOctagon : LucideIcons.checkCircle2,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE11D48)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        elevation: 4,
      ),
    );
  }

  Future<void> _scheduleEvent() async {
    if (_startDate == null || _endDate == null) {
      _showSnackBar(
        "Por favor, selecciona las fechas del proyecto",
        isError: true,
      );
      return;
    }
    if (_exceedsQuotedDays && _justificationCtrl.text.trim().isEmpty) {
      _showSnackBar(
        "Se requiere una justificación por exceder los días cotizados",
        isError: true,
      );
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
        technicianNames: _selectedTechIds
            .map((id) => _techNames[id] ?? '')
            .toList(),
        vehicleIds: _selectedVehicleIds.toList(),
        vehicleModels: _selectedVehicleIds
            .map((id) => _vehicleNames[id] ?? '')
            .toList(),
        createdBy: "Logística",
        createdAt: DateTime.now(),
        // ── Heredar privacidad del proceso padre ──
        processId: widget.process.id,
        isPrivate: widget.process.isPrivate,
        visibleToUserIds: widget.process.visibleToUserIds,
      );

      if (_scheduledEventId != null && _scheduledEventId!.isNotEmpty) {
        await _eventService.updateEvent(event);
        _showSnackBar("Evento sincronizado en el calendario");
      } else {
        final docRef = FirebaseFirestore.instance
            .collection('calendar_events')
            .doc();
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
          vehicleIds: event.vehicleIds,         
          vehicleModels: event.vehicleModels,   
          createdBy: event.createdBy,
          createdAt: event.createdAt,
          // ── Heredar privacidad del proceso padre ──
          processId: widget.process.id,
          isPrivate: widget.process.isPrivate,
          visibleToUserIds: widget.process.visibleToUserIds,
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

  // ═══════════════════════════════════════════════════════════════
  //  DESCARGAR PDF DE HERRAMIENTAS ASIGNADAS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _downloadToolsPdf() async {
    // Validación mínima
    if (_selectedToolIds.isEmpty) {
      _showSnackBar(
        "No hay herramientas seleccionadas para descargar",
        isError: true,
      );
      return;
    }

    try {
      // 1) Obtener herramientas completas desde el stream (snapshot)
      final allTools = await _toolService.getTools().first;
      final selectedTools = allTools
          .where((t) => _selectedToolIds.contains(t.id))
          .toList();

      // 2) Convertir a formato que entiende el generador de PDF
      final toolsForPdf = selectedTools.map<Map<String, String>>((tool) {
        return {
          'name': tool.name,
          'brand': tool.brand,
          // Si la herramienta no tiene número de serie, usamos el ID como respaldo
          'serial': tool.serialNumber.isNotEmpty ? tool.serialNumber : tool.id,
        };
      }).toList();

      // 3) Responsable: quien creó el proceso o el usuario actual
      final responsibleName = widget.process.requestedBy.isNotEmpty
          ? widget.process.requestedBy
          : (widget.process.history.isNotEmpty
              ? widget.process.history.first.userName
              : 'Sin asignar');

      // 4) Técnicos asignados
      final technicianNames = _selectedTechIds
          .map((id) => _techNames[id] ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // 5) Generar y abrir PDF
      await ToolsCheckoutPdfGenerator.generateAndPrint(
        projectId: widget.process.id,
        projectTitle: widget.process.title,
        clientName: widget.process.client,
        responsibleName: responsibleName,
        technicianNames: technicianNames,
        tools: toolsForPdf,
        startDate: _startDate,
        endDate: _endDate,
      );

      _showSnackBar("PDF generado correctamente");
    } catch (e) {
      _showSnackBar("Error al generar el PDF: $e", isError: true);
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
      helpText: isStart
          ? "SELECCIONA FECHA DE INICIO"
          : "SELECCIONA FECHA DE FIN",
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: _selectedColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF1E293B),
          ),
          datePickerTheme: const DatePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
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
        if (_endDate != null && _endDate!.isBefore(_startDate!))
          _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!))
          _startDate = picked;
      }
    });
    _notifyData();
  }

  /// Revisa si un técnico tiene conflicto de fechas con los eventos existentes.
  /// Devuelve el nombre del cliente/proyecto que lo tiene ocupado, o null si está libre.
  String? _technicianConflict(String techId, List<CalendarEvent> allEvents) {
    if (_startDate == null || _endDate == null) return null;

    final rangeStart = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final rangeEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    // Evitar auto-conflicto con el evento actual de ejecución (si ya fue agendado)
    final currentEventId = _scheduledEventId;

    for (final ev in allEvents) {
      if (currentEventId != null && ev.id == currentEventId) continue;
      if (!ev.technicianIds.contains(techId)) continue;

      final evStart = DateTime(ev.startDate.year, ev.startDate.month, ev.startDate.day);
      final evEnd = DateTime(ev.endDate.year, ev.endDate.month, ev.endDate.day);

      final overlaps = evStart.compareTo(rangeEnd) <= 0 &&
          evEnd.compareTo(rangeStart) >= 0;
      if (overlaps) {
        return ev.clientName.isNotEmpty ? ev.clientName : ev.title;
      }
    }
    return null;
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
            child: Icon(
              LucideIcons.layoutList,
              color: _selectedColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Detalles de Agendamiento",
            // Tamaño igualado al de LogisticsSection
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection() {
    if (_isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CRONOGRAMA", style: _labelStyle()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateCard(
                  "Inicio",
                  _startDate,
                  () => _pickDate(true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  LucideIcons.arrowRight,
                  size: 16,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              Expanded(
                child: _buildDateCard("Fin", _endDate, () => _pickDate(false)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDaysSummaryCard(),
        ],
      );
    }

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
                  Expanded(
                    child: _buildDateCard(
                      "Inicio",
                      _startDate,
                      () => _pickDate(true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      LucideIcons.arrowRight,
                      size: 16,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  Expanded(
                    child: _buildDateCard(
                      "Fin",
                      _endDate,
                      () => _pickDate(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: _buildDaysSummaryCard()),
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
                        const Icon(
                          LucideIcons.shieldAlert,
                          color: Color(0xFFE11D48),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Justificación por exceso de días",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _justificationCtrl,
                      enabled: widget.isEditable,
                      onChanged: (_) => _notifyData(),
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF4C0519),
                      ),
                      decoration: InputDecoration(
                        hintText: "Ej. Retraso por clima...",
                        hintStyle: TextStyle(
                          color: const Color(0xFFE11D48).withOpacity(0.4),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFFECDD3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFFECDD3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE11D48),
                            width: 1.5,
                          ),
                        ),
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
    final techWidget = _buildResourceContainer(
      title: "EQUIPO TÉCNICO",
      icon: LucideIcons.users,
      stream: _userService.getUsersStream().map((users) {
        // Si el proceso es privado, filtrar solo a usuarios autorizados
        if (!widget.process.isPrivate) return users;
        return users.where((u) {
          final role = u.role.toLowerCase();
          // Solo SuperAdmin tiene acceso automático
          if (role == 'superadmin') return true;
          if (widget.process.visibleToUserIds.contains(u.id)) return true;
          if (u.id == widget.process.createdByUserId) return true;
          return false;
        }).toList();
      }),
      builder: (data) {
        final techs = data.where((u) => u.role == SystemRoles.technician).toList();

        // ── Stream anidado: eventos del calendario para detectar conflictos ──
        return StreamBuilder<List<CalendarEvent>>(
          stream: _eventService.getEventsStream(),
          builder: (ctx, evSnap) {
            final allEvents = evSnap.data ?? [];

            return _buildSelectableList(
              items: techs,
              emptyIcon: LucideIcons.userX,
              emptyMessage: "No hay técnicos",
              itemBuilder: (tech) {
                final conflictClient = _technicianConflict(tech.id, allEvents);
                final hasConflict = conflictClient != null;
                final isSelected = _selectedTechIds.contains(tech.id);

                return _buildTechnicianTileWithStatus(
                  tech: tech,
                  isSelected: isSelected,
                  hasConflict: hasConflict,
                  conflictClient: conflictClient,
                  onTap: () {
                    if (!widget.isEditable) return;
                    setState(() {
                      if (isSelected) {
                        _selectedTechIds.remove(tech.id);
                        _techNames.remove(tech.id);
                      } else {
                        _selectedTechIds.add(tech.id);
                        _techNames[tech.id] = tech.name;
                      }
                    });
                    _notifyData();
                  },
                );
              },
            );
          },
        );
      },
    );

    final toolWidget = _buildToolSelectionCard();
    final vehicleWidget = _buildVehicleSelectionCard();

    if (_isMobile) {
      return Column(
        children: [
          techWidget,
          const SizedBox(height: 16),
          toolWidget,
          const SizedBox(height: 16),
          vehicleWidget,
        ],
      );
    }

    return Column(
      children: [
        // Fila superior: Técnicos | Herramientas
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: techWidget),
            const SizedBox(width: 20),
            Expanded(child: toolWidget),
          ],
        ),
        const SizedBox(height: 20),
        // Vehículo centrado abajo
        Center(child: SizedBox(width: 460, child: vehicleWidget)),
      ],
    );
  }

  // ── HERRAMIENTAS: Card resumen + BottomSheet ──────────────────────────
  Widget _buildToolSelectionCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.wrench, size: 16, color: Color(0xFF475569)),
            const SizedBox(width: 8),
            Text("HERRAMIENTAS", style: _labelStyle()),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<dynamic>>(
          stream: _toolService.getTools(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final allTools = snap.data ?? [];
            final selectedTools = allTools
                .where((t) => _selectedToolIds.contains(t.id))
                .toList();

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips de seleccionados
                  if (selectedTools.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedTools
                            .map((tool) => _buildToolChip(tool))
                            .toList(),
                      ),
                    ),

                  if (selectedTools.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          "Sin herramientas seleccionadas",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // Botón para abrir selector
                  // Botón para abrir selector
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: widget.isEditable
                              ? () => _openToolSelector(allTools)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedColor.withOpacity(0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.plus,
                                  size: 16,
                                  color: _selectedColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  selectedTools.isEmpty
                                      ? "Seleccionar herramientas"
                                      : "Agregar o quitar herramientas",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── NUEVO: Botón descargar PDF ──
                        if (selectedTools.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _downloadToolsPdf,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    LucideIcons.fileDown,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Descargar listado en PDF",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolChip(dynamic tool) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _selectedColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _selectedColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.hammer, size: 12, color: _selectedColor),
          const SizedBox(width: 6),
          Text(
            tool.name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _selectedColor,
            ),
          ),
          if (widget.isEditable) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => _selectedToolIds.remove(tool.id));
                _notifyData();
              },
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: _selectedColor.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openToolSelector(List<dynamic> allTools) {
    _toolSearchCtrl.clear();
    _toolSearchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final visibleTools = allTools.where((tool) {
              final isSelected = _selectedToolIds.contains(tool.id);
              final isAvailable = tool.status == 'Disponible';
              if (!isAvailable && !isSelected) return false;

              if (_toolSearchQuery.isNotEmpty) {
                final q = _toolSearchQuery.toLowerCase();
                final matchName = tool.name.toString().toLowerCase().contains(
                  q,
                );
                final matchBrand = tool.brand.toString().toLowerCase().contains(
                  q,
                );
                return matchName || matchBrand;
              }
              return true;
            }).toList();

            // Ordenar: seleccionados primero
            visibleTools.sort((a, b) {
              final aSelected = _selectedToolIds.contains(a.id) ? 0 : 1;
              final bSelected = _selectedToolIds.contains(b.id) ? 0 : 1;
              return aSelected.compareTo(bSelected);
            });

            final selectedCount = _selectedToolIds.length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Seleccionar Herramientas",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$selectedCount seleccionada${selectedCount == 1 ? '' : 's'}",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Listo",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Barra de búsqueda
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: TextField(
                      controller: _toolSearchCtrl,
                      onChanged: (val) =>
                          setSheetState(() => _toolSearchQuery = val),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: "Buscar por nombre o marca...",
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        suffixIcon: _toolSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: () {
                                  _toolSearchCtrl.clear();
                                  setSheetState(() => _toolSearchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _selectedColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lista
                  Expanded(
                    child: visibleTools.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.searchX,
                                  size: 36,
                                  color: Color(0xFFCBD5E1),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Sin resultados",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: visibleTools.length,
                            itemBuilder: (_, i) {
                              final tool = visibleTools[i];
                              final isSelected = _selectedToolIds.contains(
                                tool.id,
                              );
                              final isInUse =
                                  tool.status == 'En Uso' && !isSelected;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildToolTile(
                                  tool: tool,
                                  isSelected: isSelected,
                                  isInUse: isInUse,
                                  onTap: () {
                                    if (!widget.isEditable || isInUse) return;
                                    setState(() {
                                      isSelected
                                          ? _selectedToolIds.remove(tool.id)
                                          : _selectedToolIds.add(tool.id);
                                    });
                                    setSheetState(() {});
                                    _notifyData();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── VEHÍCULOS: Card resumen simple ─────────────────────────────────────
  Widget _buildVehicleSelectionCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.truck, size: 16, color: Color(0xFF475569)),
            const SizedBox(width: 8),
            Text("VEHÍCULOS ASIGNADOS", style: _labelStyle()),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Vehicle>>(
          stream: _vehicleService.getVehicles(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final vehicles = snap.data ?? [];
            final hasVehicles = _selectedVehicleIds.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: hasVehicles ? _selectedColor.withOpacity(0.04) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasVehicles
                      ? _selectedColor.withOpacity(0.35)
                      : const Color(0xFFE2E8F0),
                  width: hasVehicles ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Chips de vehículos seleccionados ──
                  if (hasVehicles)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedVehicleIds.map((id) {
                          final name = _vehicleNames[id] ?? id;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: _selectedColor.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _selectedColor.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.truck,
                                      size: 10, color: Colors.white),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedColor,
                                  ),
                                ),
                                if (widget.isEditable) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedVehicleIds.remove(id);
                                        _vehicleNames.remove(id);
                                      });
                                      _notifyData();
                                    },
                                    child: Icon(LucideIcons.x,
                                        size: 13,
                                        color: _selectedColor.withOpacity(0.6)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ── Botón agregar ──
                  InkWell(
                    onTap: widget.isEditable
                        ? () => _openVehicleSelector(vehicles)
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: hasVehicles
                          ? Radius.zero
                          : const Radius.circular(14),
                      topRight: hasVehicles
                          ? Radius.zero
                          : const Radius.circular(14),
                      bottomLeft: const Radius.circular(14),
                      bottomRight: const Radius.circular(14),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: hasVehicles ? 12 : 18,
                      ),
                      child: Row(
                        mainAxisAlignment: hasVehicles
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          if (!hasVehicles) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.truck,
                                  size: 20, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Sin vehículos asignados",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Toca para seleccionar",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(LucideIcons.chevronRight,
                                size: 18, color: Color(0xFFCBD5E1)),
                          ] else ...[
                            Icon(LucideIcons.plus,
                                size: 14, color: _selectedColor),
                            const SizedBox(width: 6),
                            Text(
                              "Agregar otro vehículo",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openVehicleSelector(List<Vehicle> vehicles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final selectedCount = _selectedVehicleIds.length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Seleccionar Vehículos",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$selectedCount seleccionado${selectedCount == 1 ? '' : 's'}",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Listo",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 20, color: Color(0xFFE2E8F0)),
                  ),

                  // Lista
                  Expanded(
                    child: vehicles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.truck,
                                    size: 36, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 10),
                                Text(
                                  "Sin vehículos disponibles",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: vehicles.length,
                            itemBuilder: (_, i) {
                              final vehicle = vehicles[i];
                              final isSelected =
                                  _selectedVehicleIds.contains(vehicle.id);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: widget.isEditable
                                      ? () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedVehicleIds
                                                  .remove(vehicle.id);
                                              _vehicleNames.remove(vehicle.id);
                                            } else {
                                              _selectedVehicleIds.add(vehicle.id);
                                              _vehicleNames[vehicle.id] =
                                                  vehicle.model;
                                            }
                                          });
                                          setSheetState(() {});
                                          _notifyData();
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _selectedColor.withOpacity(0.08)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? _selectedColor.withOpacity(0.5)
                                            : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _selectedColor
                                                : _selectedColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(LucideIcons.truck,
                                              size: 18,
                                              color: isSelected
                                                  ? Colors.white
                                                  : _selectedColor),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                vehicle.model,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? _selectedColor
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(LucideIcons.zap,
                                                      size: 12,
                                                      color:
                                                          const Color(0xFF94A3B8)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "${vehicle.kmPerLiter.toStringAsFixed(1)} km/L",
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color:
                                                          const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(LucideIcons.checkCircle2,
                                              size: 20, color: _selectedColor)
                                        else
                                          const Icon(LucideIcons.circle,
                                              size: 20,
                                              color: Color(0xFFCBD5E1)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooterActions() {
    final colorRow = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colorPalette
          .map(
            (color) => GestureDetector(
              onTap: widget.isEditable
                  ? () {
                      setState(() => _selectedColor = color);
                      _notifyData();
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: _selectedColor == color ? 28 : 22,
                height: _selectedColor == color ? 28 : 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: _selectedColor == color ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_selectedColor == color)
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: _selectedColor == color
                    ? const Icon(
                        LucideIcons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          )
          .toList(),
    );

    final actionButton = SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: widget.isEditable && !_isScheduling ? _scheduleEvent : null,
        icon: _isScheduling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                _scheduledEventId != null
                    ? LucideIcons.refreshCw
                    : LucideIcons.calendarPlus,
                size: 18,
              ),
        label: Text(
          _scheduledEventId != null ? "Sincronizar" : "Guardar Evento",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedColor,
          foregroundColor: Colors.white,
          elevation: _isScheduling ? 0 : 2,
          shadowColor: _selectedColor.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );

    if (_isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ETIQUETA", style: _labelStyle()),
          const SizedBox(height: 10),
          colorRow,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: actionButton),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ETIQUETA", style: _labelStyle()),
            const SizedBox(height: 10),
            colorRow,
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: actionButton,
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
          border: Border.all(
            color: hasDate
                ? _selectedColor.withOpacity(0.3)
                : const Color(0xFFE2E8F0),
            width: hasDate ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: hasDate ? _selectedColor : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Text(
                  hasDate
                      ? DateFormat('dd MMM, yy').format(date)
                      : "Seleccionar",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: hasDate ? FontWeight.bold : FontWeight.w500,
                    color: hasDate
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
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
        border: Border.all(
          color: _exceedsQuotedDays
              ? const Color(0xFFFECDD3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DÍAS",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              if (_exceedsQuotedDays)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Excedido",
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$_calculatedDays",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _exceedsQuotedDays
                      ? const Color(0xFFBE123C)
                      : const Color(0xFF0F172A),
                ),
              ), // Número más pequeño
              Text(
                " / ${widget.quotedDays.toInt()} cotizados",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                _exceedsQuotedDays ? const Color(0xFFE11D48) : _selectedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceContainer<T>({
    required String title,
    required IconData icon,
    required Stream<List<T>> stream,
    required Widget Function(List<T>) builder,
  }) {
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
          height:
              170, // Altura reducida (antes 220) para que no ocupe media pantalla
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: StreamBuilder<List<T>>(
            stream: stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    "Error al cargar",
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                );
              }
              return builder(snap.data ?? []);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableList<T>({
    required List<T> items,
    required IconData emptyIcon,
    required String emptyMessage,
    required Widget Function(T) itemBuilder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 32, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
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

  /// Tile personalizado para técnicos con indicador visual de disponibilidad.
  /// NO restringe la selección, solo muestra un badge verde/rojo informativo.
  Widget _buildTechnicianTileWithStatus({
    required UserModel tech,
    required bool isSelected,
    required bool hasConflict,
    required String? conflictClient,
    required VoidCallback onTap,
  }) {
    // Colores según estado
    final Color statusColor = hasConflict
        ? const Color(0xFFDC2626) // Rojo: ocupado
        : const Color(0xFF059669); // Verde: disponible

    final Color statusBg = hasConflict
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFECFDF5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _selectedColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _selectedColor.withOpacity(0.5)
                : hasConflict
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar con icono de estado
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? _selectedColor : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.userCheck,
                    size: 14,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                // Puntito de estado (verde/rojo)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tech.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Badge de estado (DISPONIBLE / OCUPADO)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: statusColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasConflict
                              ? LucideIcons.alertCircle
                              : LucideIcons.checkCircle2,
                          size: 9,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            hasConflict
                                ? "Ocupado: $conflictClient"
                                : "Disponible",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, color: _selectedColor, size: 18)
            else
              const Icon(
                LucideIcons.circle,
                color: Color(0xFFCBD5E1),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolTile({
    required dynamic tool,
    required bool isSelected,
    required bool isInUse,
    required VoidCallback onTap,
  }) {
    // Colores según estado
    final Color borderColor = isSelected
        ? _selectedColor.withOpacity(0.5)
        : isInUse
        ? const Color(0xFFFECACA)
        : const Color(0xFFE2E8F0);

    final Color bgColor = isSelected
        ? _selectedColor.withOpacity(0.08)
        : isInUse
        ? const Color(0xFFFFF1F2)
        : Colors.white;

    final Color iconBg = isSelected
        ? _selectedColor
        : isInUse
        ? const Color(0xFFE11D48).withOpacity(0.1)
        : const Color(0xFFF1F5F9);

    final Color iconColor = isSelected
        ? Colors.white
        : isInUse
        ? const Color(0xFFE11D48)
        : const Color(0xFF64748B);

    return Opacity(
      opacity: isInUse ? 0.65 : 1.0,
      child: InkWell(
        onTap: isInUse ? null : onTap, // 🔒 Bloqueado si está en uso
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.hammer, size: 14, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.brand,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Badge de estado derecho ──────────────────
              if (isSelected)
                Icon(LucideIcons.checkCircle2, color: _selectedColor, size: 18)
              else if (isInUse)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE11D48).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE11D48),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "En Uso",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(
                  LucideIcons.circle,
                  color: Color(0xFFCBD5E1),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    color: const Color(0xFF64748B),
  );
}
