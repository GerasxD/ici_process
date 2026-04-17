import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:ici_process/models/client_model.dart';
import 'package:ici_process/models/event_model.dart';
import 'package:ici_process/models/user_model.dart';
import 'package:ici_process/models/vehicle_model.dart';
import 'package:ici_process/services/client_service.dart';
import 'package:ici_process/services/event_service.dart';
import 'package:ici_process/services/user_service.dart';
import 'package:ici_process/services/vehicle_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class EventFormDialog extends StatefulWidget {
  final UserModel currentUser;
  final DateTime? initialDate;
  final CalendarEvent? eventToEdit;

  const EventFormDialog({
    super.key,
    required this.currentUser,
    this.initialDate,
    this.eventToEdit,
  });

  @override
  State<EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  final _titleCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _customClientCtrl = TextEditingController();

  final EventService _eventService = EventService();
  final ClientService _clientService = ClientService();
  // ignore: unused_field
  final VehicleService _vehicleService = VehicleService();
  final UserService _userService = UserService();

  EventType _selectedType = EventType.reunionCliente;
  Client? _selectedClient;
  bool _isCustomClient = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  Color _selectedColor = const Color(0xFF2563EB);
  Set<String> _selectedVehicleIds = {};
  Map<String, String> _vehicleModelsMap = {};
  // ignore: unused_field
  String? _selectedVehicleModel;
  Set<String> _selectedTechIds = {};
  Map<String, String> _techNames = {}; // id → name
  String _editingClientName = '';

  bool _isSaving = false;

  // Paleta de colores disponibles
  final List<Color> _colorPalette = [
    const Color(0xFF2563EB),
    const Color(0xFF7C3AED),
    const Color(0xFF059669),
    const Color(0xFFEA580C),
    const Color(0xFF0891B2),
    const Color(0xFFDC2626),
    const Color(0xFFD97706),
    const Color(0xFF64748B),
    const Color(0xFFEC4899),
    const Color(0xFF0F172A),
  ];

  bool get isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _startDate = widget.initialDate!;
      _endDate = widget.initialDate!;
    }
    if (isEditing) _loadFromEvent(widget.eventToEdit!);
  }

  void _loadFromEvent(CalendarEvent e) {
    _titleCtrl.text = e.title;
    _selectedType = e.type;
    _isCustomClient = e.isCustomClient;
    if (_isCustomClient) {
      _customClientCtrl.text = e.clientName;
    }
    // ✅ FIX: Guardamos el nombre del cliente para la comparación
    _editingClientName = e.clientName;
    _contactNameCtrl.text = e.contactName;
    _contactPhoneCtrl.text = e.contactPhone;
    _startDate = e.startDate;
    _endDate = e.endDate;
    _selectedColor = e.color;
    _selectedVehicleIds = Set.from(e.vehicleIds);
    for (int i = 0; i < e.vehicleIds.length; i++) {
      if (i < e.vehicleModels.length) {
        _vehicleModelsMap[e.vehicleIds[i]] = e.vehicleModels[i];
      }
    }
    _selectedTechIds = Set.from(e.technicianIds);
    for (int i = 0; i < e.technicianIds.length; i++) {
      if (i < e.technicianNames.length) {
        _techNames[e.technicianIds[i]] = e.technicianNames[i];
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _customClientCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _selectedColor),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        if (picked.isBefore(_startDate)) {
          _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showSnack("El título es obligatorio", isError: true);
      return;
    }

    final clientName = _isCustomClient
        ? _customClientCtrl.text.trim()
        : (_selectedClient?.name ?? '');

    if (clientName.isEmpty) {
      _showSnack("Selecciona o escribe un cliente", isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final event = CalendarEvent(
        id: isEditing ? widget.eventToEdit!.id : '',
        title: _titleCtrl.text.trim(),
        type: _selectedType,
        clientName: clientName,
        contactName: _contactNameCtrl.text.trim(),
        contactPhone: _contactPhoneCtrl.text.trim(),
        isCustomClient: _isCustomClient,
        startDate: _startDate,
        endDate: _endDate,
        colorValue: _selectedColor.value,
        vehicleIds: _selectedVehicleIds.toList(),
        vehicleModels: _selectedVehicleIds
            .map((id) => _vehicleModelsMap[id] ?? '')
            .toList(),
        technicianIds: _selectedTechIds.toList(),
        technicianNames:
            _selectedTechIds.map((id) => _techNames[id] ?? '').toList(),
        createdBy: widget.currentUser.name,
        createdAt: isEditing ? widget.eventToEdit!.createdAt : DateTime.now(),
      );

      if (isEditing) {
        await _eventService.updateEvent(event);
      } else {
        await _eventService.createEvent(event);
      }

      if (mounted) {
        Navigator.pop(context, true);
        _showSnack(
            isEditing ? "Evento actualizado" : "Evento creado correctamente");
      }
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 16))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────
            _buildDialogHeader(),

            // ── Contenido scrolleable ───────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Título del evento
                    _buildLabel("Título del Evento"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleCtrl,
                      hint: "Ej. Visita técnica, Garantía...",
                      icon: LucideIcons.type,
                    ),

                    const SizedBox(height: 18),

                    // Tipo
                    _buildLabel("Tipo"),
                    const SizedBox(height: 8),
                    _buildTypeSelector(),

                    const SizedBox(height: 18),

                    // Cliente / Ubicación
                    _buildClientSection(),

                    const SizedBox(height: 18),

                    // Fechas
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Fecha Inicio"),
                              const SizedBox(height: 8),
                              _buildDateButton(_startDate, () => _pickDate(true)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Fecha Fin"),
                              const SizedBox(height: 8),
                              _buildDateButton(_endDate, () => _pickDate(false)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Color + Vehículo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Color Seguimiento"),
                              const SizedBox(height: 8),
                              _buildColorPicker(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Vehículo (Opcional)"),
                              const SizedBox(height: 8),
                              _buildVehicleSelector(),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Técnicos
                    _buildLabel("Asignar Técnicos (Disponibles)"),
                    const SizedBox(height: 8),
                    _buildTechnicianSelector(),
                  ],
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_selectedType.icon,
                color: _selectedColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? "Editar Evento" : "Agendar Evento Extraordinario",
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x,
                size: 20, color: Color(0xFF94A3B8)),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ── TYPE SELECTOR ─────────────────────────────────────────
  Widget _buildTypeSelector() {
    return DropdownButtonFormField<EventType>(
      value: _selectedType,
      isExpanded: true,
      onChanged: (val) => setState(() => _selectedType = val!),
      decoration: _inputDeco(),
      items: EventType.values.map((t) {
        return DropdownMenuItem(
          value: t,
          child: Row(
            children: [
              Icon(t.icon, size: 16, color: t.color),
              const SizedBox(width: 10),
              Text(t.label,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF1E293B))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── CLIENTE ───────────────────────────────────────────────
  Widget _buildClientSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CLIENTE / UBICACIÓN",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2563EB),
                  letterSpacing: 0.6,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _isCustomClient = !_isCustomClient;
                  _selectedClient = null;
                  _customClientCtrl.clear();
                }),
                child: Text(
                  _isCustomClient ? "Buscar en catálogo" : "Ingresar otro",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Selector de cliente o campo libre
          _isCustomClient
              ? TextField(
                  controller: _customClientCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _inputDeco().copyWith(
                    hintText: "Nombre del cliente / dirección...",
                    filled: true,
                    fillColor: Colors.white,
                  ),
                )
              : StreamBuilder<List<Client>>(
                  stream: _clientService.getClients(),
                  builder: (ctx, snap) {
                    final clients = snap.data ?? [];
                    if (_selectedClient == null && _editingClientName.isNotEmpty && !_isCustomClient) {
                      try {
                        // Buscamos en la lista el objeto completo que coincida con el nombre
                        _selectedClient = clients.firstWhere((c) => c.name == _editingClientName);
                      } catch (_) {
                        // Por si el cliente ya no existe en la base de datos
                      }
                    }
                    return DropdownButtonFormField<Client>(
                      value: _selectedClient,
                      isExpanded: true,
                      hint: Text("Seleccionar Cliente...",
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8))),
                      onChanged: (c) => setState(() => _selectedClient = c),
                      decoration: _inputDeco().copyWith(
                          filled: true, fillColor: Colors.white),
                      items: clients
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 14)),
                              ))
                          .toList(),
                    );
                  },
                ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contactNameCtrl,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _inputDeco().copyWith(
                    hintText: "Nombre Contacto",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _contactPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _inputDeco().copyWith(
                    hintText: "Teléfono",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── DATE BUTTON ───────────────────────────────────────────
  Widget _buildDateButton(DateTime date, VoidCallback onTap) {
    final fmt = DateFormat('dd/MM/yyyy');
    final parts = fmt.format(date).split('/');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 16, color: _selectedColor),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155)),
                children: [
                  TextSpan(text: parts[0]),
                  TextSpan(
                      text: '/',
                      style:
                          TextStyle(color: _selectedColor, fontWeight: FontWeight.w800)),
                  TextSpan(text: parts[1]),
                  TextSpan(
                      text: '/',
                      style:
                          TextStyle(color: _selectedColor, fontWeight: FontWeight.w800)),
                  TextSpan(text: parts[2]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COLOR PICKER ──────────────────────────────────────────
  Widget _buildColorPicker() {
    return InkWell(
      onTap: _showColorDialog,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: _selectedColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Elegir",
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(LucideIcons.chevronDown,
                size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showColorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Seleccionar Color",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorPalette.map((color) {
            final isSelected = color.value == _selectedColor.value;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedColor = color);
                Navigator.pop(ctx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Colors.white, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: isSelected ? 10 : 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── VEHICLE SELECTOR ─────────────────────────────────────
  Widget _buildVehicleSelector() {
    return StreamBuilder<List<Vehicle>>(
      stream: VehicleService().getVehicles(),
      builder: (ctx, snap) {
        final vehicles = snap.data ?? [];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              if (_selectedVehicleIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedVehicleIds.map((id) {
                      final model = _vehicleModelsMap[id] ?? id;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _selectedColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.truck,
                                size: 11, color: _selectedColor),
                            const SizedBox(width: 5),
                            Text(model,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedColor)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedVehicleIds.remove(id);
                                _vehicleModelsMap.remove(id);
                              }),
                              child: Icon(LucideIcons.x,
                                  size: 12,
                                  color: _selectedColor.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ...vehicles.map((v) {
                final isSelected = _selectedVehicleIds.contains(v.id);
                return InkWell(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedVehicleIds.remove(v.id);
                      _vehicleModelsMap.remove(v.id);
                    } else {
                      _selectedVehicleIds.add(v.id);
                      _vehicleModelsMap[v.id] = v.model;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withOpacity(0.06)
                          : Colors.transparent,
                      border: vehicles.last.id != v.id
                          ? const Border(
                              bottom: BorderSide(color: Color(0xFFF1F5F9)))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.truck,
                            size: 14, color: const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(v.model,
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _selectedColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? _selectedColor
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Revisa si el técnico ya está asignado a un evento que se solape
  /// con [_startDate]-[_endDate]. Devuelve el nombre del cliente del
  /// evento que genera conflicto, o null si está libre.
  String? _technicianConflict(String techId, List<CalendarEvent> allEvents) {
    final editingId = widget.eventToEdit?.id;

    // ✅ FIX: Normalizamos a medianoche para comparar solo la fecha
    final rangeStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final rangeEnd = DateTime(_endDate.year, _endDate.month, _endDate.day);

    for (final ev in allEvents) {
      if (editingId != null && ev.id == editingId) continue;
      if (!ev.technicianIds.contains(techId)) continue;

      // Normalizamos las fechas del evento guardado también
      final evStart = DateTime(ev.startDate.year, ev.startDate.month, ev.startDate.day);
      final evEnd = DateTime(ev.endDate.year, ev.endDate.month, ev.endDate.day);

      final overlaps = evStart.compareTo(rangeEnd) <= 0 &&
          evEnd.compareTo(rangeStart) >= 0;
      if (!overlaps) continue;

      return ev.clientName;
    }
    return null;
  }

  // ── TECHNICIAN SELECTOR ───────────────────────────────────
  Widget _buildTechnicianSelector() {
    return StreamBuilder<List<UserModel>>(
      stream: _userService.getUsersStream(),
      builder: (ctx, userSnap) {
        final technicians = (userSnap.data ?? [])
            .where((u) => u.role == UserRole.technician)
            .toList();

        if (technicians.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                "No hay técnicos disponibles.",
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ),
          );
        }

        // ── Segundo stream: eventos existentes ──
        return StreamBuilder<List<CalendarEvent>>(
          stream: _eventService.getEventsStream(),
          builder: (ctx, evSnap) {
            final allEvents = evSnap.data ?? [];

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: technicians.map((tech) {
                  final isSelected = _selectedTechIds.contains(tech.id);

                  // ── LÓGICA DE CONFLICTO ──
                  final conflictClient =
                      _technicianConflict(tech.id, allEvents);
                  final hasConflict = conflictClient != null;
                  final sameClient = hasConflict &&
                      _currentClientName.isNotEmpty &&
                      conflictClient.toLowerCase().trim() ==
                          _currentClientName.toLowerCase().trim();

                  // Bloqueado = tiene conflicto Y no es el mismo cliente
                  final isBlocked = hasConflict && !sameClient;

                  return InkWell(
                    onTap: isBlocked
                        ? null // No se puede tocar
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedTechIds.remove(tech.id);
                                _techNames.remove(tech.id);
                              } else {
                                _selectedTechIds.add(tech.id);
                                _techNames[tech.id] = tech.name;
                              }
                            });
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isBlocked
                            ? const Color(0xFFFEF2F2)
                            : isSelected
                                ? _selectedColor.withOpacity(0.06)
                                : Colors.transparent,
                        border: technicians.last.id != tech.id
                            ? const Border(
                                bottom:
                                    BorderSide(color: Color(0xFFF1F5F9)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isBlocked
                                ? const Color(0xFFFECACA)
                                : isSelected
                                    ? _selectedColor.withOpacity(0.15)
                                    : const Color(0xFFF1F5F9),
                            child: isBlocked
                                ? const Icon(LucideIcons.ban,
                                    size: 14, color: Color(0xFFDC2626))
                                : Text(
                                    tech.name.isNotEmpty
                                        ? tech.name[0].toUpperCase()
                                        : 'T',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? _selectedColor
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tech.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isBlocked
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                // ── Línea de estado ──
                                if (isBlocked)
                                  Text(
                                    "Ocupado: $conflictClient",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  )
                                else if (hasConflict && sameClient)
                                  Text(
                                    "Ya asignado a esta empresa ✓",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF059669),
                                    ),
                                  )
                                else
                                  Text(
                                    tech.email,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Checkbox visual
                          if (isBlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                "No disponible",
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            )
                          else
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _selectedColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? _selectedColor
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  // ── FOOTER ────────────────────────────────────────────────
  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (isEditing)
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("¿Eliminar evento?"),
                    content: const Text("Esta acción no se puede deshacer."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancelar")),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text("Eliminar"),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await EventService()
                      .deleteEvent(widget.eventToEdit!.id);
                  if (mounted) Navigator.pop(context, true);
                }
              },
              icon: const Icon(LucideIcons.trash2,
                  size: 16, color: Color(0xFFDC2626)),
              label: const Text("Eliminar",
                  style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600)),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar",
                style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    isEditing ? "Guardar Cambios" : "Crear Evento",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  String get _currentClientName {
    if (_isCustomClient) return _customClientCtrl.text.trim();
    if (_selectedClient != null) return _selectedClient!.name;
    // Al editar evento con cliente de catálogo, _selectedClient es null
    // pero _editingClientName tiene el nombre guardado
    return _editingClientName;
  }

  // ── HELPERS UI ────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
      decoration: _inputDeco().copyWith(
        hintText: hint,
        prefixIcon: Icon(icon, size: 17, color: const Color(0xFF94A3B8)),
      ),
    );
  }

  InputDecoration _inputDeco() => InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: GoogleFonts.inter(
            color: const Color(0xFF94A3B8), fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _selectedColor, width: 1.5),
        ),
      );
}