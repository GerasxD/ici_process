import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:ici_process/models/client_model.dart';
import 'package:ici_process/models/user_model.dart';
import 'package:ici_process/services/client_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
  // --- CONTROLADORES NUEVOS ---
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // Logo seleccionado
  Uint8List? _selectedLogoBytes;

  String _searchQuery = '';
  
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

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_clients');
  late Stream<List<Client>> _clientsStream;

  @override
  void initState() {
    super.initState();
    // 2. Inicialízalo solo una vez
    _clientsStream = _clientService.getClients();
  }

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

  List<Client> _applyFilter(List<Client> clients) {
    if (_searchQuery.isEmpty) return clients;
    final q = _searchQuery.toLowerCase();
    return clients.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.businessName.toLowerCase().contains(q) ||
      c.contactName.toLowerCase().contains(q) ||
      c.email.toLowerCase().contains(q) ||
      c.billingAddress.toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // ⭐ Importante para web: carga los bytes directamente
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          setState(() => _selectedLogoBytes = bytes);
        }
      }
    } catch (e) {
      _showSnack("No se pudo cargar la imagen", isSuccess: false);
    }
  }

  Future<void> _handleAdd() async {
    if (!canEdit) return;
    final name = _nameController.text.trim();
    final billing = _billingController.text.trim();
    final branches = _branchControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (name.isNotEmpty && billing.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        await _clientService.addClient(
          name: name,
          businessName: _businessNameController.text.trim(),
          contactName: _contactNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          billingAddress: billing,
          branchAddresses: branches,
          logoBytes: _selectedLogoBytes,
        );

        final oldBranchControllers = List<TextEditingController>.from(_branchControllers);

        _nameController.clear();
        _billingController.clear();
        _businessNameController.clear();
        _contactNameController.clear();
        _phoneController.clear();
        _emailController.clear();

        setState(() {
          _branchControllers = [TextEditingController()];
          _selectedLogoBytes = null;
        });

        for (var c in oldBranchControllers) { c.dispose(); }

        FocusScope.of(context).unfocus();
        if (mounted) _showSnack("Cliente registrado correctamente", isSuccess: true);
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
    _businessNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
                    stream: _clientsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allClients = snapshot.data ?? [];
                      final filtered = _applyFilter(allClients);

                      final listSection = Column(
                        children: [
                          _buildSearchBar(allClients.length),
                          const SizedBox(height: 20),
                          _buildListResults(filtered, allClients.length),
                        ],
                      );

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: listSection),
                            const SizedBox(width: 32),
                            if (canEdit) Expanded(flex: 4, child: _buildAddForm()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            if (canEdit) ...[_buildAddForm(), const SizedBox(height: 32)],
                            listSection,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.building2, color: _primaryBlue, size: 30),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Gestión de Clientes", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("Administra tu cartera, datos fiscales y sucursales.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

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
                hintText: "Buscar por nombre o dirección fiscal...",
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.building2, size: 16, color: _primaryBlue),
                const SizedBox(width: 8),
                Text("$totalCount", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _primaryBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListResults(List<Client> filtered, int totalCount) {
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
                _searchQuery.isNotEmpty ? LucideIcons.searchX : LucideIcons.building2,
                size: 44,
                color: const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty
                    ? "Sin resultados para \"$_searchQuery\""
                    : "Sin clientes registrados",
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
                ? "$totalCount cliente${totalCount == 1 ? '' : 's'}"
                : "${filtered.length} de $totalCount cliente${totalCount == 1 ? '' : 's'}",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _buildClientCard(filtered[index]),
        ),
      ],
    );
  }

  Widget _buildClientCard(Client client) {
    final initials = client.name.isNotEmpty
        ? client.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'C';

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: client.logoUrl.isNotEmpty
                ? Image.network(
                    client.logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackInitials(initials),
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlue),
                        ),
                      );
                    },
                  )
                : _fallbackInitials(initials),
          ),
          title: Text(client.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8.0, 
              runSpacing: 6.0, 
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.mapPin, size: 10, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180), 
                        child: Text(
                          client.billingAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (client.branchAddresses.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.store, size: 10, color: _primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          "${client.branchAddresses.length} sucursal${client.branchAddresses.length == 1 ? '' : 'es'}",
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryBlue),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit) ...[
                _buildActionIcon(LucideIcons.edit3, const Color(0xFF2563EB), () async {
                  final bool? updated = await showDialog(
                    context: context,
                    builder: (_) => _EditClientDialog(client: client, service: _clientService),
                  );
                  if (updated == true && mounted) {
                    _showSnack("Datos actualizados correctamente", isSuccess: true);
                  }
                }),
                const SizedBox(width: 4),
                _buildActionIcon(LucideIcons.trash2, const Color(0xFFEF4444), () => _confirmDelete(client)),
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
                  // --- INFO DE CONTACTO ---
                  if (client.businessName.isNotEmpty ||
                      client.contactName.isNotEmpty ||
                      client.phone.isNotEmpty ||
                      client.email.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(LucideIcons.fileText, size: 14, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Text("INFORMACIÓN DE CONTACTO",
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (client.businessName.isNotEmpty)
                      _buildInfoRow(LucideIcons.fileText, "Razón Social", client.businessName),
                    if (client.contactName.isNotEmpty)
                      _buildInfoRow(LucideIcons.user, "Contacto", client.contactName),
                    if (client.phone.isNotEmpty)
                      _buildInfoRow(LucideIcons.phone, "Teléfono", client.phone),
                    if (client.email.isNotEmpty)
                      _buildInfoRow(LucideIcons.mail, "Correo", client.email),
                    const SizedBox(height: 16),
                    Container(height: 1, color: _borderColor),
                    const SizedBox(height: 16),
                  ],
                  // Dirección fiscal
                  Row(
                    children: [
                      const Icon(LucideIcons.receipt, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Text("DIRECCIÓN FISCAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(client.billingAddress, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, height: 1.4)),

                  if (client.branchAddresses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(height: 1, color: _borderColor),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(LucideIcons.store, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Text("SUCURSALES (${client.branchAddresses.length})", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...client.branchAddresses.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: _primaryBlue, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(b, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary))),
                          ],
                        ),
                      ),
                    )),
                  ],

                  if (client.branchAddresses.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor, style: BorderStyle.solid),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.store, size: 14, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 8),
                          Text("Sin sucursales registradas", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _primaryBlue),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.3),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackInitials(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryBlue.withOpacity(0.12), _primaryBlue.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(color: _primaryBlue, fontWeight: FontWeight.w800, fontSize: 16),
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

  Widget _buildAddForm() {
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
          // ── Header con acento visual ──────────────────────────
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
                  child: Icon(Icons.add_business_rounded, color: _primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Nuevo Registro",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Completa los datos del cliente",
                      style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Cuerpo del formulario ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Sección: Información general
                _buildSectionLabel("Información General", Icons.info_outline_rounded),
                const SizedBox(height: 16),

                // --- SELECTOR DE LOGO ---
                Center(child: _buildLogoPicker()),
                const SizedBox(height: 20),

                _buildInputLabel("Nombre Comercial"),
                const SizedBox(height: 6),
                _buildModernTextField(_nameController, "Ej. Grupo Modelo", Icons.business_outlined),

                const SizedBox(height: 16),
                _buildInputLabel("Razón Social"),
                const SizedBox(height: 6),
                _buildModernTextField(_businessNameController, "Ej. Grupo Modelo S.A. de C.V.", Icons.description_outlined),

                const SizedBox(height: 28),
                _buildDivider(),
                const SizedBox(height: 24),

                // Sección: Contacto
                _buildSectionLabel("Datos de Contacto", Icons.person_outline_rounded),
                const SizedBox(height: 12),

                _buildInputLabel("Nombre del Contacto"),
                const SizedBox(height: 6),
                _buildModernTextField(_contactNameController, "Ej. Juan Pérez", Icons.person_outline),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputLabel("Teléfono"),
                          const SizedBox(height: 6),
                          _buildModernTextField(_phoneController, "449 123 4567", Icons.phone_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputLabel("Correo"),
                          const SizedBox(height: 6),
                          _buildModernTextField(_emailController, "correo@empresa.com", Icons.mail_outline),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                _buildDivider(),
                const SizedBox(height: 24),

                // Sección: Dirección
                _buildSectionLabel("Dirección Fiscal", Icons.location_on_outlined),
                const SizedBox(height: 12),
                _buildModernTextField(_billingController, "Calle, Número, Colonia, CP...", Icons.location_on_outlined),

                const SizedBox(height: 28),
                _buildDivider(),
                const SizedBox(height: 24),

                // Sección: Sucursales
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildSectionLabel("Sucursales Operativas", Icons.storefront_outlined),
                    ),
                    _buildAddBranchButton(),
                  ],
                ),
                const SizedBox(height: 14),

                ..._branchControllers.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        // Indicador numérico
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: _primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${entry.key + 1}",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildModernTextField(
                            entry.value,
                            "Nombre o dirección de sucursal",
                            Icons.storefront_outlined,
                            isDense: true,
                          ),
                        ),
                        if (_branchControllers.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Material(
                              color: const Color(0xFFEF4444).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => _removeBranchField(entry.key),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 32),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _handleAdd,
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
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Registrar Cliente",
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.2),
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
    );
  }

// ── Helpers de apoyo ──────────────────────────────────────────
Widget _buildLogoPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedLogoBytes != null ? _primaryBlue : _borderColor,
                width: _selectedLogoBytes != null ? 2 : 1.5,
                style: _selectedLogoBytes != null ? BorderStyle.solid : BorderStyle.solid,
              ),
              boxShadow: _selectedLogoBytes != null
                  ? [BoxShadow(color: _primaryBlue.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: _selectedLogoBytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_selectedLogoBytes!, fit: BoxFit.cover),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedLogoBytes = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.imagePlus, size: 28, color: _primaryBlue.withOpacity(0.7)),
                      const SizedBox(height: 6),
                      Text("Subir logo",
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textSecondary)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedLogoBytes != null ? "Toca para cambiar" : "Opcional · PNG o JPG",
          style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: _borderColor, thickness: 1, height: 1)),
      ],
    );
  }

  Widget _buildAddBranchButton() {
    return Material(
      color: _primaryBlue.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: _addBranchField,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 15, color: _primaryBlue),
              const SizedBox(width: 4),
              Text(
                "Agregar",
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryBlue),
              ),
            ],
          ),
        ),
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
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 460,
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(LucideIcons.trash2, color: Color(0xFFDC2626), size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Eliminar Cliente", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text("Se eliminará del directorio", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20), splashRadius: 20),
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
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(LucideIcons.building2, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(client.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (client.billingAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(client.billingAddress, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text("El cliente será eliminado permanentemente del directorio. Los procesos asociados no se verán afectados.", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500, height: 1.4)),
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
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                        child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          _clientService.deleteClient(client.id);
                          Navigator.pop(ctx);
                          _showSnack("Cliente eliminado correctamente");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            Text("Eliminar Cliente", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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
  late TextEditingController _businessCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  Uint8List? _newLogoBytes;
  bool _removeLogo = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client.name);
    _billingCtrl = TextEditingController(text: widget.client.billingAddress);
    _businessCtrl = TextEditingController(text: widget.client.businessName);
    _contactCtrl = TextEditingController(text: widget.client.contactName);
    _phoneCtrl = TextEditingController(text: widget.client.phone);
    _emailCtrl = TextEditingController(text: widget.client.email);

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
    _businessCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    for (var c in _branchCtrls) c.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty || _billingCtrl.text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final branches = _branchCtrls
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final updatedClient = Client(
        id: widget.client.id,
        name: _nameCtrl.text.trim(),
        businessName: _businessCtrl.text.trim(),
        contactName: _contactCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        logoUrl: _removeLogo ? '' : widget.client.logoUrl,
        billingAddress: _billingCtrl.text.trim(),
        branchAddresses: branches,
      );

      await widget.service.updateClient(
        updatedClient,
        newLogoBytes: _newLogoBytes,
        removeLogo: _removeLogo,
      );
      if (mounted) Navigator.pop(context, true);
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
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _newLogoBytes != null
                              ? Image.memory(_newLogoBytes!, fit: BoxFit.cover)
                              : (widget.client.logoUrl.isNotEmpty && !_removeLogo)
                                  ? Image.network(
                                      widget.client.logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          _nameCtrl.text.isNotEmpty
                                              ? _nameCtrl.text[0].toUpperCase()
                                              : 'C',
                                          style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Icon(LucideIcons.imagePlus,
                                          color: Colors.white70, size: 22),
                                    ),
                        ),
                      ),
                      // Botón eliminar logo (solo aparece si HAY logo activo)
                      if ((_newLogoBytes != null ||
                              (widget.client.logoUrl.isNotEmpty && !_removeLogo)))
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _newLogoBytes = null;
                              _removeLogo = true;
                            }),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(LucideIcons.x,
                                  size: 11, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Editar Cliente", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Text("Modifica los datos del cliente", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
                    Text("NOMBRE COMERCIAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _field(_nameCtrl, Icons.business, _inputFill),
                    const SizedBox(height: 20),
                    Text("DIRECCIÓN FISCAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _field(_billingCtrl, Icons.map, _inputFill),
                    const SizedBox(height: 24),

                    const SizedBox(height: 20),
                    Text("RAZÓN SOCIAL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _field(_businessCtrl, Icons.description_outlined, _inputFill),

                    const SizedBox(height: 20),
                    Text("CONTACTO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _field(_contactCtrl, Icons.person_outline, _inputFill),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TELÉFONO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              _field(_phoneCtrl, Icons.phone_outlined, _inputFill),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("CORREO", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              _field(_emailCtrl, Icons.mail_outline, _inputFill),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Sucursales header
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Text("SUCURSALES", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _branchCtrls.add(TextEditingController())),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _primaryBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _primaryBlue.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.plus, size: 14, color: _primaryBlue),
                                const SizedBox(width: 6),
                                Text("Agregar", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryBlue)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._branchCtrls.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _field(entry.value, Icons.storefront, Colors.transparent, isDense: true)),
                            if (_branchCtrls.length > 1)
                              IconButton(
                                icon: const Icon(LucideIcons.x, color: Color(0xFFEF4444), size: 16),
                                splashRadius: 16,
                                onPressed: () {
                                  setState(() {
                                    _branchCtrls[entry.key].dispose();
                                    _branchCtrls.removeAt(entry.key);
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    )),
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
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
                      child: Text("Cancelar", style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.save, size: 18),
                                const SizedBox(width: 8),
                                Text("Guardar Cambios", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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
    );
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          setState(() {
            _newLogoBytes = bytes;
            _removeLogo = false;
          });
        }
      }
    } catch (_) {}
  }

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