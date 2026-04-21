import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:mime/mime.dart';

import '../models/file_vault_model.dart';
import '../models/user_model.dart';

class FileVaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _foldersRef => _db.collection('file_vault');
  CollectionReference get _filesRef => _db.collection('file_vault_items');

  // ═══════════════════════════════════════════════════════════════════════
  //  STREAMS DE CARPETAS
  // ═══════════════════════════════════════════════════════════════════════

  /// Obtiene todas las carpetas hijas directas de [parentId].
  /// Si [parentId] es null, devuelve las carpetas raíz.
  ///
  /// NOTA: NO filtra por permisos. Ese filtro lo hace [VaultAccess] en la UI
  /// para poder reaccionar a cambios de rol del usuario sin perder streams.
  Stream<List<VaultFolder>> getFolders({String? parentId}) {
    return _foldersRef
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => VaultFolder.fromDoc(d)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
  }

  /// Obtiene una carpeta puntual (para breadcrumbs, p. ej.)
  Future<VaultFolder?> getFolderById(String id) async {
    final doc = await _foldersRef.doc(id).get();
    if (!doc.exists) return null;
    return VaultFolder.fromDoc(doc);
  }

  /// Obtiene todas las carpetas del path dado (para construir breadcrumbs)
  Future<List<VaultFolder>> getFoldersByPath(List<String> path) async {
    if (path.isEmpty) return [];
    final snaps = await Future.wait(path.map((id) => _foldersRef.doc(id).get()));
    return snaps
        .where((s) => s.exists)
        .map((s) => VaultFolder.fromDoc(s))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CRUD CARPETAS
  // ═══════════════════════════════════════════════════════════════════════

  /// Crea una carpeta. Si [parent] es null, se crea como raíz.
  /// Si no se pasan roles, hereda los del padre (si existe).
  Future<String> createFolder({
    required String name,
    required UserModel creator,
    VaultFolder? parent,
    String colorHex = '0xFF2563EB',
    String iconName = 'folder',
    List<String>? viewRoles,
    List<String>? uploadRoles,
    List<String>? deleteRoles,
  }) async {
    final docRef = _foldersRef.doc();

    final folder = VaultFolder(
      id: docRef.id,
      name: name.trim(),
      parentId: parent?.id,
      path: parent == null ? [] : [...parent.path, parent.id],
      colorHex: colorHex,
      iconName: iconName,
      createdBy: creator.id,
      createdByName: creator.name,
      createdAt: DateTime.now(),
      viewRoles: viewRoles ?? parent?.viewRoles ?? [],
      uploadRoles: uploadRoles ?? parent?.uploadRoles ?? [],
      deleteRoles: deleteRoles ?? parent?.deleteRoles ?? [],
    );

    await docRef.set(folder.toMap());

    // Incrementar contador del padre si aplica
    if (parent != null) {
      await _foldersRef.doc(parent.id).update({
        'subfolderCount': FieldValue.increment(1),
      });
    }

    return docRef.id;
  }

  /// Actualiza carpeta (solo nombre, color, icono y permisos — el path y parent
  /// no se mueven desde aquí).
  Future<void> updateFolder(VaultFolder folder) async {
    await _foldersRef.doc(folder.id).update({
      'name': folder.name,
      'colorHex': folder.colorHex,
      'iconName': folder.iconName,
      'viewRoles': folder.viewRoles,
      'uploadRoles': folder.uploadRoles,
      'deleteRoles': folder.deleteRoles,
    });
  }

  /// Elimina carpeta y TODO su contenido (subcarpetas + archivos) recursivamente.
  /// ⚠ Operación irreversible. Usar con confirmación.
  Future<void> deleteFolderRecursive(String folderId) async {
    // 1. Eliminar archivos de esta carpeta (Storage + Firestore)
    final files = await _filesRef.where('folderId', isEqualTo: folderId).get();
    for (final doc in files.docs) {
      final f = VaultFile.fromDoc(doc);
      try {
        await _storage.ref(f.storagePath).delete();
      } catch (_) {
        // Si el archivo físico ya no existe, ignoramos
      }
      await doc.reference.delete();
    }

    // 2. Recursivamente eliminar subcarpetas
    final subfolders = await _foldersRef.where('parentId', isEqualTo: folderId).get();
    for (final doc in subfolders.docs) {
      await deleteFolderRecursive(doc.id);
    }

    // 3. Eliminar la carpeta en sí y decrementar contador del padre
    final folderDoc = await _foldersRef.doc(folderId).get();
    if (folderDoc.exists) {
      final folder = VaultFolder.fromDoc(folderDoc);
      await _foldersRef.doc(folderId).delete();
      if (folder.parentId != null) {
        await _foldersRef.doc(folder.parentId).update({
          'subfolderCount': FieldValue.increment(-1),
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  STREAMS DE ARCHIVOS
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<VaultFile>> getFiles(String folderId) {
    return _filesRef
        .where('folderId', isEqualTo: folderId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => VaultFile.fromDoc(d)).toList()
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt)));
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SUBIR / ELIMINAR ARCHIVOS
  // ═══════════════════════════════════════════════════════════════════════

  /// Sube un archivo a la carpeta indicada. Usa Firebase Storage para el
  /// binario y guarda metadata en Firestore.
  ///
  /// [onProgress] opcional: recibe valores entre 0.0 y 1.0
  Future<VaultFile> uploadFile({
    required String folderId,
    required String fileName,
    required Uint8List bytes,
    required UserModel uploader,
    void Function(double progress)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Sanitizamos nombre para Storage (sin slashes ni espacios raros)
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '${VaultConstants.storageRootPath}/$folderId/${timestamp}_$safeName';

    final ref = _storage.ref(storagePath);
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: mimeType),
    );

    // Reportar progreso
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          onProgress(event.bytesTransferred / event.totalBytes);
        }
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Guardar metadata
    final docRef = _filesRef.doc();
    final file = VaultFile(
      id: docRef.id,
      name: fileName,
      folderId: folderId,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      uploadedBy: uploader.id,
      uploadedByName: uploader.name,
      uploadedAt: DateTime.now(),
    );
    await docRef.set(file.toMap());

    // Incrementar contador de archivos de la carpeta
    await _foldersRef.doc(folderId).update({
      'fileCount': FieldValue.increment(1),
    });

    return file;
  }

  Future<void> deleteFile(VaultFile file) async {
    try {
      await _storage.ref(file.storagePath).delete();
    } catch (_) {
      // Ignorar si ya no existe físicamente
    }
    await _filesRef.doc(file.id).delete();
    await _foldersRef.doc(file.folderId).update({
      'fileCount': FieldValue.increment(-1),
    });
  }

  Future<void> renameFile(String fileId, String newName) async {
    await _filesRef.doc(fileId).update({'name': newName.trim()});
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  VaultAccess: helper centralizado para validar permisos por carpeta.
//  Úsalo en la UI para decidir qué botones mostrar.
// ═══════════════════════════════════════════════════════════════════════════
class VaultAccess {
  /// ID del rol del usuario (ya es String en el nuevo modelo)
  static String _roleId(UserModel user) => user.role;

  /// ¿Es super-admin con acceso total?
  static bool _isGod(UserModel user) => user.role == SystemRoles.superAdmin;

  /// Puede ver el contenido de una carpeta
  static bool canView(UserModel user, VaultFolder folder,
      {bool hasGlobalOverride = false}) {
    if (_isGod(user) || hasGlobalOverride) return true;
    // Carpeta sin roles definidos = acceso abierto a todos los que lleguen
    if (folder.viewRoles.isEmpty) return true;
    return folder.viewRoles.contains(_roleId(user));
  }

  /// Puede subir archivos / crear subcarpetas
  static bool canUpload(UserModel user, VaultFolder folder,
      {bool hasGlobalOverride = false}) {
    if (_isGod(user) || hasGlobalOverride) return true;
    if (folder.uploadRoles.isEmpty) return false; // más estricto por defecto
    return folder.uploadRoles.contains(_roleId(user));
  }

  /// Puede eliminar archivos, renombrar carpeta, cambiar permisos, borrar carpeta
  static bool canDelete(UserModel user, VaultFolder folder,
      {bool hasGlobalOverride = false}) {
    if (_isGod(user) || hasGlobalOverride) return true;
    if (folder.deleteRoles.isEmpty) return false;
    return folder.deleteRoles.contains(_roleId(user));
  }
}
