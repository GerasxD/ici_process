import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/worker_model.dart';
import '../../services/worker_service.dart';

class WorkerManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  const WorkerManagementScreen({super.key, required this.currentUser});

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen> {
  final WorkerService _workerService = WorkerService();

  late final Stream<List<Worker>> _workersStream;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nssCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController(); // ← NUEVO

  String _selectedBloodType = '';
  DateTime? _selectedStartDate;
  bool _isUploading = false;

  final List<String> _bloodTypes = [
    '', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF0D9488);

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_workers');

  @override
  void initState() {
    super.initState();
    _workersStream = _workerService.getWorkers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _nssCtrl.dispose();
    _curpCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyPhoneCtrl.dispose(); // ← NUEVO
    super.dispose();
  }

  Future<void> _handleAddNew() async {
    if (!canEdit) return;
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack("El nombre es obligatorio", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final worker = Worker(
        id: '',
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        nss: _nssCtrl.text.trim(),
        curp: _curpCtrl.text.trim().toUpperCase(),
        bloodType: _selectedBloodType,
        startDate: _selectedStartDate,
        address: _addressCtrl.text.trim(),
        emergencyPhone: _emergencyPhoneCtrl.text.trim(), // ← NUEVO
      );

      await _workerService.addWorker(worker);
      _resetForm();
      _showSnack("Trabajador registrado correctamente");
    } catch (e) {
      _showSnack("Error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _nssCtrl.clear();
    _curpCtrl.clear();
    _addressCtrl.clear();
    _emergencyPhoneCtrl.clear(); // ← NUEVO
    setState(() {
      _selectedBloodType = '';
      _selectedStartDate = null;
    });
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              StreamBuilder<List<Worker>>(
                stream: _workersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final workers = snapshot.data ?? [];

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildList(workers)),
                        const SizedBox(width: 40),
                        if (canEdit) Expanded(flex: 4, child: _buildForm()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        if (canEdit) ...[_buildForm(), const SizedBox(height: 40)],
                        _buildList(workers),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }

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
          child: Icon(LucideIcons.hardHat, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Personal y Trabajadores", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("Gestiona los datos del equipo técnico y operativo.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Worker> workers) {
    if (workers.isEmpty) return _buildEmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DIRECTORIO DE PERSONAL (${workers.length})",
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 1),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: workers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, index) => _buildCard(workers[index]),
        ),
      ],
    );
  }

  Widget _buildCard(Worker worker) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final bool hasExtraData = worker.nss.isNotEmpty || worker.curp.isNotEmpty || worker.bloodType.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                worker.name.isNotEmpty ? worker.name.substring(0, 1).toUpperCase() : 'T',
                style: GoogleFonts.inter(color: _accentColor, fontWeight: FontWeight.w700, fontSize: 20),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(worker.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
              ),
              if (!hasExtraData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 11, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Text("Completar datos", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFB45309))),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (worker.email.isNotEmpty) ...[
                  Icon(LucideIcons.mail, size: 13, color: _textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(worker.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
                  ),
                ],
                if (worker.bloodType.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.droplets, size: 11, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text(worker.bloodType, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
                if (worker.startDate != null) ...[
                  const SizedBox(width: 12),
                  Icon(LucideIcons.calendarCheck, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(dateFmt.format(worker.startDate!), style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                ],
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit) ...[
                _buildIconBtn(icon: LucideIcons.edit3, color: Colors.blue, onTap: () => _showEditDialog(worker)),
                const SizedBox(width: 8),
                _buildIconBtn(icon: LucideIcons.trash2, color: Colors.red, onTap: () => _confirmDelete(worker)),
              ],
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.clipboard, size: 16, color: _textSecondary),
                      const SizedBox(width: 8),
                      Text("DATOS PERSONALES", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      _buildInfoField("NSS (Seguro Social)", worker.nss.isNotEmpty ? worker.nss : "No registrado"),
                      _buildInfoField("CURP", worker.curp.isNotEmpty ? worker.curp : "No registrado"),
                      _buildInfoField("Tipo de Sangre", worker.bloodType.isNotEmpty ? worker.bloodType : "No registrado"),
                      _buildInfoField("Fecha de Ingreso", worker.startDate != null ? dateFmt.format(worker.startDate!) : "No registrada"),
                      _buildInfoField("Correo Electrónico", worker.email.isNotEmpty ? worker.email : "No registrado"),
                    ],
                  ),

                  // ── NÚMERO DE EMERGENCIA ─────────────────── ← NUEVO
                  if (worker.emergencyPhone.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.phoneCall, size: 16, color: Color(0xFFFF6B35)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("CONTACTO DE EMERGENCIA", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(
                              worker.emergencyPhone,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B35)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(LucideIcons.phoneCall, size: 16, color: const Color(0xFFFF6B35).withOpacity(0.4)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("CONTACTO DE EMERGENCIA", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text("No registrado", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                    ),
                  ],

                  if (worker.address.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.mapPin, size: 14, color: _accentColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("DIRECCIÓN PARTICULAR", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(worker.address, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    final bool isEmpty = value == "No registrado" || value == "No registrada";
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
              color: isEmpty ? const Color(0xFF94A3B8) : _textPrimary,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(LucideIcons.userPlus, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text("Registrar Trabajador", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, size: 14, color: Color(0xFF0369A1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Los técnicos creados desde Administración → Usuarios también aparecen aquí automáticamente.",
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0C4A6E), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionLabel("Datos Personales"),
          _input(_nameCtrl, "Nombre Completo", LucideIcons.user),
          const SizedBox(height: 12),
          _input(_emailCtrl, "Correo Electrónico", LucideIcons.mail),

          const SizedBox(height: 24),
          _buildSectionLabel("Documentos Oficiales"),
          _input(_nssCtrl, "NSS (Seguro Social)", LucideIcons.shieldCheck),
          const SizedBox(height: 12),
          _input(_curpCtrl, "CURP", LucideIcons.fingerprint),

          const SizedBox(height: 24),
          _buildSectionLabel("Información Médica y Laboral"),
          Row(
            children: [
              Expanded(child: _buildBloodTypeDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildDatePickerField()),
            ],
          ),

          // ── NÚMERO DE EMERGENCIA ─────────────────────── ← NUEVO
          const SizedBox(height: 24),
          _buildSectionLabel("Contacto de Emergencia"),
          _inputEmergencyPhone(_emergencyPhoneCtrl),

          const SizedBox(height: 24),
          _buildSectionLabel("Domicilio"),
          _input(_addressCtrl, "Dirección particular completa", LucideIcons.mapPin, maxLines: 2),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _handleAddNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Registrar Trabajador", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Campo especial para teléfono de emergencia ── ← NUEVO
  Widget _inputEmergencyPhone(TextEditingController ctrl) {
    return Container(
      decoration: BoxDecoration(
        color: _inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.phone,
        style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: const Icon(LucideIcons.phoneCall, size: 20, color: Color(0xFFFF6B35)),
          ),
          hintText: "Número de emergencia (ej. 449 123 4567)",
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBloodTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBloodType,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
          items: _bloodTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  if (type.isNotEmpty) ...[
                    Icon(LucideIcons.droplets, size: 14, color: const Color(0xFFDC2626).withOpacity(0.7)),
                    const SizedBox(width: 8),
                  ],
                  Text(type.isEmpty ? "Tipo de Sangre" : type, style: GoogleFonts.inter(fontSize: 14, color: type.isEmpty ? Colors.grey : _textPrimary)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedBloodType = val ?? ''),
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedStartDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _accentColor)),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _selectedStartDate = picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(LucideIcons.calendarCheck, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedStartDate != null ? DateFormat('dd/MM/yyyy').format(_selectedStartDate!) : "Fecha de Ingreso",
                style: GoogleFonts.inter(fontSize: 14, color: _selectedStartDate != null ? _textPrimary : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: Colors.grey.shade400)),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
      ),
    );
  }

  // ── DIÁLOGO DE EDICIÓN ──────────────────────────────────
  void _showEditDialog(Worker worker) {
    final editNssCtrl = TextEditingController(text: worker.nss);
    final editCurpCtrl = TextEditingController(text: worker.curp);
    final editAddressCtrl = TextEditingController(text: worker.address);
    final editEmailCtrl = TextEditingController(text: worker.email);
    final editEmergencyPhoneCtrl = TextEditingController(text: worker.emergencyPhone);

    String tempBloodType = worker.bloodType;
    DateTime? tempStartDate = worker.startDate;
    bool isSaving = false;

    // Función para descargar todos los controladores de forma segura
    void disposeControllers() {
      // ignore: invalid_use_of_protected_member
      if (!editNssCtrl.hasListeners) editNssCtrl.dispose();
      // ignore: invalid_use_of_protected_member
      if (!editCurpCtrl.hasListeners) editCurpCtrl.dispose();
      // ignore: invalid_use_of_protected_member
      if (!editAddressCtrl.hasListeners) editAddressCtrl.dispose();
      // ignore: invalid_use_of_protected_member
      if (!editEmailCtrl.hasListeners) editEmailCtrl.dispose();
      // ignore: invalid_use_of_protected_member
      if (!editEmergencyPhoneCtrl.hasListeners) editEmergencyPhoneCtrl.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando fuera para controlar el dispose
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return WillPopScope(
            onWillPop: () async {
              // Descargar controladores cuando se cierra con el botón de atrás
              disposeControllers();
              return true;
            },
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.userCog, color: _accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Editar Datos",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          worker.name,
                          style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel("Correo Electrónico"),
                      TextField(
                        controller: editEmailCtrl,
                        style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(LucideIcons.mail, size: 20, color: Colors.grey.shade400),
                          ),
                          hintText: "correo@empresa.com",
                          filled: true,
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel("Documentos Oficiales"),
                      TextField(
                        controller: editNssCtrl,
                        style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(LucideIcons.shieldCheck, size: 20, color: Colors.grey.shade400),
                          ),
                          hintText: "NSS (Seguro Social)",
                          filled: true,
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: editCurpCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(LucideIcons.fingerprint, size: 20, color: Colors.grey.shade400),
                          ),
                          hintText: "CURP",
                          filled: true,
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel("Información Médica y Laboral"),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: _inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _bloodTypes.contains(tempBloodType) ? tempBloodType : '',
                                  isExpanded: true,
                                  icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
                                  items: _bloodTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type.isEmpty ? "Sin especificar" : type,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: type.isEmpty ? Colors.grey : _textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setModalState(() => tempBloodType = val ?? ''),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: tempStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) => Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(primary: _accentColor),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(() => tempStartDate = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: _inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.calendarCheck, size: 18, color: Colors.grey.shade400),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tempStartDate != null
                                            ? DateFormat('dd/MM/yyyy').format(tempStartDate!)
                                            : "Fecha de Ingreso",
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: tempStartDate != null ? _textPrimary : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel("Contacto de Emergencia"),
                      Container(
                        decoration: BoxDecoration(
                          color: _inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
                        ),
                        child: TextField(
                          controller: editEmergencyPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                          decoration: InputDecoration(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(LucideIcons.phoneCall, size: 20, color: Color(0xFFFF6B35)),
                            ),
                            hintText: "Número de emergencia",
                            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel("Domicilio"),
                      TextField(
                        controller: editAddressCtrl,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(LucideIcons.mapPin, size: 20, color: Colors.grey.shade400),
                          ),
                          hintText: "Dirección particular",
                          filled: true,
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                TextButton(
                  onPressed: () {
                    // Descargar controladores antes de cerrar
                    disposeControllers();
                    Navigator.pop(ctx);
                  },
                  style: TextButton.styleFrom(foregroundColor: _textSecondary),
                  child: Text("Cancelar", style: GoogleFonts.inter()),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            final updated = Worker(
                              id: worker.id,
                              name: worker.name,
                              email: editEmailCtrl.text.trim(),
                              nss: editNssCtrl.text.trim(),
                              curp: editCurpCtrl.text.trim().toUpperCase(),
                              bloodType: tempBloodType,
                              startDate: tempStartDate,
                              address: editAddressCtrl.text.trim(),
                              emergencyPhone: editEmergencyPhoneCtrl.text.trim(),
                            );
                            await _workerService.updateWorkerDetails(updated);
                            
                            // Descargar controladores después de guardar exitosamente
                            disposeControllers();
                            
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnack("Datos actualizados correctamente");
                          } catch (e) {
                            _showSnack("Error: $e", isSuccess: false);
                          } finally {
                            if (ctx.mounted) setModalState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          "Guardar Cambios",
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(Worker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Text("Eliminar Trabajador", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("¿Seguro que deseas eliminar a '${worker.name}'?", style: GoogleFonts.inter()),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Si este trabajador tiene cuenta de acceso al sistema, también perderá su acceso.",
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              _workerService.deleteWorker(worker.id);
              Navigator.pop(ctx);
              _showSnack("Trabajador eliminado");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.userX, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No hay trabajadores registrados", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(height: 8),
          Text("Los usuarios de tipo Técnico aparecerán aquí automáticamente.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626), size: 32),
            const SizedBox(height: 12),
            Text("Error de conexión", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
            Text(error, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C))),
          ],
        ),
      ),
    );
  }
}