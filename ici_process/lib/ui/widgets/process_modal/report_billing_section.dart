import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/process_model.dart';

// ============================================================
//  DATA MODEL: ReportBillingData
// ============================================================
class ReportBillingFile {
  final String name;
  final String url;
  final String type; // 'photo_report', 'invoice_xml', 'invoice_pdf', 'editable_report'
  final DateTime uploadedAt;
  final String uploadedBy;
  final int sizeBytes;

  ReportBillingFile({
    required this.name,
    required this.url,
    required this.type,
    required this.uploadedAt,
    required this.uploadedBy,
    this.sizeBytes = 0,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'type': type,
        'uploadedAt': uploadedAt.toIso8601String(),
        'uploadedBy': uploadedBy,
        'sizeBytes': sizeBytes,
      };

  factory ReportBillingFile.fromMap(Map<String, dynamic> map) =>
      ReportBillingFile(
        name: map['name'] ?? '',
        url: map['url'] ?? '',
        type: map['type'] ?? '',
        uploadedAt: map['uploadedAt'] != null
            ? DateTime.parse(map['uploadedAt'])
            : DateTime.now(),
        uploadedBy: map['uploadedBy'] ?? '',
        sizeBytes: map['sizeBytes'] ?? 0,
      );
}

// ============================================================
//  MAIN WIDGET: ReportBillingSection
// ============================================================
class ReportBillingSection extends StatefulWidget {
  final ProcessModel process;
  final bool isEditable;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onDataChanged;
  final String currentUserName;

  const ReportBillingSection({
    super.key,
    required this.process,
    required this.isEditable,
    this.initialData,
    required this.onDataChanged,
    required this.currentUserName,
  });

  @override
  State<ReportBillingSection> createState() => _ReportBillingSectionState();
}

class _ReportBillingSectionState extends State<ReportBillingSection> {
  // ── Estado ──────────────────────────────────────────────
  List<ReportBillingFile> _photoReportFiles = [];
  List<ReportBillingFile> _invoiceXmlFiles = [];
  List<ReportBillingFile> _invoicePdfFiles = [];
  List<ReportBillingFile> _editableReportFiles = [];

  bool _reportSent = false;
  bool _invoiceSent = false;

  // ── Uploading states por categoría ─────────────────────
  final Map<String, bool> _isUploading = {
    'photo_report': false,
    'invoice_xml': false,
    'invoice_pdf': false,
    'editable_report': false,
  };

  final Map<String, bool> _isDraggingOver = {
    'photo_report': false,
    'invoice_xml': false,
    'invoice_pdf': false,
    'editable_report': false,
  };

  // ── Downloading states por archivo ─────────────────────
  final Map<String, bool> _isDownloading = {};

  // ── Colores verdes del tema ────────────────────────────
  static const Color _accentDark = Color(0xFF15803D);   // green-700
  static const Color _accentMid = Color(0xFF16A34A);    // green-600
  static const Color _accentLight = Color(0xFF22C55E);  // green-500
  static const Color _bgTint = Color(0xFFF0FDF4);       // green-50
  static const Color _bgMid = Color(0xFFDCFCE7);        // green-100
  static const Color _borderGreen = Color(0xFFBBF7D0);  // green-200

  final _dateFmt = DateFormat('dd MMM, yyyy · HH:mm', 'es');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.initialData == null) return;
    final data = widget.initialData!;

    _reportSent = data['reportSent'] ?? false;
    _invoiceSent = data['invoiceSent'] ?? false;

    _photoReportFiles = _parseFiles(data['photoReportFiles']);
    _invoiceXmlFiles = _parseFiles(data['invoiceXmlFiles']);
    _invoicePdfFiles = _parseFiles(data['invoicePdfFiles']);
    _editableReportFiles = _parseFiles(data['editableReportFiles']);
  }

  List<ReportBillingFile> _parseFiles(dynamic raw) {
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ReportBillingFile.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _notifyChanged() {
    widget.onDataChanged({
      'reportSent': _reportSent,
      'invoiceSent': _invoiceSent,
      'photoReportFiles': _photoReportFiles.map((f) => f.toMap()).toList(),
      'invoiceXmlFiles': _invoiceXmlFiles.map((f) => f.toMap()).toList(),
      'invoicePdfFiles': _invoicePdfFiles.map((f) => f.toMap()).toList(),
      'editableReportFiles':
          _editableReportFiles.map((f) => f.toMap()).toList(),
    });
  }

  // ── DOWNLOAD FILE ──────────────────────────────────────
  Future<void> _downloadFile(ReportBillingFile file) async {
    final key = '${file.type}_${file.name}';
    if (_isDownloading[key] == true) return;

    setState(() => _isDownloading[key] = true);

    try {
      final Uri uri = Uri.parse(file.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showSnack("No se pudo abrir el archivo: ${file.name}", isError: true);
      }
    } catch (e) {
      _showSnack("Error al descargar ${file.name}: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading[key] = false);
    }
  }

  // ── FILE PICKER + FIREBASE STORAGE UPLOAD ─────────────
  Future<void> _pickAndUploadFile(String fileType) async {
    FileType pickerType;
    List<String>? allowedExtensions;

    switch (fileType) {
      case 'photo_report':
        pickerType = FileType.custom;
        allowedExtensions = ['pdf'];
        break;
      case 'invoice_xml':
        pickerType = FileType.custom;
        allowedExtensions = ['xml'];
        break;
      case 'invoice_pdf':
        pickerType = FileType.custom;
        allowedExtensions = ['pdf'];
        break;
      case 'editable_report':
        pickerType = FileType.custom;
        allowedExtensions = ['doc', 'docx', 'xls', 'xlsx'];
        break;
      default:
        return;
    }

    final bool allowMultiple = fileType == 'photo_report';

    try {
      final result = await FilePicker.platform.pickFiles(
        type: pickerType,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading[fileType] = true);

      for (final file in result.files) {
        final Uint8List? fileBytes = file.bytes;
        final String fileName = file.name;

        if (fileBytes == null) {
          _showSnack("No se pudo leer el archivo: $fileName", isError: true);
          continue;
        }

        final String storagePath =
            'processes/${widget.process.id}/report_billing/$fileType/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        try {
          final ref = FirebaseStorage.instance.ref().child(storagePath);

          String contentType = 'application/octet-stream';
          final ext = fileName.split('.').last.toLowerCase();
          switch (ext) {
            case 'jpg':
            case 'jpeg':
              contentType = 'image/jpeg';
              break;
            case 'png':
              contentType = 'image/png';
              break;
            case 'gif':
              contentType = 'image/gif';
              break;
            case 'webp':
              contentType = 'image/webp';
              break;
            case 'xml':
              contentType = 'application/xml';
              break;
            case 'pdf':
              contentType = 'application/pdf';
              break;
            case 'doc':
              contentType = 'application/msword';
              break;
            case 'docx':
              contentType =
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
              break;
            case 'xls':
              contentType = 'application/vnd.ms-excel';
              break;
            case 'xlsx':
              contentType =
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
              break;
          }

          await ref.putData(
            fileBytes,
            SettableMetadata(contentType: contentType),
          );

          final downloadUrl = await ref.getDownloadURL();

          final newFile = ReportBillingFile(
            name: fileName,
            url: downloadUrl,
            type: fileType,
            uploadedAt: DateTime.now(),
            uploadedBy: widget.currentUserName,
            sizeBytes: fileBytes.length,
          );

          setState(() {
            switch (fileType) {
              case 'photo_report':
                _photoReportFiles.add(newFile);
                break;
              case 'invoice_xml':
                _invoiceXmlFiles.add(newFile);
                break;
              case 'invoice_pdf':
                _invoicePdfFiles.add(newFile);
                break;
              case 'editable_report':
                _editableReportFiles.add(newFile);
                break;
            }
          });

          _notifyChanged();
        } catch (e) {
          _showSnack("Error al subir $fileName: $e", isError: true);
        }
      }

      if (mounted) {
        setState(() => _isUploading[fileType] = false);
        _showSnack("Archivo(s) subido(s) correctamente");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading[fileType] = false);
        _showSnack("Error al seleccionar archivo: $e", isError: true);
      }
    }
  }


  // ── MANEJAR DRAG & DROP ───────────────────────────────────
  Future<void> _handleDropForCategory(String fileType, DropDoneDetails details) async {
    setState(() => _isDraggingOver[fileType] = false);
    if (!widget.isEditable || (_isUploading[fileType] ?? false)) return;

    // Extensiones permitidas por categoría
    final Map<String, List<String>> allowedByType = {
      'photo_report': ['pdf'],
      'invoice_xml': ['xml'],
      'invoice_pdf': ['pdf'],
      'editable_report': ['doc', 'docx', 'xls', 'xlsx'],
    };

    final allowed = allowedByType[fileType] ?? [];

    setState(() => _isUploading[fileType] = true);

    for (final xFile in details.files) {
      final ext = xFile.name.split('.').last.toLowerCase();
      if (!allowed.contains(ext)) {
        _showSnack("${xFile.name}: tipo no permitido (se espera ${allowed.join(', ')})", isError: true);
        continue;
      }

      final bytes = await xFile.readAsBytes();
      final fileName = xFile.name;
      final Uint8List fileBytes = Uint8List.fromList(bytes);

      final String storagePath =
          'processes/${widget.process.id}/report_billing/$fileType/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      try {
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final extLower = fileName.split('.').last.toLowerCase();

        String contentType = 'application/octet-stream';
        switch (extLower) {
          case 'xml': contentType = 'application/xml'; break;
          case 'pdf': contentType = 'application/pdf'; break;
          case 'doc': contentType = 'application/msword'; break;
          case 'docx': contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; break;
          case 'xls': contentType = 'application/vnd.ms-excel'; break;
          case 'xlsx': contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; break;
        }

        await ref.putData(fileBytes, SettableMetadata(contentType: contentType));
        final downloadUrl = await ref.getDownloadURL();

        final newFile = ReportBillingFile(
          name: fileName,
          url: downloadUrl,
          type: fileType,
          uploadedAt: DateTime.now(),
          uploadedBy: widget.currentUserName,
          sizeBytes: fileBytes.length,
        );

        setState(() {
          switch (fileType) {
            case 'photo_report': _photoReportFiles.add(newFile); break;
            case 'invoice_xml': _invoiceXmlFiles.add(newFile); break;
            case 'invoice_pdf': _invoicePdfFiles.add(newFile); break;
            case 'editable_report': _editableReportFiles.add(newFile); break;
          }
        });
        _notifyChanged();
      } catch (e) {
        _showSnack("Error al subir $fileName: $e", isError: true);
      }
    }

    if (mounted) {
      setState(() => _isUploading[fileType] = false);
      _showSnack("Archivo(s) subido(s) correctamente");
    }
  }

  Future<void> _deleteFile(String fileType, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.trash2,
                  color: Color(0xFFDC2626), size: 18),
            ),
            const SizedBox(width: 12),
            Text("¿Eliminar archivo?",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "El archivo será eliminado permanentemente del almacenamiento.",
          style: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar",
                style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child:
                Text("Eliminar", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    ReportBillingFile fileToDelete;
    switch (fileType) {
      case 'photo_report':
        fileToDelete = _photoReportFiles[index];
        break;
      case 'invoice_xml':
        fileToDelete = _invoiceXmlFiles[index];
        break;
      case 'invoice_pdf':
        fileToDelete = _invoicePdfFiles[index];
        break;
      case 'editable_report':
        fileToDelete = _editableReportFiles[index];
        break;
      default:
        return;
    }

    try {
      await FirebaseStorage.instance.refFromURL(fileToDelete.url).delete();
    } catch (e) {
      // Si falla la eliminación de Storage, igual quitamos la referencia local
    }

    setState(() {
      switch (fileType) {
        case 'photo_report':
          _photoReportFiles.removeAt(index);
          break;
        case 'invoice_xml':
          _invoiceXmlFiles.removeAt(index);
          break;
        case 'invoice_pdf':
          _invoicePdfFiles.removeAt(index);
          break;
        case 'editable_report':
          _editableReportFiles.removeAt(index);
          break;
      }
    });
    _notifyChanged();
    _showSnack("Archivo eliminado");
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? LucideIcons.alertOctagon : LucideIcons.checkCircle2,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    ));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          _buildUploadCategory(
            title: "Reporte Fotográfico",
            subtitle: "Evidencia fotográfica del servicio realizado",
            icon: LucideIcons.camera,
            fileType: 'photo_report',
            files: _photoReportFiles,
            acceptLabel: "Archivos PDF",
          ),
          const SizedBox(height: 20),

          _buildUploadCategory(
            title: "Factura XML",
            subtitle: "Archivo CFDI en formato XML",
            icon: LucideIcons.fileCode,
            fileType: 'invoice_xml',
            files: _invoiceXmlFiles,
            acceptLabel: "Archivos XML",
          ),
          const SizedBox(height: 20),

          _buildUploadCategory(
            title: "Factura PDF",
            subtitle: "Representación impresa de la factura",
            icon: LucideIcons.fileText,
            fileType: 'invoice_pdf',
            files: _invoicePdfFiles,
            acceptLabel: "Archivos PDF",
          ),
          const SizedBox(height: 20),

          _buildUploadCategory(
            title: "Reporte Editable",
            subtitle: "Documento de reporte en Word o Excel",
            icon: LucideIcons.fileSpreadsheet,
            fileType: 'editable_report',
            files: _editableReportFiles,
            acceptLabel: "Word (.docx) o Excel (.xlsx)",
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 20),

          _buildConfirmationSection(mobile),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    final totalFiles = _photoReportFiles.length +
        _invoiceXmlFiles.length +
        _invoicePdfFiles.length +
        _editableReportFiles.length;

    int confirmations = 0;
    if (_reportSent) confirmations++;
    if (_invoiceSent) confirmations++;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _bgTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGreen),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(LucideIcons.clipboardCheck, color: _accentDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reporte de Servicio y Facturación",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _accentDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$totalFiles archivo${totalFiles != 1 ? 's' : ''} subido${totalFiles != 1 ? 's' : ''} · $confirmations/2 confirmaciones",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF16A34A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: confirmations == 2
                  ? _accentMid.withOpacity(0.12)
                  : const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: confirmations == 2
                    ? _accentMid.withOpacity(0.3)
                    : const Color(0xFFFCD34D).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  confirmations == 2
                      ? LucideIcons.checkCircle2
                      : LucideIcons.clock,
                  size: 14,
                  color: confirmations == 2
                      ? _accentMid
                      : const Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Text(
                  confirmations == 2 ? "Completo" : "Pendiente",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: confirmations == 2
                        ? _accentMid
                        : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── UPLOAD CATEGORY ────────────────────────────────────────
  Widget _buildUploadCategory({
    required String title,
    required String subtitle,
    required IconData icon,
    required String fileType,
    required List<ReportBillingFile> files,
    required String acceptLabel,
  }) {
    final isUploading = _isUploading[fileType] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: files.isNotEmpty ? _borderGreen : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título de la categoría ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: files.isNotEmpty ? _bgTint : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: files.isNotEmpty
                        ? _accentMid.withOpacity(0.12)
                        : const Color(0xFF64748B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: files.isNotEmpty
                        ? _accentMid
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (files.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accentMid,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${files.length}",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Lista de archivos subidos ──────────────────
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: files.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final file = entry.value;
                  return _buildFileItem(file, fileType, idx);
                }).toList(),
              ),
            ),

          // ── Zona de subida (solo en E7 editable) ───────
          // ── Zona de subida con Drag & Drop (solo en E7 editable) ──
          if (widget.isEditable)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: DropTarget(
                onDragEntered: (_) => setState(() => _isDraggingOver[fileType] = true),
                onDragExited: (_) => setState(() => _isDraggingOver[fileType] = false),
                onDragDone: (details) => _handleDropForCategory(fileType, details),
                child: InkWell(
                  onTap: isUploading ? null : () => _pickAndUploadFile(fileType),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: (_isDraggingOver[fileType] == true)
                          ? _accentMid.withOpacity(0.08)
                          : isUploading
                              ? _bgMid
                              : _bgTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_isDraggingOver[fileType] == true)
                            ? _accentMid
                            : isUploading
                                ? _accentLight
                                : _borderGreen,
                        width: (_isDraggingOver[fileType] == true) ? 2 : 1,
                      ),
                    ),
                    child: isUploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _accentMid,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Subiendo archivo...",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _accentDark,
                                ),
                              ),
                            ],
                          )
                        : (_isDraggingOver[fileType] == true)
                            ? Column(
                                children: [
                                  Icon(LucideIcons.download, size: 24, color: _accentMid),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Suelta aquí para subir",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _accentMid,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.uploadCloud, size: 18, color: _accentMid),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      children: [
                                        Text(
                                          "Arrastra o toca para subir",
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _accentDark,
                                          ),
                                        ),
                                        Text(
                                          acceptLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _accentMid.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ),

          // ── Mensaje informativo en modo lectura (E8) ───
          if (!widget.isEditable && files.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.folderOpen,
                        size: 16, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 10),
                    Text(
                      "Sin archivos en esta categoría",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── FILE ITEM ─────────────────────────────────────────────
  Widget _buildFileItem(
      ReportBillingFile file, String fileType, int index) {
    final ext = file.name.split('.').last.toLowerCase();
    IconData fileIcon;
    Color fileIconColor;

    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        fileIcon = LucideIcons.image;
        fileIconColor = const Color(0xFF2563EB);
        break;
      case 'xml':
        fileIcon = LucideIcons.fileCode;
        fileIconColor = const Color(0xFFEA580C);
        break;
      case 'pdf':
        fileIcon = LucideIcons.fileText;
        fileIconColor = const Color(0xFFDC2626);
        break;
      case 'doc':
      case 'docx':
        fileIcon = LucideIcons.fileText;
        fileIconColor = const Color(0xFF2563EB);
        break;
      case 'xls':
      case 'xlsx':
        fileIcon = LucideIcons.fileSpreadsheet;
        fileIconColor = const Color(0xFF16A34A);
        break;
      default:
        fileIcon = LucideIcons.file;
        fileIconColor = const Color(0xFF64748B);
    }

    final downloadKey = '${fileType}_${file.name}';
    final isDownloading = _isDownloading[downloadKey] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // ── Ícono del archivo ─────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fileIconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(fileIcon, size: 16, color: fileIconColor),
          ),
          const SizedBox(width: 12),

          // ── Info del archivo ──────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${_formatFileSize(file.sizeBytes)} · ${file.uploadedBy} · ${_dateFmt.format(file.uploadedAt)}",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Botón Descargar (siempre visible: E7 y E8) ─
          Tooltip(
            message: "Descargar archivo",
            child: InkWell(
              onTap: isDownloading ? null : () => _downloadFile(file),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDownloading
                      ? _bgMid
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDownloading
                        ? _borderGreen
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: isDownloading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accentMid,
                        ),
                      )
                    : const Icon(
                        LucideIcons.download,
                        size: 14,
                        color: Color(0xFF2563EB),
                      ),
              ),
            ),
          ),

          // ── Botón Eliminar (solo en E7 editable) ───────
          if (widget.isEditable) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: "Eliminar archivo",
              child: InkWell(
                onTap: () => _deleteFile(fileType, index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Icon(LucideIcons.trash2,
                      size: 14, color: Color(0xFFDC2626)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── CONFIRMACIÓN DE ENVÍO ─────────────────────────────────
  Widget _buildConfirmationSection(bool mobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.send, size: 16, color: _accentDark),
            ),
            const SizedBox(width: 10),
            Text(
              "CONFIRMACIÓN DE ENVÍO",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _accentDark,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (mobile)
          Column(
            children: [
              _buildConfirmationCheckbox(
                label: "Reporte Enviado al Cliente",
                subtitle:
                    "El reporte fotográfico y el reporte editable han sido entregados",
                icon: LucideIcons.fileCheck,
                value: _reportSent,
                onChanged: widget.isEditable
                    ? (val) {
                        setState(() => _reportSent = val ?? false);
                        _notifyChanged();
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              _buildConfirmationCheckbox(
                label: "Factura Enviada al Cliente",
                subtitle:
                    "La factura PDF y XML han sido enviadas al cliente",
                icon: LucideIcons.receipt,
                value: _invoiceSent,
                onChanged: widget.isEditable
                    ? (val) {
                        setState(() => _invoiceSent = val ?? false);
                        _notifyChanged();
                      }
                    : null,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildConfirmationCheckbox(
                  label: "Reporte Enviado al Cliente",
                  subtitle:
                      "El reporte fotográfico ha sido entregado",
                  icon: LucideIcons.fileCheck,
                  value: _reportSent,
                  onChanged: widget.isEditable
                      ? (val) {
                          setState(() => _reportSent = val ?? false);
                          _notifyChanged();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildConfirmationCheckbox(
                  label: "Factura Enviada al Cliente",
                  subtitle:
                      "La factura PDF y XML han sido enviadas al cliente",
                  icon: LucideIcons.receipt,
                  value: _invoiceSent,
                  onChanged: widget.isEditable
                      ? (val) {
                          setState(() => _invoiceSent = val ?? false);
                          _notifyChanged();
                        }
                      : null,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildConfirmationCheckbox({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool?)? onChanged,
  }) {
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? _bgTint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? _accentMid.withOpacity(0.4) : const Color(0xFFE2E8F0),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? _accentMid : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: value ? _accentMid : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: value ? _accentDark : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: value
                                ? _accentDark
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: value
                          ? _accentMid.withOpacity(0.8)
                          : const Color(0xFF94A3B8),
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
}