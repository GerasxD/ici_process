import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  MODELO: Carpeta
// ═══════════════════════════════════════════════════════════════════════════
class VaultFolder {
  final String id;
  final String name;
  final String? parentId;          // null si es raíz
  final List<String> path;         // ["rootId", "subId1"] útil para breadcrumbs y queries
  final String colorHex;           // color del ícono ej. "0xFF2563EB"
  final String iconName;           // nombre lógico del ícono ej. "folder"
  final String createdBy;          // userId
  final String createdByName;      // denormalizado para mostrar sin otro query
  final DateTime createdAt;

  // Permisos por rol (nombres de rol de UserRole)
  final List<String> viewRoles;
  final List<String> uploadRoles;
  final List<String> deleteRoles;

  // Contadores (denormalizados — los actualiza el service)
  final int fileCount;
  final int subfolderCount;

  VaultFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.path = const [],
    this.colorHex = '0xFF2563EB',
    this.iconName = 'folder',
    required this.createdBy,
    this.createdByName = '',
    required this.createdAt,
    this.viewRoles = const [],
    this.uploadRoles = const [],
    this.deleteRoles = const [],
    this.fileCount = 0,
    this.subfolderCount = 0,
  });

  bool get isRoot => parentId == null;

  Map<String, dynamic> toMap() => {
        'name': name,
        'parentId': parentId,
        'path': path,
        'colorHex': colorHex,
        'iconName': iconName,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': Timestamp.fromDate(createdAt),
        'viewRoles': viewRoles,
        'uploadRoles': uploadRoles,
        'deleteRoles': deleteRoles,
        'fileCount': fileCount,
        'subfolderCount': subfolderCount,
      };

  factory VaultFolder.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return VaultFolder(
      id: doc.id,
      name: map['name'] ?? '',
      parentId: map['parentId'],
      path: List<String>.from(map['path'] ?? []),
      colorHex: map['colorHex'] ?? '0xFF2563EB',
      iconName: map['iconName'] ?? 'folder',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewRoles: List<String>.from(map['viewRoles'] ?? []),
      uploadRoles: List<String>.from(map['uploadRoles'] ?? []),
      deleteRoles: List<String>.from(map['deleteRoles'] ?? []),
      fileCount: map['fileCount'] ?? 0,
      subfolderCount: map['subfolderCount'] ?? 0,
    );
  }

  VaultFolder copyWith({
    String? name,
    String? colorHex,
    String? iconName,
    List<String>? viewRoles,
    List<String>? uploadRoles,
    List<String>? deleteRoles,
  }) {
    return VaultFolder(
      id: id,
      name: name ?? this.name,
      parentId: parentId,
      path: path,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
      viewRoles: viewRoles ?? this.viewRoles,
      uploadRoles: uploadRoles ?? this.uploadRoles,
      deleteRoles: deleteRoles ?? this.deleteRoles,
      fileCount: fileCount,
      subfolderCount: subfolderCount,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODELO: Archivo dentro de una carpeta
// ═══════════════════════════════════════════════════════════════════════════
class VaultFile {
  final String id;
  final String name;
  final String folderId;
  final String storagePath;    // ruta en Firebase Storage
  final String downloadUrl;
  final String mimeType;
  final int sizeBytes;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;

  VaultFile({
    required this.id,
    required this.name,
    required this.folderId,
    required this.storagePath,
    required this.downloadUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    this.uploadedByName = '',
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'folderId': folderId,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };

  factory VaultFile.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return VaultFile(
      id: doc.id,
      name: map['name'] ?? '',
      folderId: map['folderId'] ?? '',
      storagePath: map['storagePath'] ?? '',
      downloadUrl: map['downloadUrl'] ?? '',
      mimeType: map['mimeType'] ?? '',
      sizeBytes: map['sizeBytes'] ?? 0,
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedByName: map['uploadedByName'] ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Extensión en minúsculas sin el punto (ej. "pdf", "xlsx")
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Tamaño formateado legible (ej. "2.4 MB")
  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Tipo visual para UI: image, pdf, doc, sheet, archive, other
  String get kind {
    final ext = extension;
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) return 'image';
    if (ext == 'pdf') return 'pdf';
    if (['doc', 'docx', 'odt', 'txt', 'rtf'].contains(ext)) return 'doc';
    if (['xls', 'xlsx', 'ods', 'csv'].contains(ext)) return 'sheet';
    if (['ppt', 'pptx', 'odp'].contains(ext)) return 'slide';
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return 'archive';
    return 'other';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Helper: extensiones permitidas
// ═══════════════════════════════════════════════════════════════════════════
class VaultConstants {
  /// Tipos de archivo permitidos por la app. Cambia esta lista si quieres
  /// permitir más o menos tipos.
  static const List<String> allowedExtensions = [
    // Documentos
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt',
    // Hojas de cálculo
    'xls', 'xlsx', 'csv', 'ods',
    // Presentaciones
    'ppt', 'pptx', 'odp',
    // Imágenes
    'png', 'jpg', 'jpeg', 'gif', 'webp',
    // Archivos comprimidos
    'zip', 'rar', '7z',
  ];

  /// Tamaño máximo permitido por archivo (50 MB por defecto)
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// Carpeta raíz en Firebase Storage
  static const String storageRootPath = 'file_vault';
}