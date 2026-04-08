import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/vehicle_model.dart';
import '../../services/vehicle_service.dart';

class VehicleManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  const VehicleManagementScreen({super.key, required this.currentUser});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final VehicleService _vehicleService = VehicleService();
  late Stream<List<Vehicle>> _vehiclesStream;

  final _modelCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _platesCtrl = TextEditingController();
  final _kmLiterCtrl = TextEditingController();
  final _costKmCtrl = TextEditingController();
  final _gasPriceCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _searchQuery = '';
  bool _isUploading = false;

  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF0369A1);

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_vehicles');

  @override
  void initState() {
    super.initState();
    _vehiclesStream = _vehicleService.getVehicles();
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _kmLiterCtrl.dispose();
    _costKmCtrl.dispose();
    _gasPriceCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Vehicle> _applyFilter(List<Vehicle> vehicles) {
    if (_searchQuery.isEmpty) return vehicles;
    final q = _searchQuery.toLowerCase();
    return vehicles.where((v) => v.model.toLowerCase().contains(q)).toList();
  }

  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    if (_modelCtrl.text.isEmpty) {
      _showSnack("El modelo es obligatorio", isSuccess: false);
      return;
    }
    if (_kmLiterCtrl.text.isEmpty || _costKmCtrl.text.isEmpty || _gasPriceCtrl.text.isEmpty) {
      _showSnack("Todos los campos numéricos son obligatorios", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final vehicle = Vehicle(
        id: docId ?? '',
        model: _modelCtrl.text.trim(),
        kmPerLiter: double.tryParse(_kmLiterCtrl.text) ?? 0.0,
        costPerKm: double.tryParse(_costKmCtrl.text) ?? 0.0,
        gasPrice: double.tryParse(_gasPriceCtrl.text) ?? 0.0,
      );

      if (docId == null) {
        await _vehicleService.addVehicle(vehicle);
        _resetForm();
        _showSnack("Vehículo registrado correctamente");
      } else {
        await _vehicleService.updateVehicle(vehicle);
        if (mounted) Navigator.pop(context);
        _showSnack("Vehículo actualizado");
      }
    } catch (e) {
      _showSnack("Error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _modelCtrl.clear();
    _brandCtrl.clear();
    _platesCtrl.clear();
    _kmLiterCtrl.clear();
    _costKmCtrl.clear();
    _gasPriceCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isSuccess ? LucideIcons.checkCircle2 : LucideIcons.alertOctagon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
      backgroundColor: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
              const SizedBox(height: 32),
              StreamBuilder<List<Vehicle>>(
                stream: _vehiclesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allVehicles = snapshot.data ?? [];
                  final filtered = _applyFilter(allVehicles);

                  final listSection = Column(
                    children: [
                      _buildSearchBar(allVehicles.length),
                      const SizedBox(height: 20),
                      _buildListResults(filtered, allVehicles.length),
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
              ),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.truck, color: _accentColor, size: 30),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Gestión de Vehículos", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("Administra tu flota y costos operativos.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ── BÚSQUEDA ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(int totalCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
              decoration: InputDecoration(
                hintText: "Buscar por modelo, marca o placas...",
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                      )
                    : null,
                filled: true,
                fillColor: _inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Contador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.truck, size: 16, color: _accentColor),
                const SizedBox(width: 8),
                Text("$totalCount", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _accentColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── RESULTADOS ───────────────────────────────────────────────────────────

  Widget _buildListResults(List<Vehicle> filtered, int totalCount) {
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
                _searchQuery.isNotEmpty ? LucideIcons.searchX : LucideIcons.truck,
                size: 44,
                color: const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty
                    ? "Sin resultados para \"$_searchQuery\""
                    : "Sin vehículos registrados",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                  icon: Icon(LucideIcons.rotateCcw, size: 14, color: _primaryBlue),
                  label: Text("Limpiar búsqueda", style: GoogleFonts.inter(fontSize: 13, color: _primaryBlue, fontWeight: FontWeight.w600)),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            filtered.length == totalCount
                ? "$totalCount vehículo${totalCount == 1 ? '' : 's'}"
                : "${filtered.length} de $totalCount vehículo${totalCount == 1 ? '' : 's'}",
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

  // ── TARJETA DE VEHÍCULO ──────────────────────────────────────────────────

  Widget _buildCard(Vehicle item) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor.withOpacity(0.1), _accentColor.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accentColor.withOpacity(0.15)),
                ),
                child: Icon(LucideIcons.truck, color: _accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.model,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: _textPrimary),
                ),
              ),
              if (canEdit)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(LucideIcons.edit3, const Color(0xFF2563EB), () => _showEditDialog(item)),
                    const SizedBox(width: 4),
                    _buildActionIcon(LucideIcons.trash2, const Color(0xFFEF4444), () => _confirmDelete(item)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricChip(LucideIcons.gauge, "KM/L", item.kmPerLiter.toStringAsFixed(1), const Color(0xFF059669)),
              const SizedBox(width: 12),
              _buildMetricChip(LucideIcons.dollarSign, "Costo/KM", "\$${item.costPerKm.toStringAsFixed(2)}", const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              _buildMetricChip(LucideIcons.fuel, "\$/L Gas", "\$${item.gasPrice.toStringAsFixed(2)}", const Color(0xFFB45309)),
            ],
          ),
        ],
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

  Widget _buildMetricChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.7), letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  // ── FORMULARIO ───────────────────────────────────────────────────────────
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

          // ── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.truck, color: _primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nuevo Vehículo",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text("Completa los datos del vehículo",
                        style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ),

          // ── Cuerpo ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Sección: Modelo
                Row(children: [
                  Icon(LucideIcons.truck, size: 14, color: _textSecondary),
                  const SizedBox(width: 6),
                  Text("MODELO", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 12),
                _input(_modelCtrl, "Ej. Nissan NP300", LucideIcons.truck),

                const SizedBox(height: 24),
                Divider(color: _borderColor, thickness: 1, height: 1),
                const SizedBox(height: 20),

                // Sección: Rendimiento y Costos
                Row(children: [
                  Icon(LucideIcons.gauge, size: 14, color: _textSecondary),
                  const SizedBox(width: 6),
                  Text("RENDIMIENTO Y COSTOS", style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("KM/L", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.6)),
                          const SizedBox(height: 6),
                          _numericInput(_kmLiterCtrl, "0.0", LucideIcons.gauge),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("COSTO/KM", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.6)),
                          const SizedBox(height: 6),
                          _numericInput(_costKmCtrl, "\$0.0", LucideIcons.dollarSign),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("\$/L GAS", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.6)),
                          const SizedBox(height: 6),
                          _numericInput(_gasPriceCtrl, "\$0.0", LucideIcons.fuel),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : () => _handleSave(docId: null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primaryBlue.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ).copyWith(
                      overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.checkCircle, size: 18),
                              const SizedBox(width: 8),
                              Text("Registrar Vehículo",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.2)),
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

  // ── DIÁLOGOS (se mantienen igual) ────────────────────────────────────────
  void _showEditDialog(Vehicle item) {
    _modelCtrl.text = item.model;
    _kmLiterCtrl.text = item.kmPerLiter.toString();
    _costKmCtrl.text = item.costPerKm.toString();
    _gasPriceCtrl.text = item.gasPrice.toString();

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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                    child: Row(children: [
                      Container(width: 52, height: 52, decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]), child: const Center(child: Icon(LucideIcons.truck, color: Colors.white, size: 24))),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Editar Vehículo", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Text(item.model, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      IconButton(onPressed: () { _resetForm(); Navigator.pop(ctx); }, icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20), splashRadius: 20),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("MODELO DEL VEHÍCULO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        _input(_modelCtrl, "Ej. Nissan NP300", LucideIcons.truck),
                        const SizedBox(height: 24),
                        Row(children: [const Icon(LucideIcons.gauge, size: 14, color: Color(0xFF94A3B8)), const SizedBox(width: 8), Text("RENDIMIENTO Y COSTOS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8))]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("KM/L", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)), const SizedBox(height: 6), _numericInput(_kmLiterCtrl, "0.0", LucideIcons.gauge)])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("COSTO/KM", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)), const SizedBox(height: 6), _numericInput(_costKmCtrl, "0.0", LucideIcons.dollarSign)])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("\$/L GAS", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)), const SizedBox(height: 6), _numericInput(_gasPriceCtrl, "0.0", LucideIcons.fuel)])),
                        ]),
                      ]),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(children: [
                      Expanded(child: TextButton(onPressed: () { _resetForm(); Navigator.pop(ctx); }, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))), child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)))),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: ElevatedButton(
                        onPressed: _isUploading ? null : () => _handleSave(docId: item.id),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.save, size: 18), const SizedBox(width: 8), Text("Guardar Cambios", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14))]),
                      )),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => _resetForm());
  }

  void _confirmDelete(Vehicle item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 460,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.trash2, color: Color(0xFFDC2626), size: 26)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Eliminar Vehículo", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text("Esta acción no se puede deshacer", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20), splashRadius: 20),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.truck, size: 16, color: Color(0xFF64748B))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.model, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Expanded(child: Text("El vehículo será eliminado permanentemente del inventario junto con su historial.", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500, height: 1.4))),
                    ]),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))), child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    onPressed: () { _vehicleService.deleteVehicle(item.id); Navigator.pop(ctx); _showSnack("Vehículo eliminado correctamente"); },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.trash2, size: 18), const SizedBox(width: 8), Text("Eliminar Vehículo", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14))]),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS UI ───────────────────────────────────────────────────────────

  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
      ),
    );
  }

  Widget _numericInput(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryBlue, width: 1.5)),
      ),
    );
  }
}