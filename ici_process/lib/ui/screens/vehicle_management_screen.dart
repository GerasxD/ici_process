import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart'; // Para el filtrado de input numérico
import '../../models/user_model.dart';
import '../../models/vehicle_model.dart';
import '../../services/vehicle_service.dart';

class VehicleManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  const VehicleManagementScreen({super.key, required this.currentUser});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final VehicleService _vehicleService = VehicleService();

  // 1. Declarar la variable para guardar (cachear) el Stream
  late Stream<List<Vehicle>> _vehiclesStream;

  // Controladores
  final _modelCtrl = TextEditingController();
  final _kmLiterCtrl = TextEditingController();
  final _costKmCtrl = TextEditingController();
  final _gasPriceCtrl = TextEditingController();

  bool _isUploading = false;

  // Estilos
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);

  bool get canEdit =>
      PermissionManager().can(widget.currentUser, 'edit_vehicles');

  @override
  void initState() {
    super.initState();
    // 2. Inicializar el Stream una sola vez cuando se crea la pantalla
    _vehiclesStream = _vehicleService.getVehicles();
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _kmLiterCtrl.dispose();
    _costKmCtrl.dispose();
    _gasPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    if (_modelCtrl.text.isEmpty) {
      _showSnack("El modelo es obligatorio", isSuccess: false);
      return;
    }
    // Validar que los campos numéricos no estén vacíos (pueden ser 0, pero no vacíos)
    if (_kmLiterCtrl.text.isEmpty ||
        _costKmCtrl.text.isEmpty ||
        _gasPriceCtrl.text.isEmpty) {
      _showSnack(
        "Todos los campos numéricos son obligatorios",
        isSuccess: false,
      );
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
    _kmLiterCtrl.clear();
    _costKmCtrl.clear();
    _gasPriceCtrl.clear();
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 40),

                StreamBuilder<List<Vehicle>>(
                  // 3. Usar la variable cacheada en lugar de llamar a la función
                  stream: _vehiclesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return Text("Error: ${snapshot.error}");
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final vehicles = snapshot.data ?? [];

                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildList(vehicles)),
                          const SizedBox(width: 40),
                          // 3. OCULTAR FORMULARIO (DESKTOP)
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
                          _buildList(vehicles),
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
                color: _primaryBlue.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.truck, color: _primaryBlue, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Gestión de Vehículos",
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Administra tu flota y costos operativos.",
              style: GoogleFonts.inter(fontSize: 15, color: _textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // --- LISTADO ---
  Widget _buildList(List<Vehicle> vehicles) {
    if (vehicles.isEmpty)
      return const Center(child: Text("Sin vehículos registrados"));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => _buildCard(vehicles[index]),
    );
  }

  Widget _buildCard(Vehicle item) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono del camión (Igual a la imagen)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Color de fondo claro
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                LucideIcons.truck,
                color: Color(0xFF2563EB),
                size: 32,
              ), // Icono azul
            ),
          ),
          const SizedBox(width: 24),

          // Información del Vehículo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MODELO",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.model,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Fila de Datos Numéricos
                Row(
                  children: [
                    _buildDataColumn(
                      "KM/L",
                      item.kmPerLiter.toStringAsFixed(1),
                    ),
                    const SizedBox(width: 32),
                    _buildDataColumn(
                      "COST/KM",
                      "\$${item.costPerKm.toStringAsFixed(2)}",
                    ),
                    const SizedBox(width: 32),
                    _buildDataColumn(
                      "\$/L GAS",
                      "\$${item.gasPrice.toStringAsFixed(2)}",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botones de Acción
          if (canEdit)
            Column(
              children: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.edit3,
                    size: 20,
                    color: Colors.blue,
                  ),
                  onPressed: () => _showEditDialog(item),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 20,
                    color: Colors.red,
                  ),
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDataColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  // --- FORMULARIO ---
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.plus, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "Nuevo Vehículo",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _input(_modelCtrl, "Modelo del Vehículo", LucideIcons.truck),
          const SizedBox(height: 16),

          // Inputs numéricos en fila
          Row(
            children: [
              Expanded(
                child: _numericInput(_kmLiterCtrl, "KM/L", LucideIcons.gauge),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numericInput(
                  _costKmCtrl,
                  "Cost/KM",
                  LucideIcons.dollarSign,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numericInput(
                  _gasPriceCtrl,
                  "\$/L Gas",
                  LucideIcons.fuel,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : () => _handleSave(docId: null),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(
                      "Guardar Vehículo",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGOS ---
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          decoration: BoxDecoration(color: const Color(0xFF0369A1), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF0369A1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                          child: const Center(child: Icon(LucideIcons.truck, color: Colors.white, size: 24)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Editar Vehículo", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text(item.model, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () { _resetForm(); Navigator.pop(ctx); }, icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20), splashRadius: 20),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("MODELO DEL VEHÍCULO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          _input(_modelCtrl, "Ej. Nissan NP300", LucideIcons.truck),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(LucideIcons.gauge, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Text("RENDIMIENTO Y COSTOS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text("KM/L", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  _numericInput(_kmLiterCtrl, "0.0", LucideIcons.gauge),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text("COSTO/KM", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  _numericInput(_costKmCtrl, "0.0", LucideIcons.dollarSign),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text("\$/L GAS", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  _numericInput(_gasPriceCtrl, "0.0", LucideIcons.fuel),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () { _resetForm(); Navigator.pop(ctx); },
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                            child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : () => _handleSave(docId: item.id),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: _isUploading
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
                            "Eliminar Vehículo",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Esta acción no se puede deshacer",
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.truck,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.model,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.model,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
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
                              "El vehículo será eliminado permanentemente del inventario junto con su historial.",
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
                          _vehicleService.deleteVehicle(item.id);
                          Navigator.pop(ctx);
                          _showSnack("Vehículo eliminado correctamente");
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
                              "Eliminar Vehículo",
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

  // --- HELPERS UI ---
  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Widget especial para inputs numéricos con filtro
  Widget _numericInput(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^\d+\.?\d{0,2}'),
        ), // Solo números y un punto
      ],
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
