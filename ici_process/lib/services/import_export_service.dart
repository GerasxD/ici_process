import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

import '../models/material_model.dart';
import 'material_service.dart';
import 'provider_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
///  REPORTE DEL RESULTADO DE IMPORTACIÓN
/// ═══════════════════════════════════════════════════════════════════════
class ImportReport {
  final int created;
  final int updated;
  final int skipped;
  final int newProvidersCreated;
  final List<String> errors;

  ImportReport({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.newProvidersCreated = 0,
    this.errors = const [],
  });

  int get total => created + updated + skipped;

  String get summary =>
      "✅ $created nuevos · 🔄 $updated actualizados · ⏭️ $skipped omitidos"
      "${newProvidersCreated > 0 ? ' · 🏭 $newProvidersCreated proveedores nuevos' : ''}";
}

/// Representa una fila del excel ya parseada y lista para importar.
class _ParsedRow {
  final String name;
  final String unit;
  final String providerName;
  final double price;

  _ParsedRow({
    required this.name,
    required this.unit,
    required this.providerName,
    required this.price,
  });
}

/// Preview de lo que se va a importar (para mostrar al usuario ANTES de subir).
class ImportPreview {
  final int totalRows;
  final int uniqueMaterials;
  final int willCreate;
  final int willUpdate;
  final int newProviders;
  final List<String> warnings;
  final Map<String, List<_ParsedRow>> groupedByName;
  final Set<String> missingProviders;

  ImportPreview({
    required this.totalRows,
    required this.uniqueMaterials,
    required this.willCreate,
    required this.willUpdate,
    required this.newProviders,
    required this.warnings,
    required this.groupedByName,
    required this.missingProviders,
  });
}

/// ═══════════════════════════════════════════════════════════════════════
///  SERVICIO DE IMPORTACIÓN / EXPORTACIÓN DE EXCEL
/// ═══════════════════════════════════════════════════════════════════════
class ImportExportService {
  final MaterialService _materialService = MaterialService();
  final ProviderService _providerService = ProviderService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Mapeo de columnas esperadas.
  /// Si el header del Excel contiene cualquiera de estos aliases (sin importar
  /// mayúsculas/espacios), lo asociamos al campo correspondiente.
  static const Map<String, List<String>> _columnAliases = {
    'name': ['articulo / modelo', 'articulo/modelo', 'nombre', 'material'],
    'unit': ['unidad', 'unit'],
    'provider': ['proveedores', 'proveedor', 'provider'],
    'price': ['costo', 'precio', 'price'],
  };

  // ─────────────────────────────────────────────────────────────────────
  //  1) ABRIR EL SELECTOR DE ARCHIVOS Y LEER EL EXCEL
  // ─────────────────────────────────────────────────────────────────────

  /// Permite al usuario elegir un archivo Excel y lo parsea.
  /// Retorna null si el usuario cancela.
  Future<ImportPreview?> pickAndAnalyzeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true, // CRÍTICO: obtener bytes directo (funciona también en Web)
    );

    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      throw Exception("No se pudo leer el archivo seleccionado");
    }

    return _analyzeBytes(bytes);
  }

  /// Analiza los bytes del Excel y genera un preview.
  Future<ImportPreview> _analyzeBytes(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception("El archivo Excel está vacío");
    }

    // Usar la primera hoja
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw Exception("La hoja no contiene datos");
    }

    // 1. Localizar columnas por header
    final headerRow = sheet.rows.first;
    final colMap = _mapColumns(headerRow);

    if (colMap['name'] == null) {
      throw Exception(
          "No encontré la columna del nombre del material. "
          "Esperaba una de: Articulo / Modelo, Nombre, Material");
    }
    if (colMap['unit'] == null) {
      throw Exception("No encontré la columna 'Unidad'");
    }
    if (colMap['price'] == null) {
      throw Exception("No encontré la columna 'Costo' o 'Precio'");
    }

    // 2. Parsear filas
    final parsed = <_ParsedRow>[];
    final warnings = <String>[];

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      try {
        final name = _cellString(row, colMap['name']!).trim();
        if (name.isEmpty) continue; // Fila vacía, saltar silenciosamente

        final unit = _cellString(row, colMap['unit']!).trim();
        final providerName =
            _cellString(row, colMap['provider'] ?? -1).trim();
        final priceStr = _cellString(row, colMap['price']!).trim();
        final price = _parseDouble(priceStr);

        if (price == null) {
          warnings.add("Fila ${i + 1} ($name): costo inválido '$priceStr'");
          continue;
        }

        parsed.add(_ParsedRow(
          name: name,
          unit: unit.isEmpty ? 'Pieza' : unit,
          providerName: providerName,
          price: price,
        ));
      } catch (e) {
        warnings.add("Fila ${i + 1}: error al leer — $e");
      }
    }

    // 3. Agrupar por nombre (un mismo material puede tener varios proveedores)
    final grouped = <String, List<_ParsedRow>>{};
    for (final r in parsed) {
      grouped.putIfAbsent(r.name, () => []).add(r);
    }

    // 4. Consultar qué ya existe en Firebase para calcular creados vs actualizados
    final existing = await _materialService.getMaterials().first;
    final existingNames = existing.map((m) => m.name.toLowerCase()).toSet();

    int willCreate = 0;
    int willUpdate = 0;
    for (final name in grouped.keys) {
      if (existingNames.contains(name.toLowerCase())) {
        willUpdate++;
      } else {
        willCreate++;
      }
    }

    // 5. Detectar proveedores que habrá que crear
    final existingProviders = await _providerService.getProviders().first;
    final existingProviderNames =
        existingProviders.map((p) => p.name.toLowerCase().trim()).toSet();

    final allProviderNames = parsed
        .map((r) => r.providerName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();

    final missingProviders = allProviderNames
        .where((n) => !existingProviderNames.contains(n.toLowerCase()))
        .toSet();

    return ImportPreview(
      totalRows: parsed.length,
      uniqueMaterials: grouped.length,
      willCreate: willCreate,
      willUpdate: willUpdate,
      newProviders: missingProviders.length,
      warnings: warnings,
      groupedByName: grouped,
      missingProviders: missingProviders,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  2) EJECUTAR LA IMPORTACIÓN (ya confirmada por el usuario)
  // ─────────────────────────────────────────────────────────────────────

  /// Ejecuta la importación basada en un preview ya analizado.
  ///
  /// Reglas:
  /// - Si el material ya existe (match por nombre, case-insensitive):
  ///     actualiza unidad y lista de precios. NUNCA toca stock ni reservedStock.
  /// - Si no existe: lo crea con stock = 0.
  /// - Si aparecen proveedores nuevos: los crea automáticamente en la colección.
  /// - Usa WriteBatch (500 ops por lote) para performance.
  Future<ImportReport> executeImport(ImportPreview preview) async {
    final errors = <String>[];
    int created = 0;
    int updated = 0;
    int skipped = 0;

    // ── PASO 1: Crear proveedores faltantes ──
    final providerNameToId = <String, String>{}; // lowercase -> id
    final existingProviders = await _providerService.getProviders().first;
    for (final p in existingProviders) {
      providerNameToId[p.name.toLowerCase().trim()] = p.id;
    }

    int newProvidersCreated = 0;
    for (final providerName in preview.missingProviders) {
      try {
        final docRef = await _db.collection('providers').add({
          'name': providerName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        providerNameToId[providerName.toLowerCase()] = docRef.id;
        newProvidersCreated++;
      } catch (e) {
        errors.add("No se pudo crear proveedor '$providerName': $e");
      }
    }

    // ── PASO 2: Obtener materiales existentes ──
    final existingMaterials = await _materialService.getMaterials().first;
    final existingByName = <String, MaterialItem>{
      for (final m in existingMaterials) m.name.toLowerCase(): m,
    };

    // ── PASO 3: Procesar en lotes de 500 (límite de WriteBatch) ──
    final materialsRef = _db.collection('materials');
    const batchSize = 400; // Dejamos margen bajo el límite de 500

    final entries = preview.groupedByName.entries.toList();

    for (int i = 0; i < entries.length; i += batchSize) {
      final chunk = entries.skip(i).take(batchSize);
      final batch = _db.batch();

      for (final entry in chunk) {
        final name = entry.key;
        final rows = entry.value;

        try {
          // Construir lista de precios (un precio por proveedor)
          final prices = <PriceEntry>[];
          for (final r in rows) {
            if (r.providerName.isEmpty) continue;
            final providerId =
                providerNameToId[r.providerName.toLowerCase()] ?? '';
            if (providerId.isEmpty) continue;

            // Si ya hay precio para ese proveedor, quedarnos con el más bajo
            final existingIdx =
                prices.indexWhere((p) => p.providerId == providerId);
            if (existingIdx >= 0) {
              if (r.price < prices[existingIdx].price) {
                prices[existingIdx] = PriceEntry(
                  providerId: providerId,
                  providerName: r.providerName,
                  price: r.price,
                  updatedAt: DateTime.now(),
                );
              }
            } else {
              prices.add(PriceEntry(
                providerId: providerId,
                providerName: r.providerName,
                price: r.price,
                updatedAt: DateTime.now(),
              ));
            }
          }

          final unit = rows.first.unit;
          final existing = existingByName[name.toLowerCase()];

          if (existing != null) {
            // ── ACTUALIZAR: solo unidad y precios. NUNCA stock ni reservedStock. ──
            batch.update(materialsRef.doc(existing.id), {
              'unit': unit,
              'prices': prices.map((p) => p.toMap()).toList(),
            });
            updated++;
          } else {
            // ── CREAR NUEVO: stock = 0 ──
            final newDoc = materialsRef.doc();
            batch.set(newDoc, {
              'name': name,
              'unit': unit,
              'stock': 0.0,
              'reservedStock': 0.0,
              'prices': prices.map((p) => p.toMap()).toList(),
            });
            created++;
          }
        } catch (e) {
          errors.add("Error con '$name': $e");
          skipped++;
        }
      }

      try {
        await batch.commit();
      } catch (e) {
        errors.add("Error al guardar lote ${(i ~/ batchSize) + 1}: $e");
      }
    }

    return ImportReport(
      created: created,
      updated: updated,
      skipped: skipped,
      newProvidersCreated: newProvidersCreated,
      errors: errors,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  3) EXPORTAR A EXCEL (mismo formato del archivo original)
  // ─────────────────────────────────────────────────────────────────────

  /// Exporta todos los materiales a un Excel con el mismo formato del
  /// archivo original del usuario. Cada fila es un par material-proveedor,
  /// por lo que si un material tiene 3 proveedores aparecerá en 3 filas.
  ///
  /// Retorna la ruta del archivo generado.
  Future<String> exportToExcel() async {
    final materials = await _materialService.getMaterials().first;

    final excel = Excel.createExcel();
    // Renombrar la hoja por defecto a 'Hoja1' como el original
    final defaultSheet = excel.getDefaultSheet()!;
    excel.rename(defaultSheet, 'Hoja1');
    final sheet = excel['Hoja1'];

    // ── Header con estilo ──
    final headers = [
      'Codigo de Articulo',
      'Estatus',
      'Etiqueta',
      'Proveedores',
      'Marca',
      'Modelo',
      'Descripcion',
      'Articulo / Modelo',
      'Unidad',
      'Costo',
      'Stock',
      'Stock Apartado',
      'Stock Disponible',
    ];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // ── Filas de datos ──
    int rowIdx = 1;
    int counter = 1;

    // Ordenar alfabéticamente
    materials.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (final m in materials) {
      if (m.prices.isEmpty) {
        // Material sin proveedores: 1 fila con proveedor vacío
        _writeRow(sheet, rowIdx, [
          'SD-$counter',
          'Activo',
          'SDI',
          '',
          '',
          '',
          m.name,
          m.name,
          m.unit,
          0.0,
          m.stock,
          m.reservedStock,
          m.availableStock,
        ]);
        rowIdx++;
      } else {
        // Una fila por cada proveedor
        for (final p in m.prices) {
          _writeRow(sheet, rowIdx, [
            'SD-$counter',
            'Activo',
            'SDI',
            p.providerName,
            '',
            '',
            m.name,
            m.name,
            m.unit,
            p.price,
            m.stock,
            m.reservedStock,
            m.availableStock,
          ]);
          rowIdx++;
        }
      }
      counter++;
    }

    // Anchos de columna aproximados
    sheet.setColumnWidth(0, 18); // Codigo
    sheet.setColumnWidth(1, 10); // Estatus
    sheet.setColumnWidth(2, 10); // Etiqueta
    sheet.setColumnWidth(3, 20); // Proveedores
    sheet.setColumnWidth(6, 40); // Descripcion
    sheet.setColumnWidth(7, 40); // Articulo / Modelo
    sheet.setColumnWidth(8, 10); // Unidad
    sheet.setColumnWidth(9, 12); // Costo
    sheet.setColumnWidth(10, 10);
    sheet.setColumnWidth(11, 14);
    sheet.setColumnWidth(12, 14);

    // ── Guardar y abrir (multiplataforma con FileSaver) ──
    final bytes = excel.save();
    if (bytes == null) throw Exception("No se pudo generar el archivo");

    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'MATERIALES_$timestamp';

    // FileSaver funciona en TODAS las plataformas:
    // - Web: descarga vía navegador
    // - Android/iOS: abre diálogo de guardado
    // - Windows/Mac/Linux: abre "Guardar como"
    final savedPath = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    return savedPath;
  }

  // ─────────────────────────────────────────────────────────────────────
  //  HELPERS PRIVADOS
  // ─────────────────────────────────────────────────────────────────────

  void _writeRow(Sheet sheet, int rowIdx, List<dynamic> values) {
    for (int i = 0; i < values.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIdx));
      final v = values[i];
      if (v is num) {
        cell.value = DoubleCellValue(v.toDouble());
      } else {
        cell.value = TextCellValue(v?.toString() ?? '');
      }
    }
  }

  /// Localiza las columnas del Excel buscando los headers por aliases.
  Map<String, int?> _mapColumns(List<Data?> headerRow) {
    final result = <String, int?>{
      'name': null,
      'unit': null,
      'provider': null,
      'price': null,
    };

    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null) continue;
      final text = cell.value?.toString().toLowerCase().trim() ?? '';
      if (text.isEmpty) continue;

      for (final entry in _columnAliases.entries) {
        if (entry.value.any((alias) => text == alias)) {
          result[entry.key] = i;
          break;
        }
      }
    }
    return result;
  }

  /// Lee una celda como string manejando todos los tipos posibles.
  String _cellString(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return '';
    final cell = row[col];
    if (cell == null || cell.value == null) return '';
    final v = cell.value;
    if (v is DoubleCellValue) return v.value.toString();
    if (v is IntCellValue) return v.value.toString();
    if (v is TextCellValue) return v.value.text ?? '';
    return v.toString();
  }

  /// Parsea un string numérico tolerando comas, símbolos de moneda, etc.
  double? _parseDouble(String s) {
    if (s.isEmpty) return null;
    final cleaned = s
        .replaceAll(RegExp(r'[^\d.\-]'), '') // quitar $, comas, espacios
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}