
// Modelo para archivos adjuntos por sección de un proceso.
// Cada proceso puede tener archivos en 3 secciones: info, financial, oc
import 'package:cloud_firestore/cloud_firestore.dart';

class FileAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType;       // extension: pdf, png, jpg, docx, xlsx...
  final int fileSizeBytes;
  final String uploadedBy;     // nombre del usuario que subió
  final String uploadedById;   // uid del usuario
  final DateTime uploadedAt;
  final String section;        // 'info' | 'financial' | 'oc'

  FileAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSizeBytes,
    required this.uploadedBy,
    required this.uploadedById,
    required this.uploadedAt,
    required this.section,
  });

  factory FileAttachment.fromMap(Map<String, dynamic> data) {
    return FileAttachment(
      id: data['id'] ?? '',
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? '',
      fileSizeBytes: data['fileSizeBytes'] ?? 0,
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedById: data['uploadedById'] ?? '',
      uploadedAt: data['uploadedAt'] is Timestamp
          ? (data['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      section: data['section'] ?? 'info',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
      'uploadedBy': uploadedBy,
      'uploadedById': uploadedById,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'section': section,
    };
  }

  /// Helper: Tamaño legible (ej: "2.4 MB", "340 KB")
  String get readableSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1048576) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / 1048576).toStringAsFixed(1)} MB';
  }

  /// Helper: ¿Es una imagen?
  bool get isImage => ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(fileType.toLowerCase());

  /// Helper: ¿Es PDF?
  bool get isPdf => fileType.toLowerCase() == 'pdf';
}