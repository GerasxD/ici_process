import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/tool_model.dart';
import '../../services/tool_service.dart';

class ToolCatalogScreen extends StatefulWidget {
  final UserModel currentUser;
  const ToolCatalogScreen({super.key, required this.currentUser});

  @override
  State<ToolCatalogScreen> createState() => _ToolCatalogScreenState();
}

class _ToolCatalogScreenState extends State<ToolCatalogScreen> {
  final ToolService _toolService = ToolService();

  late Stream<List<ToolItem>> _toolsStream;

  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  
  String _selectedStatus = 'Disponible';
  bool _isUploading = false;

  final List<String> _statusOptions = [
    'Disponible',
    'En Uso',
    'Mantenimiento',
    'Extraviada'
  ];

  // Colores
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFFF59E0B);

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_tools');

  @override
  void initState() {
    super.initState();
    // Esto asegura que la conexión a Firebase se abra UNA SOLA VEZ
    _toolsStream = _toolService.getTools(); 
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disponible': return const Color(0xFF10B981); // Verde
      case 'En Uso': return const Color(0xFF3B82F6);     // Azul
      case 'Mantenimiento': return const Color(0xFFF59E0B); // Naranja
      case 'Extraviada': return const Color(0xFFEF4444);    // Rojo
      default: return _textSecondary;
    }
  }

  // --- NUEVO: ACTUALIZACIÓN RÁPIDA DE ESTADO ---
  Future<void> _quickUpdateStatus(ToolItem item, String newStatus) async {
    if (item.status == newStatus) return; // No hacer nada si es el mismo

    try {
      // Creamos una copia del objeto con el nuevo estado
      final updatedTool = ToolItem(
        id: item.id,
        name: item.name,
        brand: item.brand,
        serialNumber: item.serialNumber,
        status: newStatus,
      );

      await _toolService.updateTool(updatedTool);
      _showSnack("Estado actualizado a: $newStatus");
    } catch (e) {
      _showSnack("Error al actualizar estado", isSuccess: false);
    }
  }
  // ---------------------------------------------

  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    if (_nameCtrl.text.isEmpty || _brandCtrl.text.isEmpty) {
      _showSnack("Nombre y Marca son obligatorios", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      final tool = ToolItem(
        id: docId ?? '',
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim(),
        status: _selectedStatus,
      );

      if (docId == null) {
        await _toolService.addTool(tool);
        _resetForm();
        _showSnack("Herramienta registrada correctamente");
      } else {
        await _toolService.updateTool(tool);
        if (mounted) Navigator.pop(context);
        _showSnack("Herramienta actualizada");
      }
    } catch (e) {
      _showSnack("Error al guardar: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _brandCtrl.clear();
    _serialCtrl.clear();
    setState(() => _selectedStatus = 'Disponible');
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
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              
              StreamBuilder<List<ToolItem>>(
                stream: _toolsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final tools = snapshot.data ?? [];

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildList(tools)),
                        const SizedBox(width: 40),
                        if (canEdit) 
                           Expanded(flex: 4, child: _buildForm()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        if (canEdit) ...[_buildForm(), const SizedBox(height: 40)],
                        _buildList(tools),
                      ],
                    );
                  }
                },
              )
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
          child: Icon(LucideIcons.wrench, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Inventario de Herramientas", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
            Text("Control de equipo, estado y asignaciones.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildList(List<ToolItem> tools) {
    if (tools.isEmpty) return const Center(child: Text("Sin herramientas registradas"));
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => _buildCard(tools[index]),
    );
  }

  // --- TARJETA DE HERRAMIENTA CON CAMBIO RÁPIDO ---
  Widget _buildCard(ToolItem item) {
    Color statusColor = _getStatusColor(item.status);

    // Diseño del Badge (lo extraemos para reusarlo)
    Widget statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            item.status.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
          ),
          if (canEdit) ...[
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 12, color: statusColor)
          ]
        ],
      ),
    );

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.hammer, color: _accentColor, size: 24),
          ),
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
                const SizedBox(height: 4),
                Text("${item.brand}  •  Serie: ${item.serialNumber.isEmpty ? 'S/N' : item.serialNumber}", 
                  style: GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
                
                const SizedBox(height: 12),
                
                // --- AQUÍ ESTÁ LA MAGIA: POPUP MENU ---
                if (canEdit)
                  PopupMenuButton<String>(
                    tooltip: "Cambiar estado rápidamente",
                    offset: const Offset(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    initialValue: item.status,
                    onSelected: (newStatus) => _quickUpdateStatus(item, newStatus),
                    itemBuilder: (context) => _statusOptions.map((status) {
                      Color c = _getStatusColor(status);
                      return PopupMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            Icon(LucideIcons.circle, size: 10, color: c),
                            const SizedBox(width: 10),
                            Text(status, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: c)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: statusBadge, // Usamos el diseño del badge como botón
                  )
                else
                  statusBadge, // Si no puede editar, solo muestra el badge estático
                // --------------------------------------
              ],
            ),
          ),

          if (canEdit)
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.edit3, size: 20, color: Colors.blue),
                  onPressed: () => _showEditDialog(item),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            )
        ],
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
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(LucideIcons.plus, color: _primaryBlue, size: 20)),
              const SizedBox(width: 12),
              Text("Alta de Herramienta", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          _input(_nameCtrl, "Nombre de la Herramienta", LucideIcons.wrench),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _input(_brandCtrl, "Marca", LucideIcons.tag)),
              const SizedBox(width: 12),
              Expanded(child: _input(_serialCtrl, "No. Serie", LucideIcons.hash)),
            ],
          ),
          const SizedBox(height: 24),

          Text("ESTADO ACTUAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: _getStatusColor(status), shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(status, style: GoogleFonts.inter(fontSize: 14, color: _textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val!),
              ),
            ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : Text("Guardar Herramienta", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ToolItem item) {
    _nameCtrl.text = item.name;
    _brandCtrl.text = item.brand;
    _serialCtrl.text = item.serialNumber;
    
    String tempStatus = item.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              "Editar Herramienta", 
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary)
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, // Alineación a la izquierda
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                      child: Text("NOMBRE DE LA HERRAMIENTA", 
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                    ),
                    _input(_nameCtrl, "Ej. Taladro Percutor", LucideIcons.wrench),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                                child: Text("MARCA", 
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                              ),
                              _input(_brandCtrl, "Ej. DeWalt", LucideIcons.tag),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                                child: Text("NO. SERIE", 
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                              ),
                              _input(_serialCtrl, "Ej. SN-12345", LucideIcons.hash),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 2),
                      child: Text("ESTADO ACTUAL", 
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tempStatus,
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.grey),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _getStatusColor(status), shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Text(status, style: GoogleFonts.inter(fontSize: 14, color: _textPrimary)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            // La lógica intacta
                            setModalState(() => tempStatus = val!);
                            _selectedStatus = val!;
                          },
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
                onPressed: () { _resetForm(); Navigator.pop(ctx); }, 
                style: TextButton.styleFrom(foregroundColor: _textSecondary),
                child: Text("Cancelar", style: GoogleFonts.inter()),
              ),
              ElevatedButton(
                onPressed: _isUploading ? null : () {
                  // La lógica intacta
                  _selectedStatus = tempStatus; 
                  _handleSave(docId: item.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _isUploading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Guardar Cambios", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    ).then((_) => _resetForm());
  }

  void _confirmDelete(ToolItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Eliminar"),
      content: Text("¿Dar de baja '${item.name}'?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            _toolService.deleteTool(item.id);
            Navigator.pop(ctx);
            _showSnack("Herramienta dada de baja");
          }, 
          child: const Text("Dar de Baja")
        ),
      ],
    ));
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true, fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}