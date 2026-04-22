import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:ici_process/core/utils/web_utils.dart';
import 'package:ici_process/models/client_model.dart';
import 'package:ici_process/models/company_settings_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// Generador de PDF para el listado de Herramientas asignadas a un Proyecto
/// Diseño compacto — mismo lenguaje visual que WorkOrderPdfGenerator
/// ════════════════════════════════════════════════════════════════════════════
class ToolsCheckoutPdfGenerator {
  // ── PALETA (idéntica a los otros generadores) ─────────────
  static const _black   = PdfColor.fromInt(0xFF000000);
  static const _white   = PdfColor.fromInt(0xFFFFFFFF);
  static const _grey50  = PdfColor.fromInt(0xFFFAFAFA);
  static const _grey100 = PdfColor.fromInt(0xFFF5F5F5);
  static const _grey200 = PdfColor.fromInt(0xFFEEEEEE);
  static const _grey300 = PdfColor.fromInt(0xFFE0E0E0);
  static const _grey400 = PdfColor.fromInt(0xFFBDBDBD);
  static const _grey600 = PdfColor.fromInt(0xFF757575);
  static const _grey700 = PdfColor.fromInt(0xFF616161);
  static const _grey800 = PdfColor.fromInt(0xFF424242);
  static const _blue    = PdfColor.fromInt(0xFF2563EB);
  static const _amber   = PdfColor.fromInt(0xFFF59E0B);
  static const _green   = PdfColor.fromInt(0xFF059669);

  static final _dateFmt = DateFormat('dd/MM/yyyy', 'es');

  // ── LAYOUT ────────────────────────────────────────────────
  static const double _margin = 14.4;
  static const double _pageW  = 612.0; // Letter

  // ═══════════════════════════════════════════════════════════════
  //  API PÚBLICA
  // ═══════════════════════════════════════════════════════════════
  static Future<void> generateAndPrint({
    required String projectId,
    required String projectTitle,
    required String clientName,
    required String responsibleName,
    required List<String> technicianNames,
    required List<Map<String, String>> tools,
    DateTime? startDate,
    DateTime? endDate,
    required CompanySettingsModel company,
    Client? client,
  }) async {
    final pdf = await _buildPdf(
      projectId: projectId,
      projectTitle: projectTitle,
      clientName: clientName,
      responsibleName: responsibleName,
      technicianNames: technicianNames,
      tools: tools,
      startDate: startDate,
      endDate: endDate,
      company: company,
      client: client,
    );

    final bytes = await pdf.save();
    final fileName = 'HERR-$projectId.pdf';

    if (kIsWeb) {
      openPdfInBrowser(bytes, fileName);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: fileName,
      );
    }
  }

  static Future<List<int>> generateBytes({
    required String projectId,
    required String projectTitle,
    required String clientName,
    required String responsibleName,
    required List<String> technicianNames,
    required List<Map<String, String>> tools,
    DateTime? startDate,
    DateTime? endDate,
    required CompanySettingsModel company,
    Client? client,
  }) async {
    final pdf = await _buildPdf(
      projectId: projectId,
      projectTitle: projectTitle,
      clientName: clientName,
      responsibleName: responsibleName,
      technicianNames: technicianNames,
      tools: tools,
      startDate: startDate,
      endDate: endDate,
      company: company,
      client: client,
    );
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONSTRUCCIÓN DEL PDF
  // ═══════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildPdf({
    required String projectId,
    required String projectTitle,
    required String clientName,
    required String responsibleName,
    required List<String> technicianNames,
    required List<Map<String, String>> tools,
    DateTime? startDate,
    DateTime? endDate,
    required CompanySettingsModel company,
    Client? client,
  }) async {
    final theme = await _buildTheme();
    final pdf = pw.Document(
      title: 'Salida de Herramientas - $projectId',
      author: company.name.isNotEmpty ? company.name : 'ICI Process',
      theme: theme,
    );

    final double contentW = _pageW - _margin * 2;

    final companyLogo = await _tryLoadImage(company.logoUrl);
    final clientLogo = await _tryLoadImage(client?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.all(_margin),
        header: (_) => _buildHeader(
          contentW,
          projectId,
          responsibleName,
          startDate,
          company,
          client,
          clientName,
          companyLogo,
          clientLogo,
        ),
        footer: (ctx) => _buildFooter(contentW, ctx),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 6),

          // ── Barra de info ──────────────────────────────────
          _buildInfoBar(contentW),

          pw.SizedBox(height: 6),

          // ── Datos del Proyecto + Cronograma ────────────────
          _buildProjectDataRow(
            contentW,
            projectId,
            projectTitle,
            clientName,
            startDate,
            endDate,
          ),

          pw.SizedBox(height: 8),

          // ── Responsable y Equipo Técnico ───────────────────
          _buildSectionBar(contentW, 'RESPONSABLE Y EQUIPO TÉCNICO'),
          _buildTeamBlock(contentW, responsibleName, technicianNames),

          pw.SizedBox(height: 8),

          // ── Listado de Herramientas ────────────────────────
          _buildSectionBar(
            contentW,
            'HERRAMIENTAS ASIGNADAS  (${tools.length})',
          ),
          _buildToolsTable(contentW, tools),

          pw.SizedBox(height: 12),

          // ── Firmas ─────────────────────────────────────────
          _buildSignatures(contentW, responsibleName),

          pw.SizedBox(height: 8),

          // ── Nota legal ─────────────────────────────────────
          _buildLegalNote(contentW),
        ],
      ),
    );

    return pdf;
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER — 3 columnas (empresa | título + metadata | cliente)
  //  Logos laterales + datos del Company Profile y del Cliente
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader(
    double w,
    String projectId,
    String responsibleName,
    DateTime? startDate,
    CompanySettingsModel company,
    Client? client,
    String fallbackClientName,
    pw.ImageProvider? companyLogo,
    pw.ImageProvider? clientLogo,
  ) {
    const headerH = 56.0;
    final centerW = w * 0.38;
    final sideW   = (w - centerW) / 2;

    return pw.Container(
      height: headerH,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: pw.Row(
        children: [
          // ── Col 1: Logo + datos empresa ──
          pw.Container(
            width: sideW,
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: _grey400, width: 0.5)),
            ),
            child: _buildCompanyBlock(sideW, company, companyLogo),
          ),

          // ── Col 2: Título + Subtítulo + Caja Metadata ──
          pw.Container(
            width: centerW,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: _grey400, width: 0.5)),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('SALIDA DE HERRAMIENTAS',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _black),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1),
                pw.SizedBox(height: 2),
                pw.Text('CONTROL DE INVENTARIO DE CAMPO',
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.3),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: _grey200,
                    border: pw.Border.all(color: _grey400, width: 0.5),
                  ),
                  child: pw.Text(
                    'EMISIÓN: ${_dateFmt.format(DateTime.now()).toUpperCase()}  |  FOLIO: HERR-${projectId.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: _black),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  startDate != null
                      ? 'Inicio: ${_dateFmt.format(startDate)}  ·  Responsable: $responsibleName'
                      : 'Responsable: $responsibleName',
                  style: const pw.TextStyle(fontSize: 4.5, color: _grey600),
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          // ── Col 3: Datos cliente + logo ──
          pw.Container(
            width: sideW,
            child: _buildClientBlock(sideW, client, fallbackClientName, clientLogo),
          ),
        ],
      ),
    );
  }

  // ── Bloque empresa (Col 1): logo izq + datos der ────────────
  static pw.Widget _buildCompanyBlock(
    double w,
    CompanySettingsModel company,
    pw.ImageProvider? logo,
  ) {
    const logoW = 42.0;
    const logoH = 42.0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: logoW,
              height: logoH,
              margin: const pw.EdgeInsets.only(right: 4),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  company.name.isNotEmpty ? company.name : 'ICI Process',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
                  maxLines: 1,
                ),
                if (company.legalName.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(company.legalName,
                      style: const pw.TextStyle(fontSize: 4.5, color: _grey700),
                      maxLines: 1),
                ],
                if (company.address.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(company.address,
                      style: const pw.TextStyle(fontSize: 4, color: _grey700),
                      maxLines: 2),
                ],
                if (company.phone.isNotEmpty || company.email.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    [
                      if (company.phone.isNotEmpty) 'Tel: ${company.phone}',
                      if (company.email.isNotEmpty) company.email,
                    ].join('  ·  '),
                    style: const pw.TextStyle(fontSize: 4, color: _grey600),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bloque cliente (Col 3): datos izq + logo der ────────────
  static pw.Widget _buildClientBlock(
    double w,
    Client? client,
    String fallbackName,
    pw.ImageProvider? logo,
  ) {
    const logoW = 42.0;
    const logoH = 42.0;
    final displayName = client?.name.isNotEmpty == true ? client!.name : fallbackName;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  displayName,
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
                  textAlign: pw.TextAlign.right,
                  maxLines: 1,
                ),
                if (client != null && client.businessName.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(client.businessName,
                      style: const pw.TextStyle(fontSize: 4.5, color: _grey700),
                      textAlign: pw.TextAlign.right,
                      maxLines: 1),
                ],
                if (client != null && client.billingAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(client.billingAddress,
                      style: const pw.TextStyle(fontSize: 4, color: _grey700),
                      textAlign: pw.TextAlign.right,
                      maxLines: 2),
                ],
                if (client != null && (client.phone.isNotEmpty || client.email.isNotEmpty)) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    [
                      if (client.phone.isNotEmpty) 'Tel: ${client.phone}',
                      if (client.email.isNotEmpty) client.email,
                    ].join('  ·  '),
                    style: const pw.TextStyle(fontSize: 4, color: _grey600),
                    textAlign: pw.TextAlign.right,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          if (logo != null)
            pw.Container(
              width: logoW,
              height: logoH,
              margin: const pw.EdgeInsets.only(left: 4),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
        ],
      ),
    );
  }

  // ── Helper: cargar imagen desde URL con fallback seguro ─────
  //  1º intento: Firebase Storage SDK (evita CORS en web)
  //  2º intento: networkImage normal
  static Future<pw.ImageProvider?> _tryLoadImage(String? url) async {
    if (url == null || url.isEmpty) return null;

    if (url.contains('firebasestorage.googleapis.com') || url.startsWith('gs://')) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final bytes = await ref.getData(10 * 1024 * 1024);
        if (bytes != null) return pw.MemoryImage(bytes);
      } catch (_) {
        // cae al fallback
      }
    }

    try {
      return await networkImage(url);
    } catch (_) {
      return null;
    }
  }

  // ── Helper: theme con Roboto (soporta unicode: "—", "·", etc.) ──
  static Future<pw.ThemeData> _buildTheme() async {
    try {
      final base = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      final italic = await PdfGoogleFonts.robotoItalic();
      return pw.ThemeData.withFont(base: base, bold: bold, italic: italic);
    } catch (_) {
      return pw.ThemeData();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INFO BAR
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildInfoBar(double w) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _grey100,
        border: pw.Border.all(color: _grey400, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Text('EMISIÓN: ',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey600)),
          pw.Text(_dateFmt.format(DateTime.now()),
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _black)),
          pw.Spacer(),
          pw.Text('CONTROL DE INVENTARIO DE HERRAMIENTAS',
              style: const pw.TextStyle(fontSize: 5, color: _grey600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATOS DEL PROYECTO — 2 columnas
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildProjectDataRow(
    double w,
    String projectId,
    String projectTitle,
    String clientName,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final colW = (w - 4) / 2;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Datos del Proyecto ──
        pw.Container(
          width: colW,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: colW,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: _grey200,
                child: pw.Row(
                  children: [
                    pw.Container(width: 3, height: 8, color: _blue),
                    pw.SizedBox(width: 6),
                    pw.Text('DATOS DEL PROYECTO',
                        style: pw.TextStyle(
                            fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PROYECTO (ID: $projectId)',
                        style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(projectTitle,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _black)),
                    pw.SizedBox(height: 6),
                    pw.Text('CLIENTE',
                        style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(clientName,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _black)),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 4),

        // ── Cronograma ──
        pw.Container(
          width: colW,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: colW,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: _grey200,
                child: pw.Row(
                  children: [
                    pw.Container(width: 3, height: 8, color: _amber),
                    pw.SizedBox(width: 6),
                    pw.Text('CRONOGRAMA DEL PROYECTO',
                        style: pw.TextStyle(
                            fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('INICIO',
                                  style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                startDate != null ? _dateFmt.format(startDate) : 'Pendiente',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: startDate != null ? _blue : _grey600),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('FIN PROGRAMADO',
                                  style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                endDate != null ? _dateFmt.format(endDate) : 'Pendiente',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: endDate != null ? _grey800 : _grey600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('ESTADO DE LAS HERRAMIENTAS',
                        style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: _green,
                      child: pw.Text('EN USO / ASIGNADAS',
                          style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BLOQUE RESPONSABLE + EQUIPO
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildTeamBlock(
    double w,
    String responsibleName,
    List<String> technicianNames,
  ) {
    return pw.Container(
      width: w,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Responsable
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 80,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RESPONSABLE',
                          style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        color: _grey800,
                        child: pw.Text('A CARGO',
                            style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: _white)),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    responsibleName.isNotEmpty ? responsibleName : '—',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _black),
                  ),
                ),
              ],
            ),
          ),
          pw.Container(height: 0.5, color: _grey300),

          // Equipo técnico
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 80,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EQUIPO TÉCNICO',
                          style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('${technicianNames.length} ${technicianNames.length == 1 ? "persona" : "personas"}',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _blue)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: technicianNames.isEmpty
                      ? pw.Text('Sin personal asignado',
                          style: const pw.TextStyle(fontSize: 7, color: _grey600))
                      : pw.Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: technicianNames.map((name) {
                            return pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: _grey100,
                                border: pw.Border.all(color: _grey300, width: 0.5),
                              ),
                              child: pw.Text(name,
                                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _grey800)),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TABLA DE HERRAMIENTAS
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildToolsTable(double w, List<Map<String, String>> tools) {
    if (tools.isEmpty) {
      return pw.Container(
        width: w,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _grey300, width: 0.5),
        ),
        child: pw.Text('Sin herramientas asignadas a este proyecto.',
            style: const pw.TextStyle(fontSize: 7, color: _grey600),
            textAlign: pw.TextAlign.center),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),   // #
        1: const pw.FlexColumnWidth(3.5),   // Nombre
        2: const pw.FlexColumnWidth(2.2),   // Marca / Modelo
        3: const pw.FlexColumnWidth(2.0),   // Serie / ID
        4: const pw.FixedColumnWidth(50),   // Revisión (check)
      },
      children: [
        // ── Cabecera ──
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _grey200),
          children: [
            _tableHeader('#', center: true),
            _tableHeader('HERRAMIENTA'),
            _tableHeader('MARCA / MODELO'),
            _tableHeader('ID / SERIE'),
            _tableHeader('REVISIÓN', center: true),
          ],
        ),

        // ── Filas ──
        ...tools.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final isEven = i % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? _white : _grey50),
            children: [
              // #
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: pw.Text(
                  '${i + 1}',
                  style: const pw.TextStyle(fontSize: 6, color: _grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Nombre
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(
                  t['name'] ?? '—',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
                ),
              ),
              // Marca
              _tableCell(
                t['brand']?.isNotEmpty == true ? t['brand']! : '—',
                muted: t['brand']?.isEmpty != false,
              ),
              // Serie
              _tableCell(
                t['serial']?.isNotEmpty == true ? t['serial']! : '—',
                muted: t['serial']?.isEmpty != false,
              ),
              // Checkbox de revisión (vacío para llenar a mano)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: pw.Center(
                  child: pw.Container(
                    width: 14,
                    height: 14,
                    decoration: pw.BoxDecoration(
                      color: _white,
                      border: pw.Border.all(color: _grey400, width: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SECTION BAR
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildSectionBar(double w, String title) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const pw.BoxDecoration(color: _grey800),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _white, letterSpacing: 0.8),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FIRMAS — 2 columnas (Responsable + Almacén)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildSignatures(double w, String responsibleName) {
    final sigW = (w - 6) / 2;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            width: w,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: _grey200,
            child: pw.Text('FIRMAS DE RESPONSABILIDAD',
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
          ),
          pw.Container(height: 0.5, color: _grey400),
          // Slots
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signatureSlot(
                  sigW,
                  'Entregó',
                  'Responsable de almacén',
                  subname: null,
                ),
                pw.Container(width: 0.5, height: 50, color: _grey300),
                _signatureSlot(
                  sigW,
                  'Recibió',
                  'Responsable del proyecto',
                  subname: responsibleName.isNotEmpty ? responsibleName : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureSlot(
    double slotW,
    String title,
    String subtitle, {
    String? subname,
  }) {
    return pw.Container(
      width: slotW,
      child: pw.Column(
        children: [
          pw.SizedBox(height: 32),
          pw.Container(width: slotW * 0.85, height: 0.5, color: _grey400),
          pw.SizedBox(height: 4),
          if (subname != null) ...[
            pw.Text(subname,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 1),
          ],
          pw.Text(title,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 1),
          pw.Text(subtitle,
              style: const pw.TextStyle(fontSize: 5, color: _grey600),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOTA LEGAL
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildLegalNote(double w) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: _grey100,
        border: pw.Border(left: pw.BorderSide(color: _grey800, width: 2)),
      ),
      child: pw.Text(
        'El responsable del proyecto declara haber recibido las herramientas aquí listadas en buen estado '
        'y se compromete a devolverlas en las mismas condiciones al finalizar el servicio. Cualquier daño, '
        'pérdida o extravío deberá ser reportado de inmediato al área de almacén de ICI Process.',
        style: const pw.TextStyle(fontSize: 5.5, color: _grey600, lineSpacing: 2),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FOOTER
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildFooter(double w, pw.Context ctx) {
    return pw.Container(
      width: w,
      decoration: pw.BoxDecoration(
        color: _grey100,
        border: pw.Border.all(color: _grey400, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Container(height: 1.5, color: _grey800),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ICI Process S.A. de C.V.  —  Documento Confidencial',
                    style: const pw.TextStyle(fontSize: 5, color: _grey600)),
                pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: _grey800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS DE TABLA
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _tableHeader(String text, {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.3),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool center = false, bool muted = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, color: muted ? _grey600 : _black),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }
}