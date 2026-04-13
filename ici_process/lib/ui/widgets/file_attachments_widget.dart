// Widget reutilizable para subir/descargar/eliminar archivos adjuntos.
// Se integra en cualquier card del proceso con el estilo visual del sistema.
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/file_attachment_model.dart';
import '../../models/user_model.dart';
import '../../services/file_storage_service.dart';

class FileAttachmentsWidget extends StatefulWidget {
  final String processId;
  final String section; // 'info' | 'financial' | 'oc'
  final UserModel currentUser;
  final bool canUpload;
  final bool canView;

  const FileAttachmentsWidget({
    super.key,
    required this.processId,
    required this.section,
    required this.currentUser,
    this.canUpload = false,
    this.canView = true,
  });

  @override
  State<FileAttachmentsWidget> createState() => _FileAttachmentsWidgetState();
}

class _FileAttachmentsWidgetState extends State<FileAttachmentsWidget>
    with SingleTickerProviderStateMixin {
  final FileStorageService _fileService = FileStorageService();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isExpanded = false;
  bool _isDragging = false;

  // ── Configuración visual por sección ──────────────────────
  Map<String, dynamic> get _sectionStyle {
    switch (widget.section) {
      case 'financial':
        return {
          'label': 'Archivos de Cotización',
          'icon': LucideIcons.fileText,
          'color': const Color(0xFFEAB308),
          'bg': const Color(0xFFFEFCE8),
          'border': const Color(0xFFFDE68A),
        };
      case 'oc':
        return {
          'label': 'Archivos de Orden de Compra',
          'icon': LucideIcons.shoppingBag,
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFF5F3FF),
          'border': const Color(0xFFDDD6FE),
        };
      default: // 'info'
        return {
          'label': 'Archivos del Proyecto',
          'icon': LucideIcons.paperclip,
          'color': const Color(0xFF3B82F6),
          'bg': const Color(0xFFEFF6FF),
          'border': const Color(0xFFBFDBFE),
        };
    }
  }

  // ── SUBIR ARCHIVO ─────────────────────────────────────────
  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp',
          'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip',
        ],
        withData: true,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) _showSnackBar("No se pudo leer el archivo", isError: true);
        return;
      }

      await _processAndUpload(file.name, file.bytes!);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar("Error al subir: ${e.toString()}", isError: true);
      }
    }
  }

  void _simulateProgress() async {
    for (int i = 1; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _isUploading) {
        setState(() => _uploadProgress = i * 0.1);
      }
    }
  }


  // ── PROCESAR ARCHIVOS (compartido entre pick y drop) ──────
  Future<void> _processAndUpload(String fileName, Uint8List fileBytes) async {
    final allowedExtensions = [
      'pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp',
      'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip',
    ];

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!allowedExtensions.contains(ext)) {
      if (mounted) _showSnackBar("Tipo de archivo no permitido: .$ext", isError: true);
      return;
    }

    if (fileBytes.length > 25 * 1024 * 1024) {
      if (mounted) _showSnackBar("$fileName excede el límite de 25 MB", isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    _simulateProgress();

    try {
      await _fileService.uploadFile(
        processId: widget.processId,
        section: widget.section,
        fileName: fileName,
        fileBytes: fileBytes,
        userName: widget.currentUser.name,
        userId: widget.currentUser.id,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _isExpanded = true;
        });
        _showSnackBar("Archivo subido exitosamente");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar("Error al subir: ${e.toString()}", isError: true);
      }
    }
  }

  // ── MANEJAR DROP ──────────────────────────────────────────
  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    if (!widget.canUpload || _isUploading) return;

    for (final xFile in details.files) {
      final bytes = await xFile.readAsBytes();
      await _processAndUpload(xFile.name, Uint8List.fromList(bytes));
    }
  }

  // ── ELIMINAR ARCHIVO ──────────────────────────────────────
  Future<void> _handleDelete(FileAttachment file) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.trash2,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Eliminar Archivo",
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Esta acción no se puede deshacer",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(
                        LucideIcons.x,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Contenido: info del archivo
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _buildFileIcon(file.fileType, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${file.readableSize} · Subido por ${file.uploadedBy}",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "Eliminar",
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

    if (confirm == true) {
      try {
        await _fileService.deleteFile(
          processId: widget.processId,
          attachment: file,
        );
        if (mounted) _showSnackBar("Archivo eliminado");
      } catch (e) {
        if (mounted) _showSnackBar("Error al eliminar", isError: true);
      }
    }
  }

  // ── DESCARGAR / ABRIR ARCHIVO ─────────────────────────────
  Future<void> _handleOpen(FileAttachment file) async {
    final uri = Uri.parse(file.fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnackBar("No se pudo abrir el archivo", isError: true);
    }
  }

  // ── SNACKBAR HELPER ───────────────────────────────────────
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertOctagon : LucideIcons.checkCircle2,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!widget.canView) return const SizedBox.shrink();

    final style = _sectionStyle;
    final Color accentColor = style['color'];
    final Color bgColor = style['bg'];
    final Color borderColor = style['border'];

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: _isDragging ? accentColor.withOpacity(0.06) : bgColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDragging ? accentColor : borderColor.withOpacity(0.6),
            width: _isDragging ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Indicador visual de Drag ──────────────────
            if (_isDragging)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(LucideIcons.download, size: 28, color: accentColor),
                    const SizedBox(height: 8),
                    Text(
                      "Suelta aquí para subir",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),

            // ── HEADER: Toggle + Título + Botón Subir ─────
            if (!_isDragging)
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(style['icon'], size: 16, color: accentColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StreamBuilder<List<FileAttachment>>(
                          stream: _fileService.getAttachments(widget.processId, widget.section),
                          builder: (context, snap) {
                            final count = snap.data?.length ?? 0;
                            return Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    style['label'],
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      if (widget.canUpload) ...[
                        const SizedBox(width: 8),
                        _isUploading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(accentColor),
                                ),
                              )
                            : InkWell(
                                onTap: _pickAndUpload,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.upload, size: 14, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Subir",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Barra de progreso ─────────────────────────
            if (_isUploading && !_isDragging)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: borderColor.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(accentColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "Subiendo archivo...",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${(_uploadProgress * 100).toInt()}%",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // ── Lista expandible ──────────────────────────
            if (!_isDragging)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: _buildFileList(),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeInOut,
              ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  LISTA DE ARCHIVOS
  // ═════════════════════════════════════════════════════════════
  Widget _buildFileList() {
    return StreamBuilder<List<FileAttachment>>(
      stream: _fileService.getAttachments(widget.processId, widget.section),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final files = snapshot.data ?? [];

        if (files.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  LucideIcons.folderOpen,
                  size: 28,
                  color: const Color(0xFF94A3B8).withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sin archivos adjuntos",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              ...files.map((file) => _buildFileRow(file)),
            ],
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  FILA DE ARCHIVO INDIVIDUAL
  // ═════════════════════════════════════════════════════════════
  Widget _buildFileRow(FileAttachment file) {
    final style = _sectionStyle;
    final Color accentColor = style['color'];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono del tipo de archivo
          _buildFileIcon(file.fileType, size: 36),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  "${file.readableSize} · ${file.uploadedBy} · ${DateFormat('dd MMM yyyy').format(file.uploadedAt)}",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Botones de acción
          const SizedBox(width: 8),

          // Descargar / Abrir
          _buildActionButton(
            icon: LucideIcons.download,
            tooltip: "Descargar",
            color: accentColor,
            onTap: () => _handleOpen(file),
          ),

          // Eliminar (solo si puede subir = tiene permiso de escritura)
          if (widget.canUpload) ...[
            const SizedBox(width: 4),
            _buildActionButton(
              icon: LucideIcons.trash2,
              tooltip: "Eliminar",
              color: const Color(0xFFEF4444),
              onTap: () => _handleDelete(file),
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  HELPERS VISUALES
  // ═════════════════════════════════════════════════════════════

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  static Widget _buildFileIcon(String fileType, {double size = 36}) {
    IconData icon;
    Color color;
    Color bg;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        icon = LucideIcons.fileText;
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        icon = LucideIcons.image;
        color = const Color(0xFF7C3AED);
        bg = const Color(0xFFF5F3FF);
        break;
      case 'doc':
      case 'docx':
        icon = LucideIcons.fileText;
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFEFF6FF);
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        icon = LucideIcons.sheet;
        color = const Color(0xFF059669);
        bg = const Color(0xFFF0FDF4);
        break;
      case 'zip':
        icon = LucideIcons.archive;
        color = const Color(0xFFB45309);
        bg = const Color(0xFFFEF3C7);
        break;
      default:
        icon = LucideIcons.file;
        color = const Color(0xFF64748B);
        bg = const Color(0xFFF8FAFC);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Center(
        child: Icon(icon, size: size * 0.45, color: color),
      ),
    );
  }
}
