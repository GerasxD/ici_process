import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/company_settings_model.dart';
import '../../services/company_settings_service.dart';

class CompanyProfileScreen extends StatefulWidget {
  final UserModel currentUser;
  const CompanyProfileScreen({super.key, required this.currentUser});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final CompanySettingsService _service = CompanySettingsService();
  final ImagePicker _picker = ImagePicker();

  late CompanySettingsModel _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores
  final _nameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // ── PALETA (idéntica a WorkerManagementScreen) ──
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF0D9488); // Teal corporativo

  // Permiso: solo admins/managers pueden editar la empresa
  bool get canEdit =>
    PermissionManager().can(widget.currentUser, 'edit_company_profile');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _legalNameCtrl.dispose();
    _rfcCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = data;
        _nameCtrl.text = data.name;
        _legalNameCtrl.text = data.legalName;
        _rfcCtrl.text = data.rfc;
        _addressCtrl.text = data.address;
        _phoneCtrl.text = data.phone;
        _emailCtrl.text = data.email;
        _websiteCtrl.text = data.website;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando empresa: $e');
      if (mounted) {
        setState(() {
          _settings = CompanySettingsModel();
          _isLoading = false;
        });
        _showSnack("No se pudo cargar la información", isSuccess: false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!canEdit) return;
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack("El nombre comercial es obligatorio", isSuccess: false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      _settings.name = _nameCtrl.text.trim();
      _settings.legalName = _legalNameCtrl.text.trim();
      _settings.rfc = _rfcCtrl.text.trim().toUpperCase();
      _settings.address = _addressCtrl.text.trim();
      _settings.phone = _phoneCtrl.text.trim();
      _settings.email = _emailCtrl.text.trim();
      _settings.website = _websiteCtrl.text.trim();

      await _service.saveSettings(_settings);
      _showSnack("Información actualizada correctamente");
    } catch (e) {
      _showSnack("Error al guardar: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogoUpload() async {
    if (!canEdit) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        setState(() => _settings.logoUrl = base64Image);
      }
    } catch (e) {
      _showSnack("Error al cargar la imagen", isSuccess: false);
    }
  }

  void _handleRemoveLogo() {
    if (!canEdit) return;
    setState(() => _settings.logoUrl = '');
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgPage,
        body: Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );
    }

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
                _buildCompletionBanner(),
                const SizedBox(height: 24),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _buildFormCard()),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: _buildLogoCard()),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildLogoCard(),
                      const SizedBox(height: 24),
                      _buildFormCard(),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────
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
          child: Icon(LucideIcons.building2, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Perfil de la Empresa",
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Datos fiscales e identidad visual para tus reportes y documentos.",
                style: GoogleFonts.inter(fontSize: 15, color: _textSecondary),
              ),
            ],
          ),
        ),
        if (canEdit)
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.save, size: 18),
              label: Text(
                _isSaving ? "Guardando..." : "Guardar Cambios",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
      ],
    );
  }

  // ── BANNER DE COMPLETITUD ───────────────────────────────
  Widget _buildCompletionBanner() {
    final percent = _settings.completionPercentage;
    final isComplete = percent >= 1.0;
    final color = isComplete
        ? const Color(0xFF059669)
        : (percent >= 0.5 ? const Color(0xFFEA580C) : const Color(0xFFDC2626));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isComplete ? LucideIcons.badgeCheck : LucideIcons.alertCircle,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? "Perfil de empresa completo"
                      : "Completa el perfil de tu empresa",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isComplete
                      ? "Todos los datos básicos están registrados."
                      : "Estos datos aparecen en los encabezados de los reportes PDF.",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: _borderColor,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "${(percent * 100).toInt()}%",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── CARD DE FORMULARIO ──────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryBlue.withOpacity(0.08),
                  _primaryBlue.withOpacity(0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: _borderColor.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.fileSpreadsheet,
                    color: _primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Datos de la Organización",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Información fiscal y de contacto",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body del card
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!canEdit) _buildReadOnlyBanner(),
                if (!canEdit) const SizedBox(height: 20),

                // Datos Generales
                _buildSectionLabel("Datos Generales", LucideIcons.building),
                const SizedBox(height: 12),
                _buildLabel("NOMBRE COMERCIAL *"),
                const SizedBox(height: 6),
                _input(_nameCtrl, "Ej. ICI-PROCESS", LucideIcons.store),
                const SizedBox(height: 12),
                _buildLabel("RAZÓN SOCIAL"),
                const SizedBox(height: 6),
                _input(
                  _legalNameCtrl,
                  "Nombre legal completo de la empresa",
                  LucideIcons.gavel,
                ),
                const SizedBox(height: 12),
                _buildLabel("RFC"),
                const SizedBox(height: 6),
                _input(
                  _rfcCtrl,
                  "XAXX010101000",
                  LucideIcons.fingerprint,
                  uppercase: true,
                ),

                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),

                // Contacto
                _buildSectionLabel(
                  "Información de Contacto",
                  LucideIcons.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("TELÉFONO"),
                          const SizedBox(height: 6),
                          _input(
                            _phoneCtrl,
                            "(449) 123 4567",
                            LucideIcons.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("CORREO ELECTRÓNICO"),
                          const SizedBox(height: 6),
                          _input(
                            _emailCtrl,
                            "contacto@empresa.com",
                            LucideIcons.mail,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildLabel("SITIO WEB"),
                const SizedBox(height: 6),
                _input(_websiteCtrl, "https://www.empresa.com", LucideIcons.globe),

                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),

                // Domicilio
                _buildSectionLabel("Domicilio Fiscal", LucideIcons.mapPin),
                const SizedBox(height: 12),
                _input(
                  _addressCtrl,
                  "Calle, Número, Colonia, CP, Ciudad, Estado",
                  LucideIcons.mapPin,
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // Nota informativa
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFBAE6FD).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.info,
                        size: 14,
                        color: Color(0xFF0369A1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Los campos marcados con * son obligatorios. Esta información se mostrará en los PDF generados por el sistema.",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF0C4A6E),
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
        ],
      ),
    );
  }

  // ── CARD DE LOGO ────────────────────────────────────────
  Widget _buildLogoCard() {
    final hasLogo = _settings.logoUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentColor.withOpacity(0.08),
                  _accentColor.withOpacity(0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: _borderColor.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.image,
                    color: _accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Identidad Visual",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Logotipo de la empresa",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zona de imagen
                GestureDetector(
                  onTap: canEdit ? _handleLogoUpload : null,
                  child: Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasLogo
                            ? _borderColor
                            : _accentColor.withOpacity(0.3),
                        width: hasLogo ? 1 : 1.5,
                        style: hasLogo ? BorderStyle.solid : BorderStyle.solid,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (hasLogo)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: _settings.logoUrl.startsWith('http')
                                ? Image.network(
                                    _settings.logoUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        _buildLogoPlaceholder(),
                                  )
                                : Image.memory(
                                    base64Decode(_settings.logoUrl),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        _buildLogoPlaceholder(),
                                  ),
                          )
                        else
                          _buildLogoPlaceholder(),

                        // Botón cambiar (solo si hay logo y puede editar)
                        if (hasLogo && canEdit)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.refreshCw,
                                    size: 12,
                                    color: _textPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Cambiar",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Acciones del logo
                if (hasLogo && canEdit)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleLogoUpload,
                          icon: const Icon(LucideIcons.upload, size: 14),
                          label: Text(
                            "Subir otro",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryBlue,
                            side: BorderSide(
                              color: _primaryBlue.withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleRemoveLogo,
                          icon: const Icon(LucideIcons.trash2, size: 14),
                          label: Text(
                            "Quitar",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: BorderSide(
                              color: const Color(0xFFDC2626).withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                // Tip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _accentColor.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.lightbulb,
                        size: 14,
                        color: _accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Usa una imagen con fondo transparente (PNG) para mejores resultados en los reportes.",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _textPrimary,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            LucideIcons.uploadCloud,
            size: 30,
            color: _accentColor,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          canEdit ? "Subir Logotipo" : "Sin logotipo",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          canEdit
              ? "Haz clic para seleccionar una imagen"
              : "No tienes permisos para editar",
          style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
        ),
        if (canEdit) ...[
          const SizedBox(height: 6),
          Text(
            "PNG o JPG · Máx. 500KB",
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _textSecondary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.lock,
            size: 14,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Modo solo lectura. Contacta a un administrador para modificar estos datos.",
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFB45309),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS VISUALES ────────────────────────────────────
  Widget _buildSectionLabel(String text, IconData icon) {
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
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _borderColor.withOpacity(0),
            _borderColor,
            _borderColor.withOpacity(0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool uppercase = false,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      enabled: canEdit,
      textCapitalization:
          uppercase ? TextCapitalization.characters : TextCapitalization.none,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}