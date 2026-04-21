import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/file_vault_model.dart';
import '../../models/user_model.dart';
import '../../services/file_vault_service.dart';
import '../widgets/file_vault/folder_form_dialog.dart';

class FileVaultScreen extends StatefulWidget {
  final UserModel currentUser;
  const FileVaultScreen({super.key, required this.currentUser});

  @override
  State<FileVaultScreen> createState() => _FileVaultScreenState();
}

class _FileVaultScreenState extends State<FileVaultScreen> {
  final FileVaultService _service = FileVaultService();

  // Navegación tipo "pila": la última carpeta es donde estás.
  // Si está vacía, estás en la raíz.
  final List<VaultFolder> _stack = [];

  double? _uploadProgress; // null = no subiendo

  // ── PALETA (armonizada con el resto de pantallas del proyecto) ──
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _accentColor = const Color(0xFF7C3AED); // violeta para diferenciar

  VaultFolder? get _currentFolder => _stack.isEmpty ? null : _stack.last;

  bool get _hasGlobalOverride =>
      PermissionManager().can(widget.currentUser, 'manage_all_files');

  bool get _canCreateRootFolder =>
      PermissionManager().can(widget.currentUser, 'create_folders') ||
      _hasGlobalOverride;

  // Dentro de una carpeta: ¿puedo subir archivos o crear subcarpeta?
  bool get _canUploadHere {
    final folder = _currentFolder;
    if (folder == null) return _canCreateRootFolder;
    return VaultAccess.canUpload(widget.currentUser, folder,
        hasGlobalOverride: _hasGlobalOverride);
  }

  bool get _canDeleteHere {
    final folder = _currentFolder;
    if (folder == null) return false;
    return VaultAccess.canDelete(widget.currentUser, folder,
        hasGlobalOverride: _hasGlobalOverride);
  }

  void _openFolder(VaultFolder folder) {
    setState(() => _stack.add(folder));
  }

  void _goBack() {
    if (_stack.isEmpty) return;
    setState(() => _stack.removeLast());
  }

  void _goToRoot() {
    setState(_stack.clear);
  }

  void _goToIndex(int index) {
    setState(() {
      _stack.removeRange(index + 1, _stack.length);
    });
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor:
            isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ACCIONES
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _handleNewFolder() async {
    if (!_canUploadHere) return;
    final result = await showDialog<FolderFormResult>(
      context: context,
      builder: (_) => FolderFormDialog(
        parentFolder: _currentFolder,
        currentUser: widget.currentUser,
      ),
    );
    if (result == null) return;

    try {
      await _service.createFolder(
        name: result.name,
        creator: widget.currentUser,
        parent: _currentFolder,
        colorHex: result.colorHex,
        iconName: result.iconName,
        viewRoles: result.viewRoles,
        uploadRoles: result.uploadRoles,
        deleteRoles: result.deleteRoles,
      );
      _showSnack("Carpeta creada correctamente");
    } catch (e) {
      _showSnack("Error al crear carpeta: $e", isSuccess: false);
    }
  }

  Future<void> _handleEditFolder(VaultFolder folder) async {
    final result = await showDialog<FolderFormResult>(
      context: context,
      builder: (_) => FolderFormDialog(
        parentFolder: null, // no mostramos selector de padre
        folderToEdit: folder,
        currentUser: widget.currentUser,
      ),
    );
    if (result == null) return;

    try {
      await _service.updateFolder(folder.copyWith(
        name: result.name,
        colorHex: result.colorHex,
        iconName: result.iconName,
        viewRoles: result.viewRoles,
        uploadRoles: result.uploadRoles,
        deleteRoles: result.deleteRoles,
      ));
      _showSnack("Carpeta actualizada");
    } catch (e) {
      _showSnack("Error al actualizar: $e", isSuccess: false);
    }
  }

  Future<void> _handleDeleteFolder(VaultFolder folder) async {
    final confirmed = await _confirmDialog(
      title: "Eliminar carpeta",
      message:
          "¿Eliminar “${folder.name}” y todo su contenido? Esta acción NO se puede deshacer.",
      confirmLabel: "Eliminar todo",
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await _service.deleteFolderRecursive(folder.id);
      _showSnack("Carpeta eliminada");
      // Si estábamos dentro de esta carpeta, subimos
      if (_stack.any((f) => f.id == folder.id)) _goBack();
    } catch (e) {
      _showSnack("Error al eliminar: $e", isSuccess: false);
    }
  }

  Future<void> _handleUploadFile() async {
    if (!_canUploadHere || _currentFolder == null) return;

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: VaultConstants.allowedExtensions,
      withData: kIsWeb, // en web necesitamos los bytes
    );
    if (picked == null || picked.files.isEmpty) return;

    final pf = picked.files.single;

    // Obtener bytes (compatible web/móvil)
    final bytes = kIsWeb
        ? pf.bytes
        : (pf.path != null ? await File(pf.path!).readAsBytes() : null);

    if (bytes == null) {
      _showSnack("No se pudo leer el archivo", isSuccess: false);
      return;
    }

    if (bytes.length > VaultConstants.maxFileSizeBytes) {
      _showSnack(
        "El archivo excede el tamaño máximo (${VaultConstants.maxFileSizeBytes ~/ (1024 * 1024)} MB)",
        isSuccess: false,
      );
      return;
    }

    setState(() => _uploadProgress = 0);
    try {
      await _service.uploadFile(
        folderId: _currentFolder!.id,
        fileName: pf.name,
        bytes: bytes,
        uploader: widget.currentUser,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      _showSnack("Archivo subido correctamente");
    } catch (e) {
      _showSnack("Error al subir: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  Future<void> _handleDeleteFile(VaultFile file) async {
    final confirmed = await _confirmDialog(
      title: "Eliminar archivo",
      message: "¿Eliminar “${file.name}” permanentemente?",
      confirmLabel: "Eliminar",
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await _service.deleteFile(file);
      _showSnack("Archivo eliminado");
    } catch (e) {
      _showSnack("Error al eliminar: $e", isSuccess: false);
    }
  }

  Future<void> _handleOpenFile(VaultFile file) async {
    final url = Uri.tryParse(file.downloadUrl);
    if (url == null) {
      _showSnack("URL inválida", isSuccess: false);
      return;
    }
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) _showSnack("No se pudo abrir el archivo", isSuccess: false);
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (destructive
                            ? const Color(0xFFDC2626)
                            : _primaryBlue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    destructive ? LucideIcons.alertTriangle : LucideIcons.info,
                    color:
                        destructive ? const Color(0xFFDC2626) : _primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary)),
                ),
              ]),
              const SizedBox(height: 16),
              Text(message,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: _borderColor),
                      ),
                    ),
                    child: Text("Cancelar",
                        style: GoogleFonts.inter(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destructive
                          ? const Color(0xFFDC2626)
                          : _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(confirmLabel,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Column(
        children: [
          if (_uploadProgress != null)
            LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 3,
              backgroundColor: _borderColor,
              valueColor: AlwaysStoppedAnimation(_accentColor),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildBreadcrumbs(),
                  const SizedBox(height: 20),
                  _buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
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
          child: Icon(LucideIcons.folderTree, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentFolder?.name ?? "Archivos de la Empresa",
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _currentFolder == null
                    ? "Organiza documentos en carpetas con permisos por rol."
                    : "Contenido de la carpeta seleccionada.",
                style: GoogleFonts.inter(fontSize: 15, color: _textSecondary),
              ),
            ],
          ),
        ),
        // Acciones
        if (_canUploadHere) ...[
          OutlinedButton.icon(
            onPressed: _handleNewFolder,
            icon: const Icon(LucideIcons.folderPlus, size: 16),
            label: Text(
              _currentFolder == null ? "Nueva carpeta" : "Nueva subcarpeta",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryBlue,
              side: BorderSide(color: _primaryBlue.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_currentFolder != null) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _uploadProgress == null ? _handleUploadFile : null,
              icon: _uploadProgress != null
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.upload, size: 16),
              label: Text(
                _uploadProgress != null
                    ? "Subiendo ${((_uploadProgress ?? 0) * 100).toInt()}%"
                    : "Subir archivo",
                style:
                    GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Breadcrumbs ─────────────────────────────────────────
  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _goToRoot,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(LucideIcons.home,
                      size: 14,
                      color: _stack.isEmpty ? _primaryBlue : _textSecondary),
                  const SizedBox(width: 6),
                  Text("Raíz",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              _stack.isEmpty ? _primaryBlue : _textSecondary)),
                ],
              ),
            ),
          ),
          for (int i = 0; i < _stack.length; i++) ...[
            Icon(LucideIcons.chevronRight,
                size: 12, color: _textSecondary.withOpacity(0.5)),
            InkWell(
              onTap: () => _goToIndex(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  _stack[i].name,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: i == _stack.length - 1
                          ? _primaryBlue
                          : _textSecondary),
                ),
              ),
            ),
          ],
          if (_stack.isNotEmpty) ...[
            const Spacer(),
            InkWell(
              onTap: _goBack,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowLeft, size: 13, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text("Atrás",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Contenido (folders + files) ─────────────────────────
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Carpetas ──
        StreamBuilder<List<VaultFolder>>(
          stream: _service.getFolders(parentId: _currentFolder?.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Filtramos por permisos de visualización
            final allFolders = snapshot.data ?? [];
            final visibleFolders = allFolders
                .where((f) => VaultAccess.canView(widget.currentUser, f,
                    hasGlobalOverride: _hasGlobalOverride))
                .toList();

            if (visibleFolders.isEmpty && _currentFolder == null) {
              return _buildEmptyRoot();
            }

            if (visibleFolders.isEmpty) {
              // dentro de una carpeta sin subcarpetas — no es error, simplemente no mostramos sección
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(
                    "CARPETAS (${visibleFolders.length})", LucideIcons.folders),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    int columns = constraints.maxWidth < 600
                        ? 1
                        : constraints.maxWidth < 1000
                            ? 2
                            : constraints.maxWidth < 1400
                                ? 3
                                : 4;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 140,
                      ),
                      itemCount: visibleFolders.length,
                      itemBuilder: (_, i) => _buildFolderCard(visibleFolders[i]),
                    );
                  },
                ),
              ],
            );
          },
        ),

        // ── Archivos (solo dentro de carpeta) ──
        if (_currentFolder != null) ...[
          const SizedBox(height: 28),
          StreamBuilder<List<VaultFile>>(
            stream: _service.getFiles(_currentFolder!.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final files = snap.data ?? [];
              if (files.isEmpty) {
                return _buildEmptyFiles();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(
                      "ARCHIVOS (${files.length})", LucideIcons.fileText),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildFileRow(files[i]),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: _textSecondary),
      const SizedBox(width: 8),
      Text(text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _textSecondary,
            letterSpacing: 1,
          )),
    ]);
  }

  // ── Card de carpeta ─────────────────────────────────────
  Widget _buildFolderCard(VaultFolder folder) {
    final color = Color(int.parse(folder.colorHex));
    final canEdit = VaultAccess.canDelete(widget.currentUser, folder,
        hasGlobalOverride: _hasGlobalOverride);

    return InkWell(
      onTap: () => _openFolder(folder),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFromName(folder.iconName),
                      color: color, size: 20),
                ),
                const Spacer(),
                if (canEdit)
                  PopupMenuButton<String>(
                    icon: Icon(LucideIcons.moreVertical,
                        size: 16, color: _textSecondary),
                    splashRadius: 16,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(LucideIcons.edit3, size: 14),
                          const SizedBox(width: 10),
                          Text("Editar",
                              style: GoogleFonts.inter(fontSize: 13)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(LucideIcons.trash2,
                              size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Text("Eliminar",
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFFDC2626))),
                        ]),
                      ),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') _handleEditFolder(folder);
                      if (v == 'delete') _handleDeleteFolder(folder);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(folder.name,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.file, size: 11, color: _textSecondary),
                const SizedBox(width: 4),
                Text("${folder.fileCount}",
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _textSecondary)),
                const SizedBox(width: 10),
                Icon(LucideIcons.folder, size: 11, color: _textSecondary),
                const SizedBox(width: 4),
                Text("${folder.subfolderCount}",
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _textSecondary)),
                const Spacer(),
                if (folder.viewRoles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.lock, size: 9, color: color),
                      const SizedBox(width: 3),
                      Text("${folder.viewRoles.length} rol(es)",
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.globe,
                          size: 9, color: Color(0xFF059669)),
                      const SizedBox(width: 3),
                      Text("Pública",
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669))),
                    ]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fila de archivo ─────────────────────────────────────
  Widget _buildFileRow(VaultFile file) {
    final kindMeta = _fileKindMeta(file.kind);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (kindMeta['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(kindMeta['icon'] as IconData,
                color: kindMeta['color'] as Color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(file.readableSize,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _textSecondary)),
                  Text("  ·  ",
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _textSecondary)),
                  Text(DateFormat('dd MMM yyyy').format(file.uploadedAt),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _textSecondary)),
                  if (file.uploadedByName.isNotEmpty) ...[
                    Text("  ·  ",
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _textSecondary)),
                    Flexible(
                      child: Text(file.uploadedByName,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _textSecondary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.externalLink, size: 16, color: _primaryBlue),
            tooltip: "Abrir",
            onPressed: () => _handleOpenFile(file),
          ),
          if (_canDeleteHere)
            IconButton(
              icon: const Icon(LucideIcons.trash2,
                  size: 16, color: Color(0xFFDC2626)),
              tooltip: "Eliminar",
              onPressed: () => _handleDeleteFile(file),
            ),
        ],
      ),
    );
  }

  // ── Empty states ────────────────────────────────────────
  Widget _buildEmptyRoot() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.folderPlus, size: 48, color: _textSecondary),
          const SizedBox(height: 16),
          Text("Aún no hay carpetas",
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 6),
          Text(
              _canCreateRootFolder
                  ? "Crea tu primera carpeta para empezar a organizar archivos."
                  : "Aún no se han creado carpetas o no tienes permiso para verlas.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
          if (_canCreateRootFolder) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _handleNewFolder,
              icon: const Icon(LucideIcons.folderPlus, size: 16),
              label: Text("Crear carpeta",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEmptyFiles() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.fileQuestion, size: 36, color: _textSecondary),
          const SizedBox(height: 12),
          Text("Esta carpeta aún no tiene archivos",
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          if (_canUploadHere) ...[
            const SizedBox(height: 6),
            Text("Usa el botón “Subir archivo” para empezar.",
                style:
                    GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Helpers de íconos
  // ═══════════════════════════════════════════════════════════════════════
  IconData _iconFromName(String name) {
    switch (name) {
      case 'briefcase':
        return LucideIcons.briefcase;
      case 'fileText':
        return LucideIcons.fileText;
      case 'banknote':
        return LucideIcons.banknote;
      case 'users':
        return LucideIcons.users;
      case 'wrench':
        return LucideIcons.wrench;
      case 'shield':
        return LucideIcons.shield;
      case 'star':
        return LucideIcons.star;
      case 'archive':
        return LucideIcons.archive;
      case 'folder':
      default:
        return LucideIcons.folder;
    }
  }

  Map<String, Object> _fileKindMeta(String kind) {
    switch (kind) {
      case 'pdf':
        return {'icon': LucideIcons.fileType, 'color': const Color(0xFFDC2626)};
      case 'image':
        return {'icon': LucideIcons.image, 'color': const Color(0xFF7C3AED)};
      case 'doc':
        return {'icon': LucideIcons.fileText, 'color': const Color(0xFF2563EB)};
      case 'sheet':
        return {
          'icon': LucideIcons.fileSpreadsheet,
          'color': const Color(0xFF059669)
        };
      case 'slide':
        return {
          'icon': LucideIcons.fileText,
          'color': const Color(0xFFEA580C)
        };
      case 'archive':
        return {
          'icon': LucideIcons.archive,
          'color': const Color(0xFF92400E)
        };
      default:
        return {'icon': LucideIcons.file, 'color': const Color(0xFF64748B)};
    }
  }
}