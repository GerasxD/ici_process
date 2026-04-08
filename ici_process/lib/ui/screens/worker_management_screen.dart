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
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF0D9488);

  bool get canEdit =>
      PermissionManager().can(widget.currentUser, 'edit_workers');

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 1000;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                StreamBuilder<List<Worker>>(
                  stream: _workersStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return _buildErrorState(snapshot.error.toString());
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
                          if (canEdit) ...[
                            _buildForm(),
                            const SizedBox(height: 40),
                          ],
                          _buildList(workers),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
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
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.hardHat, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personal y Trabajadores",
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Gestiona los datos del equipo técnico y operativo.",
                style: GoogleFonts.inter(fontSize: 15, color: _textSecondary),
              ),
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
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
            letterSpacing: 1,
          ),
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

    final initials = worker.name.isNotEmpty
        ? worker.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'T';

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
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor.withOpacity(0.1), _accentColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentColor.withOpacity(0.15)),
            ),
            child: Center(
              child: Text(initials, style: GoogleFonts.inter(color: _accentColor, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(worker.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _textPrimary)),
              ),
              if (!hasExtraData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 10, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Text("Completar", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                // Badge email
                if (worker.email.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.mail, size: 10, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(worker.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Badge sangre
                if (worker.bloodType.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.droplets, size: 10, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text(worker.bloodType, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
                // Badge fecha
                if (worker.startDate != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _accentColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.calendarCheck, size: 10, color: _accentColor),
                        const SizedBox(width: 4),
                        Text(dateFmt.format(worker.startDate!), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _accentColor)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit) ...[
                _buildActionIcon(LucideIcons.edit3, const Color(0xFF2563EB), () => _showEditDialog(worker)),
                const SizedBox(width: 4),
                _buildActionIcon(LucideIcons.trash2, const Color(0xFFEF4444), () => _confirmDelete(worker)),
                const SizedBox(width: 8),
              ],
              const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFFCBD5E1)),
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
                  // Header documentos
                  Row(
                    children: [
                      const Icon(LucideIcons.fileText, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Text("DOCUMENTOS OFICIALES", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Campos en chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildDetailChip(LucideIcons.shieldCheck, "NSS", worker.nss.isNotEmpty ? worker.nss : "No registrado", const Color(0xFF2563EB), worker.nss.isNotEmpty),
                      _buildDetailChip(LucideIcons.fingerprint, "CURP", worker.curp.isNotEmpty ? worker.curp : "No registrado", const Color(0xFF7C3AED), worker.curp.isNotEmpty),
                      _buildDetailChip(LucideIcons.droplets, "Sangre", worker.bloodType.isNotEmpty ? worker.bloodType : "N/R", const Color(0xFFDC2626), worker.bloodType.isNotEmpty),
                      _buildDetailChip(LucideIcons.calendarCheck, "Ingreso", worker.startDate != null ? dateFmt.format(worker.startDate!) : "No registrada", _accentColor, worker.startDate != null),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Container(height: 1, color: _borderColor),
                  const SizedBox(height: 16),

                  // Contacto de emergencia
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: worker.emergencyPhone.isNotEmpty
                          ? const Color(0xFFEA580C).withOpacity(0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: worker.emergencyPhone.isNotEmpty
                            ? const Color(0xFFEA580C).withOpacity(0.15)
                            : _borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withOpacity(worker.emergencyPhone.isNotEmpty ? 0.1 : 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(LucideIcons.phoneCall, size: 14, color: Color(worker.emergencyPhone.isNotEmpty ? 0xFFEA580C : 0xFFCBD5E1)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("CONTACTO DE EMERGENCIA", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                              const SizedBox(height: 2),
                              Text(
                                worker.emergencyPhone.isNotEmpty ? worker.emergencyPhone : "No registrado",
                                style: worker.emergencyPhone.isNotEmpty
                                    ? GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFEA580C))
                                    : GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dirección
                  if (worker.address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(LucideIcons.mapPin, size: 14, color: _accentColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("DOMICILIO", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(worker.address, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Correo (si existe, en su propia card)
                  if (worker.email.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.mail, size: 14, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("CORREO ELECTRÓNICO", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(worker.email, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value, Color color, bool hasData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasData ? color.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasData ? color.withOpacity(0.15) : _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: hasData ? color.withOpacity(0.6) : const Color(0xFFCBD5E1)),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: hasData ? color.withOpacity(0.6) : const Color(0xFF94A3B8), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: hasData
                ? GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)
                : GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue.withOpacity(0.08), _primaryBlue.withOpacity(0.02)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _borderColor.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.userPlus, color: _primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Registrar Trabajador", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _textPrimary)),
                      const SizedBox(height: 2),
                      Text("Completa los datos del personal", style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Cuerpo ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nota informativa
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, size: 14, color: Color(0xFF0369A1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Los técnicos creados desde Administración → Usuarios también aparecen aquí.",
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0C4A6E), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Datos Personales ──────────────────────────
                _buildFormSectionLabel("Datos Personales", LucideIcons.user),
                const SizedBox(height: 10),
                _buildFormLabel("NOMBRE COMPLETO"),
                const SizedBox(height: 6),
                _input(_nameCtrl, "Ej. Carlos Ramírez López", LucideIcons.user),
                const SizedBox(height: 12),
                _buildFormLabel("CORREO ELECTRÓNICO"),
                const SizedBox(height: 6),
                _input(_emailCtrl, "correo@empresa.com", LucideIcons.mail),

                const SizedBox(height: 20),
                _buildFormDivider(),
                const SizedBox(height: 20),

                // ── Documentos ────────────────────────────────
                _buildFormSectionLabel("Documentos Oficiales", LucideIcons.fileText),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildFormLabel("NSS"),
                        const SizedBox(height: 6),
                        _input(_nssCtrl, "12345678901", LucideIcons.shieldCheck),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildFormLabel("CURP"),
                        const SizedBox(height: 6),
                        _input(_curpCtrl, "RAMC900101...", LucideIcons.fingerprint),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _buildFormDivider(),
                const SizedBox(height: 20),

                // ── Médica y Laboral ──────────────────────────
                _buildFormSectionLabel("Médica y Laboral", LucideIcons.heartPulse),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildFormLabel("TIPO DE SANGRE"),
                        const SizedBox(height: 6),
                        _buildBloodTypeDropdown(),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildFormLabel("FECHA DE INGRESO"),
                        const SizedBox(height: 6),
                        _buildDatePickerField(),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _buildFormDivider(),
                const SizedBox(height: 20),

                // ── Emergencia ────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFFEA580C).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(LucideIcons.phoneCall, size: 14, color: Color(0xFFEA580C)),
                    ),
                    const SizedBox(width: 10),
                    Text("Emergencia", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFEA580C))),
                  ],
                ),
                const SizedBox(height: 10),
                _inputEmergencyPhone(_emergencyPhoneCtrl),

                const SizedBox(height: 20),
                _buildFormDivider(),
                const SizedBox(height: 20),

                // ── Domicilio ─────────────────────────────────
                _buildFormSectionLabel("Domicilio", LucideIcons.mapPin),
                const SizedBox(height: 10),
                _input(_addressCtrl, "Calle, Número, Colonia, CP...", LucideIcons.mapPin, maxLines: 2),

                const SizedBox(height: 28),

                // ── Botón ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _handleAddNew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primaryBlue.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.userPlus, size: 18),
                              const SizedBox(width: 8),
                              Text("Registrar Trabajador", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers del formulario ──────────────────────────────────
  Widget _buildFormSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: _primaryBlue),
        ),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
      ],
    );
  }

  Widget _buildFormLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
    );
  }

  Widget _buildFormDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_borderColor.withOpacity(0), _borderColor, _borderColor.withOpacity(0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
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
            child: const Icon(
              LucideIcons.phoneCall,
              size: 20,
              color: Color(0xFFFF6B35),
            ),
          ),
          hintText: "Número de emergencia (ej. 449 123 4567)",
          hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
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
    );
  }

  Widget _buildBloodTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBloodType,
          isExpanded: true,
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 18,
            color: Colors.grey,
          ),
          items: _bloodTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  if (type.isNotEmpty) ...[
                    Icon(
                      LucideIcons.droplets,
                      size: 14,
                      color: const Color(0xFFDC2626).withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    type.isEmpty ? "Tipo de Sangre" : type,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: type.isEmpty ? Colors.grey : _textPrimary,
                    ),
                  ),
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
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: _accentColor),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _selectedStartDate = picked);
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
            Icon(
              LucideIcons.calendarCheck,
              size: 18,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedStartDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedStartDate!)
                    : "Fecha de Ingreso",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _selectedStartDate != null
                      ? _textPrimary
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _input(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: Colors.grey.shade400),
        ),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
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
          borderSide: BorderSide(color: _primaryBlue, width: 1.5),
        ),
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

    void disposeControllers() {
      editNssCtrl.dispose();
      editCurpCtrl.dispose();
      editAddressCtrl.dispose();
      editEmailCtrl.dispose();
      editEmergencyPhoneCtrl.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 540,
              constraints: const BoxConstraints(maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
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
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: Text(
                              worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'T',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Editar Trabajador", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text(worker.name, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () { disposeControllers(); Navigator.pop(ctx); },
                          icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // Contenido
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Correo
                          Text("CORREO ELECTRÓNICO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: editEmailCtrl,
                            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(LucideIcons.mail, size: 18, color: Colors.grey.shade400),
                              hintText: "correo@empresa.com",
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                              filled: true, fillColor: _inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Documentos
                          Row(children: [
                            const Icon(LucideIcons.fileText, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            Text("DOCUMENTOS OFICIALES", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          ]),
                          const SizedBox(height: 12),
                          TextField(
                            controller: editNssCtrl,
                            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(LucideIcons.shieldCheck, size: 18, color: Colors.grey.shade400),
                              hintText: "NSS (Seguro Social)",
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                              filled: true, fillColor: _inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: editCurpCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(LucideIcons.fingerprint, size: 18, color: Colors.grey.shade400),
                              hintText: "CURP",
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                              filled: true, fillColor: _inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Médica y laboral
                          Row(children: [
                            const Icon(LucideIcons.heartPulse, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            Text("INFORMACIÓN MÉDICA Y LABORAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          ]),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _bloodTypes.contains(tempBloodType) ? tempBloodType : '',
                                      isExpanded: true,
                                      icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
                                      items: _bloodTypes.map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type.isEmpty ? "Tipo de sangre" : type, style: GoogleFonts.inter(fontSize: 14, color: type.isEmpty ? Colors.grey : _textPrimary)),
                                      )).toList(),
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
                                      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _accentColor)), child: child!),
                                    );
                                    if (picked != null) setModalState(() => tempStartDate = picked);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12)),
                                    child: Row(children: [
                                      Icon(LucideIcons.calendarCheck, size: 18, color: Colors.grey.shade400),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          tempStartDate != null ? DateFormat('dd/MM/yyyy').format(tempStartDate!) : "Fecha de Ingreso",
                                          style: GoogleFonts.inter(fontSize: 13, color: tempStartDate != null ? _textPrimary : Colors.grey.shade400),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Emergencia
                          Row(children: [
                            const Icon(LucideIcons.phoneCall, size: 14, color: Color(0xFFEA580C)),
                            const SizedBox(width: 8),
                            Text("CONTACTO DE EMERGENCIA", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFEA580C), letterSpacing: 0.8)),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3))),
                            child: TextField(
                              controller: editEmergencyPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(LucideIcons.phoneCall, size: 18, color: Color(0xFFEA580C)),
                                hintText: "Número de emergencia",
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                                filled: true, fillColor: Colors.transparent,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Domicilio
                          Text("DOMICILIO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: editAddressCtrl,
                            maxLines: 2,
                            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(LucideIcons.mapPin, size: 18, color: Colors.grey.shade400),
                              hintText: "Dirección particular",
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                              filled: true, fillColor: _inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () { disposeControllers(); Navigator.pop(ctx); },
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                            child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
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
                                      disposeControllers();
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _showSnack("Datos actualizados correctamente");
                                    } catch (e) {
                                      _showSnack("Error: $e", isSuccess: false);
                                    } finally {
                                      if (ctx.mounted) setModalState(() => isSaving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: isSaving
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
    );
  }

  void _confirmDelete(Worker worker) {
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
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.trash2,
                        color: Color(0xFFDC2626),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Eliminar Trabajador",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Se dará de baja del sistema",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        LucideIcons.x,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      splashRadius: 20,
                    ),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                worker.name.isNotEmpty
                                    ? worker.name[0].toUpperCase()
                                    : 'T',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  worker.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.alertTriangle,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "El trabajador será eliminado permanentemente del registro de personal.",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFED7AA).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.info,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Si este trabajador tiene cuenta de acceso al sistema, también perderá su acceso de forma inmediata.",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
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
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          "Cancelar",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          _workerService.deleteWorker(worker.id);
                          Navigator.pop(ctx);
                          _showSnack("Trabajador eliminado correctamente");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Eliminar Trabajador",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.userX, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No hay trabajadores registrados",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Los usuarios de tipo Técnico aparecerán aquí automáticamente.",
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400),
          ),
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
            const Icon(
              LucideIcons.alertTriangle,
              color: Color(0xFFDC2626),
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              "Error de conexión",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF991B1B),
              ),
            ),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
