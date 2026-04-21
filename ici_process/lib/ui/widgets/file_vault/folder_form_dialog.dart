import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/file_vault_model.dart';
import '../../../models/user_model.dart';

/// Resultado devuelto por el diálogo
class FolderFormResult {
  final String name;
  final String colorHex;
  final String iconName;
  final List<String> viewRoles;
  final List<String> uploadRoles;
  final List<String> deleteRoles;

  FolderFormResult({
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.viewRoles,
    required this.uploadRoles,
    required this.deleteRoles,
  });
}

class FolderFormDialog extends StatefulWidget {
  final UserModel currentUser;
  final VaultFolder? parentFolder;    // null si es raíz
  final VaultFolder? folderToEdit;    // null si es creación

  const FolderFormDialog({
    super.key,
    required this.currentUser,
    this.parentFolder,
    this.folderToEdit,
  });

  @override
  State<FolderFormDialog> createState() => _FolderFormDialogState();
}

class _FolderFormDialogState extends State<FolderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  late String _colorHex;
  late String _iconName;

  late Set<String> _viewRoles;
  late Set<String> _uploadRoles;
  late Set<String> _deleteRoles;

  bool get isEditing => widget.folderToEdit != null;

  // Colores predefinidos
  final List<String> _colors = const [
    '0xFF2563EB', // azul
    '0xFF7C3AED', // violeta
    '0xFF0D9488', // teal
    '0xFF059669', // verde
    '0xFFEA580C', // naranja
    '0xFFDC2626', // rojo
    '0xFFB45309', // ámbar
    '0xFF64748B', // slate
  ];

  // Íconos predefinidos
  final List<Map<String, dynamic>> _icons = [
    {'name': 'folder', 'icon': LucideIcons.folder, 'label': 'General'},
    {'name': 'briefcase', 'icon': LucideIcons.briefcase, 'label': 'Negocios'},
    {'name': 'fileText', 'icon': LucideIcons.fileText, 'label': 'Docs'},
    {'name': 'banknote', 'icon': LucideIcons.banknote, 'label': 'Finanzas'},
    {'name': 'users', 'icon': LucideIcons.users, 'label': 'RRHH'},
    {'name': 'wrench', 'icon': LucideIcons.wrench, 'label': 'Operativo'},
    {'name': 'shield', 'icon': LucideIcons.shield, 'label': 'Legal'},
    {'name': 'star', 'icon': LucideIcons.star, 'label': 'Destacado'},
    {'name': 'archive', 'icon': LucideIcons.archive, 'label': 'Archivo'},
  ];

  // Todos los roles del sistema con su config visual
  List<Map<String, dynamic>> get _availableRoles => UserRole.values.map((r) {
        return {
          'name': r.name,
          'label': _labelForRole(r),
          'color': _colorForRole(r),
          'icon': _iconForRole(r),
        };
      }).toList();

  String _labelForRole(UserRole r) {
    switch (r) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Administrador';
      case UserRole.manager:
        return 'Gerente';
      case UserRole.technician:
        return 'Técnico';
      case UserRole.purchasing:
        return 'Compras';
      case UserRole.accountant:
        return 'Contador';
    }
  }

  Color _colorForRole(UserRole r) {
    switch (r) {
      case UserRole.superAdmin:
        return const Color(0xFF312E81);
      case UserRole.admin:
        return const Color(0xFF1E40AF);
      case UserRole.manager:
        return const Color(0xFF0369A1);
      case UserRole.technician:
        return const Color(0xFF0D9488);
      case UserRole.purchasing:
        return const Color(0xFFB45309);
      case UserRole.accountant:
        return const Color(0xFF059669);
    }
  }

  IconData _iconForRole(UserRole r) {
    switch (r) {
      case UserRole.superAdmin:
        return LucideIcons.shieldAlert;
      case UserRole.admin:
        return LucideIcons.shield;
      case UserRole.manager:
        return LucideIcons.briefcase;
      case UserRole.technician:
        return LucideIcons.wrench;
      case UserRole.purchasing:
        return LucideIcons.shoppingCart;
      case UserRole.accountant:
        return LucideIcons.dollarSign;
    }
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final f = widget.folderToEdit!;
      _nameCtrl.text = f.name;
      _colorHex = f.colorHex;
      _iconName = f.iconName;
      _viewRoles = f.viewRoles.toSet();
      _uploadRoles = f.uploadRoles.toSet();
      _deleteRoles = f.deleteRoles.toSet();
    } else {
      _colorHex = widget.parentFolder?.colorHex ?? '0xFF2563EB';
      _iconName = 'folder';
      // Sugerir heredando del padre
      _viewRoles = {...?widget.parentFolder?.viewRoles};
      _uploadRoles = {...?widget.parentFolder?.uploadRoles};
      _deleteRoles = {...?widget.parentFolder?.deleteRoles};

      // Por seguridad: si es raíz, preseleccionamos admin+superAdmin
      if (widget.parentFolder == null && _viewRoles.isEmpty) {
        _viewRoles = {'superAdmin', 'admin'};
        _uploadRoles = {'superAdmin', 'admin'};
        _deleteRoles = {'superAdmin', 'admin'};
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      FolderFormResult(
        name: _nameCtrl.text.trim(),
        colorHex: _colorHex,
        iconName: _iconName,
        viewRoles: _viewRoles.toList(),
        uploadRoles: _uploadRoles.toList(),
        deleteRoles: _deleteRoles.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Color(int.parse(_colorHex));
    final iconData = _icons
        .firstWhere((i) => i['name'] == _iconName,
            orElse: () => _icons[0])['icon'] as IconData;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: iconColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(iconData, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEditing ? "Editar Carpeta" : "Nueva Carpeta",
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(
                              widget.parentFolder == null
                                  ? (isEditing
                                      ? "Configura datos y permisos"
                                      : "Carpeta raíz del almacén")
                                  : "Dentro de: ${widget.parentFolder!.name}",
                              style: GoogleFonts.inter(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x,
                          color: Colors.white38, size: 20),
                    ),
                  ],
                ),
              ),

              // ── Contenido ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("NOMBRE DE LA CARPETA"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Obligatorio" : null,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF0F172A)),
                        decoration: _inputDecoration(
                            hint: "Ej. Contratos 2024",
                            icon: LucideIcons.folder),
                      ),

                      const SizedBox(height: 22),
                      _label("COLOR DEL ÍCONO"),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _colors.map((hex) {
                          final c = Color(int.parse(hex));
                          final selected = hex == _colorHex;
                          return GestureDetector(
                            onTap: () => setState(() => _colorHex = hex),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: selected
                                        ? const Color(0xFF0F172A)
                                        : Colors.transparent,
                                    width: 3),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                            color: c.withOpacity(0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4))
                                      ]
                                    : [],
                              ),
                              child: selected
                                  ? const Icon(LucideIcons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),
                      _label("ÍCONO"),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _icons.map((i) {
                          final selected = _iconName == i['name'];
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _iconName = i['name'] as String),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? iconColor.withOpacity(0.1)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: selected
                                        ? iconColor
                                        : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(i['icon'] as IconData,
                                      size: 15,
                                      color: selected
                                          ? iconColor
                                          : const Color(0xFF64748B)),
                                  const SizedBox(width: 7),
                                  Text(i['label'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? iconColor
                                              : const Color(0xFF475569))),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 28),

                      // ── Permisos ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(LucideIcons.lock,
                                  size: 15, color: Color(0xFF0F172A)),
                              const SizedBox(width: 8),
                              Text("Permisos por Rol",
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A))),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                "Define qué roles pueden ver, subir y eliminar dentro de esta carpeta. Super Admin siempre tiene acceso total.",
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    height: 1.4)),
                            const SizedBox(height: 14),

                            _permissionSection(
                              label: "PUEDEN VER",
                              icon: LucideIcons.eye,
                              selected: _viewRoles,
                              color: const Color(0xFF2563EB),
                              onChange: (set) {
                                setState(() {
                                  _viewRoles = set;
                                  // Si alguien no puede ver, tampoco puede subir/eliminar
                                  _uploadRoles
                                      .retainWhere((r) => _viewRoles.contains(r));
                                  _deleteRoles
                                      .retainWhere((r) => _viewRoles.contains(r));
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            _permissionSection(
                              label: "PUEDEN SUBIR",
                              icon: LucideIcons.upload,
                              selected: _uploadRoles,
                              color: const Color(0xFF059669),
                              disabledRoles:
                                  _availableRoles // los que NO están en _viewRoles
                                      .where((r) =>
                                          !_viewRoles.contains(r['name']))
                                      .map((r) => r['name'] as String)
                                      .toSet(),
                              onChange: (set) =>
                                  setState(() => _uploadRoles = set),
                            ),
                            const SizedBox(height: 14),
                            _permissionSection(
                              label: "PUEDEN ELIMINAR",
                              icon: LucideIcons.trash2,
                              selected: _deleteRoles,
                              color: const Color(0xFFDC2626),
                              disabledRoles: _availableRoles
                                  .where(
                                      (r) => !_viewRoles.contains(r['name']))
                                  .map((r) => r['name'] as String)
                                  .toSet(),
                              onChange: (set) =>
                                  setState(() => _deleteRoles = set),
                            ),

                            if (_viewRoles.isEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(children: [
                                  const Icon(LucideIcons.alertCircle,
                                      size: 13, color: Color(0xFFB45309)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        "Sin roles seleccionados, la carpeta será pública para quien pueda acceder a la sección.",
                                        style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: const Color(0xFFB45309),
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Color(0xFFF1F5F9), width: 1))),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0))),
                        ),
                        child: Text("Cancelar",
                            style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                            isEditing
                                ? LucideIcons.save
                                : LucideIcons.folderPlus,
                            size: 16),
                        label: Text(
                            isEditing
                                ? "Guardar Cambios"
                                : "Crear Carpeta",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ── Sección de permisos ──
  Widget _permissionSection({
    required String label,
    required IconData icon,
    required Set<String> selected,
    required Color color,
    Set<String> disabledRoles = const {},
    required Function(Set<String>) onChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _availableRoles.map((r) {
            final roleName = r['name'] as String;
            final isSelected = selected.contains(roleName);
            final isDisabled = disabledRoles.contains(roleName);
            final rColor = r['color'] as Color;

            return GestureDetector(
              onTap: isDisabled
                  ? null
                  : () {
                      final next = Set<String>.from(selected);
                      if (isSelected) {
                        next.remove(roleName);
                      } else {
                        next.add(roleName);
                      }
                      onChange(next);
                    },
              child: Opacity(
                opacity: isDisabled ? 0.35 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? rColor : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isSelected
                            ? rColor
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(r['icon'] as IconData,
                        size: 11,
                        color: isSelected ? Colors.white : rColor),
                    const SizedBox(width: 5),
                    Text(r['label'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569))),
                    if (isSelected) ...[
                      const SizedBox(width: 5),
                      const Icon(LucideIcons.check,
                          size: 11, color: Colors.white),
                    ],
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Helpers de UI ──
  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8));

  InputDecoration _inputDecoration(
          {required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2563EB), width: 2)),
      );
}