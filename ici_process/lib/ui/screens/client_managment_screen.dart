import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:ici_process/models/client_model.dart';
import 'package:ici_process/models/user_model.dart';
import 'package:ici_process/services/client_service.dart';

class ClientManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const ClientManagementScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  // --- CONTROLADORES (Lógica intacta) ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  List<TextEditingController> _branchControllers = [TextEditingController()];
  
  final ClientService _clientService = ClientService();
  bool _isUploading = false;

  // --- PALETA DE COLORES PROFESIONAL (Slate & Blue) ---
  final Color _bgPage = const Color(0xFFF8FAFC); // Slate 50
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A); // Slate 900
  final Color _textSecondary = const Color(0xFF64748B); // Slate 500
  final Color _borderColor = const Color(0xFFE2E8F0); // Slate 200
  final Color _primaryBlue = const Color(0xFF2563EB); // Blue 600
  final Color _inputFill = const Color(0xFFF1F5F9); // Slate 100

    bool get isAdmin =>
        widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.superAdmin;

  void _addBranchField() {
    setState(() => _branchControllers.add(TextEditingController()));
  }

  void _removeBranchField(int index) {
    if (_branchControllers.length > 1) {
      setState(() {
        _branchControllers[index].dispose();
        _branchControllers.removeAt(index);
      });
    }
  }

  Future<void> _handleAdd() async {
    final name = _nameController.text.trim();
    final billing = _billingController.text.trim();
    final branches = _branchControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (name.isNotEmpty && billing.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        await _clientService.addClient(name, billing, branches);
        
        _nameController.clear();
        _billingController.clear();
        for (var c in _branchControllers) { c.dispose(); }
        _branchControllers = [TextEditingController()];
        
        FocusScope.of(context).unfocus();
        if (mounted) {
          _showSnack("Cliente registrado correctamente", isSuccess: true);
        }
      } catch (e) {
        if (mounted) _showSnack("Error: $e", isSuccess: false);
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } else {
      _showSnack("Nombre y dirección son obligatorios", isSuccess: false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _billingController.dispose();
    for (var c in _branchControllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 1000;

          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  StreamBuilder<List<Client>>(
                    stream: _clientService.getClients(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final clients = snapshot.data ?? [];

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildClientList(clients)),
                            const SizedBox(width: 32),
                            if (isAdmin) 
                              Expanded(flex: 4, child: _buildAddForm()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            if (isAdmin) ...[_buildAddForm(), const SizedBox(height: 32)],
                            _buildClientList(clients),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(Icons.people_alt_rounded, color: _primaryBlue, size: 28),
        ),
        const SizedBox(width: 16),
        
        // --- CORRECCIÓN: Usamos Expanded ---
        Expanded( 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Gestión de Clientes",
                style: GoogleFonts.inter(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: _textPrimary, 
                  letterSpacing: -0.5
                ),
                // Asegura que si es muy largo, baje de línea
                softWrap: true, 
              ),
              Text(
                "Administra tu cartera, datos fiscales y sucursales.",
                style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
                softWrap: true,
                maxLines: 2, // Limite opcional para mantener el diseño limpio
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientList(List<Client> clients) {
    if (clients.isEmpty) return _buildEmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("CLIENTES REGISTRADOS (${clients.length})", 
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final client = clients[index];
            return _buildClientCard(client);
          },
        ),
      ],
    );
  }

  Widget _buildClientCard(Client client) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: CircleAvatar(
            backgroundColor: _primaryBlue.withOpacity(0.1),
            child: Text(
              client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
              style: GoogleFonts.inter(color: _primaryBlue, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(client.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _textPrimary, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 14, color: _textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    client.billingAddress, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                  ),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min, // Importante para que no ocupe todo el ancho
            children: [
              // BOTÓN EDITAR (Visible para todos o solo admins, como prefieras)
              if (isAdmin) 
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 20, color: Colors.blue[300]),
                  tooltip: "Editar Cliente",
                  onPressed: () async {
                    // Abrir el modal de edición
                    final bool? updated = await showDialog(
                      context: context,
                      builder: (_) => _EditClientDialog(client: client, service: _clientService),
                    );
                    
                    if (updated == true && mounted) {
                      _showSnack("Datos actualizados correctamente", isSuccess: true);
                    }
                  },
                ),
              
              // BOTÓN BORRAR
              if (isAdmin) 
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red[300]),
                  onPressed: () => _confirmDelete(client),
                  tooltip: "Eliminar Cliente",
                ) 
              else 
                const Icon(Icons.expand_more_rounded),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgPage,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store_rounded, size: 16, color: _textSecondary),
                      const SizedBox(width: 8),
                      Text("SUCURSALES REGISTRADAS", 
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (client.branchAddresses.isEmpty)
                    Text("Sin sucursales registradas.", style: GoogleFonts.inter(fontSize: 13, color: _textSecondary, fontStyle: FontStyle.italic)),
                  
                  ...client.branchAddresses.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(Icons.circle, size: 6, color: _primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(b, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary))),
                      ],
                    ),
                  )),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_business_rounded, color: _primaryBlue, size: 22),
              const SizedBox(width: 10),
              Text("Nuevo Registro", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildInputLabel("Nombre Comercial / Razón Social"),
          _buildModernTextField(_nameController, "Ej. Grupo Modelo S.A. de C.V.", Icons.business),
          
          const SizedBox(height: 16),
          _buildInputLabel("Dirección Fiscal"),
          _buildModernTextField(_billingController, "Calle, Número, Colonia, CP...", Icons.map),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInputLabel("Sucursales Operativas"),
              InkWell(
                onTap: _addBranchField,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, size: 16, color: _primaryBlue),
                      const SizedBox(width: 4),
                      Text("Agregar", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBlue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          ..._branchControllers.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernTextField(entry.value, "Nombre o Dirección de sucursal", Icons.storefront_outlined, isDense: true),
                  ),
                  if (_branchControllers.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444)),
                        onPressed: () => _removeBranchField(entry.key),
                        tooltip: "Quitar fila",
                      ),
                    )
                ],
              ),
            );
          }).toList(),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _handleAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("Registrar Cliente", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE DISEÑO ---

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 2),
      child: Text(label.toUpperCase(), 
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon, {bool isDense = false}) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: _inputFill,
        contentPadding: EdgeInsets.symmetric(vertical: isDense ? 12 : 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), 
          borderSide: BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No hay clientes registrados", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textSecondary)),
            const SizedBox(height: 8),
            Text("Utiliza el formulario para añadir tu primer cliente.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
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
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 32),
            const SizedBox(height: 12),
            Text("Ocurrió un error al cargar", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
            Text(error, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C))),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Client client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text("Eliminar Cliente", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Estás seguro de borrar a '${client.name}'?\nEsta acción no se puede deshacer.", style: GoogleFonts.inter()),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () { _clientService.deleteClient(client.id); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }
}

// --- NUEVO WIDGET: DIÁLOGO DE EDICIÓN ---
class _EditClientDialog extends StatefulWidget {
  final Client client;
  final ClientService service;

  const _EditClientDialog({required this.client, required this.service});

  @override
  State<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<_EditClientDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _billingCtrl;
  late List<TextEditingController> _branchCtrls;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 1. Precargar datos existentes
    _nameCtrl = TextEditingController(text: widget.client.name);
    _billingCtrl = TextEditingController(text: widget.client.billingAddress);
    
    // Precargar sucursales (si no hay, ponemos una vacía)
    if (widget.client.branchAddresses.isEmpty) {
      _branchCtrls = [TextEditingController()];
    } else {
      _branchCtrls = widget.client.branchAddresses
          .map((b) => TextEditingController(text: b))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _billingCtrl.dispose();
    for (var c in _branchCtrls) c.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty || _billingCtrl.text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // Recolectar sucursales limpias
      final branches = _branchCtrls
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Crear objeto actualizado manteniendo el mismo ID
      final updatedClient = Client(
        id: widget.client.id,
        name: _nameCtrl.text.trim(),
        billingAddress: _billingCtrl.text.trim(),
        branchAddresses: branches,
      );

      await widget.service.updateClient(updatedClient);
      if (mounted) Navigator.pop(context, true); // Retornar true si fue exitoso
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reutilizamos tu paleta de colores
    final Color _primaryBlue = const Color(0xFF2563EB);
    final Color _inputFill = const Color(0xFFF1F5F9); 
    final Color _textPrimary = const Color(0xFF0F172A);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text("Editar Cliente", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary)),
      content: SizedBox(
        width: 500, // Ancho fijo para desktop
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Nombre Comercial"),
              _field(_nameCtrl, Icons.business, _inputFill),
              const SizedBox(height: 16),
              _label("Dirección Fiscal"),
              _field(_billingCtrl, Icons.map, _inputFill),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label("Sucursales"),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: _primaryBlue),
                    onPressed: () => setState(() => _branchCtrls.add(TextEditingController())),
                    tooltip: "Agregar sucursal",
                  )
                ],
              ),
              ..._branchCtrls.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(child: _field(entry.value, Icons.storefront, _inputFill, isDense: true)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () {
                        if (_branchCtrls.length > 1) {
                          setState(() {
                            _branchCtrls[entry.key].dispose();
                            _branchCtrls.removeAt(entry.key);
                          });
                        }
                      },
                    )
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: GoogleFonts.inter(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text("Guardar Cambios", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
  );

  Widget _field(TextEditingController ctrl, IconData icon, Color fill, {bool isDense = false}) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        contentPadding: EdgeInsets.symmetric(vertical: isDense ? 10 : 14, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}