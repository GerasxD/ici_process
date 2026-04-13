// ============================================================================
// 📁 lib/services/file_storage_service.dart
// ============================================================================
// Servicio para subir, descargar y eliminar archivos de Firebase Storage.
// Los archivos se organizan por proceso y sección:
//   processes/{processId}/attachments/{section}/{fileId}_filename.ext
//
// También gestiona las referencias en Firestore dentro del documento
// del proceso, en el campo 'attachments' (lista de mapas).
// ============================================================================

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/file_attachment_model.dart';

class FileStorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── Referencia al documento del proceso ──────────────────
  DocumentReference _processRef(String processId) =>
      _db.collection('processes').doc(processId);

  // ─── SUBIR ARCHIVO ────────────────────────────────────────
  /// Sube un archivo a Storage y guarda la referencia en Firestore.
  /// [processId] - ID del proceso
  /// [section] - 'info' | 'financial' | 'oc'
  /// [fileName] - nombre original del archivo
  /// [fileBytes] - contenido en bytes
  /// [userName] - nombre del usuario que sube
  /// [userId] - uid del usuario
  Future<FileAttachment> uploadFile({
    required String processId,
    required String section,
    required String fileName,
    required Uint8List fileBytes,
    required String userName,
    required String userId,
  }) async {
    // 1. Generar ID único
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    final extension = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final storagePath = 'processes/$processId/attachments/$section/${fileId}_$fileName';

    // 2. Subir a Firebase Storage
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: _getMimeType(extension),
      customMetadata: {
        'uploadedBy': userName,
        'section': section,
        'originalName': fileName,
      },
    );
    final uploadTask = await ref.putData(fileBytes, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // 3. Crear modelo
    final attachment = FileAttachment(
      id: fileId,
      fileName: fileName,
      fileUrl: downloadUrl,
      fileType: extension,
      fileSizeBytes: fileBytes.length,
      uploadedBy: userName,
      uploadedById: userId,
      uploadedAt: DateTime.now(),
      section: section,
    );

    // 4. Guardar referencia en Firestore (dentro del proceso)
    await _processRef(processId).update({
      'attachments': FieldValue.arrayUnion([attachment.toMap()]),
    });

    return attachment;
  }

  // ─── ELIMINAR ARCHIVO ─────────────────────────────────────
  Future<void> deleteFile({
    required String processId,
    required FileAttachment attachment,
  }) async {
    // 1. Eliminar de Storage
    try {
      final storagePath =
          'processes/$processId/attachments/${attachment.section}/${attachment.id}_${attachment.fileName}';
      await _storage.ref(storagePath).delete();
    } catch (e) {
      // Si no existe en storage, continuar (puede haber sido eliminado manualmente)
      print('⚠️ Error eliminando de Storage: $e');
    }

    // 2. Eliminar referencia de Firestore
    await _processRef(processId).update({
      'attachments': FieldValue.arrayRemove([attachment.toMap()]),
    });
  }

  // ─── OBTENER ARCHIVOS POR SECCIÓN (Stream en tiempo real) ─
  Stream<List<FileAttachment>> getAttachments(String processId, String section) {
    return _processRef(processId).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      final list = data['attachments'] as List<dynamic>? ?? [];
      return list
          .map((e) => FileAttachment.fromMap(Map<String, dynamic>.from(e)))
          .where((f) => f.section == section)
          .toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    });
  }

  // ─── OBTENER TODOS LOS ARCHIVOS DE UN PROCESO ────────────
  Stream<List<FileAttachment>> getAllAttachments(String processId) {
    return _processRef(processId).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      final list = data['attachments'] as List<dynamic>? ?? [];
      return list
          .map((e) => FileAttachment.fromMap(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    });
  }

  // ─── HELPER: Tipo MIME ────────────────────────────────────
  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv': return 'text/csv';
      case 'txt': return 'text/plain';
      case 'zip': return 'application/zip';
      default: return 'application/octet-stream';
    }
  }
}