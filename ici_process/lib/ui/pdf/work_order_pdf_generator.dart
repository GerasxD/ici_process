import 'package:flutter/foundation.dart';
import 'package:ici_process/core/utils/web_utils.dart';
import 'package:ici_process/models/client_model.dart';
import 'package:ici_process/models/company_settings_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// Generador de PDF para Órdenes de Trabajo
/// Diseño compacto y utilitario — misma armonía visual que la Orden de Compra
/// ════════════════════════════════════════════════════════════════════════════
class WorkOrderPdfGenerator {
  // ── PALETA (idéntica a PurchaseOrderPdfGenerator) ─────────
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
  static const _red     = PdfColor.fromInt(0xFFF44336);
  static const _blue    = PdfColor.fromInt(0xFF2563EB);
  static const _amber   = PdfColor.fromInt(0xFFF59E0B);

  static final _dateFmt = DateFormat('dd/MM/yyyy', 'es');

  // ── CONSTANTES DE LAYOUT ──────────────────────────────────
  static const double _margin  = 14.4;
  static const double _pageW   = 612.0; // Letter

  // ── API PÚBLICA ───────────────────────────────────────────
  static Future<void> generateAndPrint({
    required String projectTitle,
    required String clientName,
    required String description,
    required String priority,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<Map<String, String>> technicians,
    required String notes,
    required String folio,
    required CompanySettingsModel company,
    Client? client,
  }) async {
    final pdf = await _buildPdf(
      projectTitle: projectTitle,
      clientName: clientName,
      description: description,
      priority: priority,
      startDate: startDate,
      endDate: endDate,
      technicians: technicians,
      notes: notes,
      folio: folio,
      company: company,
      client: client,
    );

    final bytes = await pdf.save();
    final fileName = 'OT-$folio.pdf';

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
    required String projectTitle,
    required String clientName,
    required String description,
    required String priority,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<Map<String, String>> technicians,
    required String notes,
    required String folio,
    required CompanySettingsModel company,
    Client? client,
  }) async {
    final pdf = await _buildPdf(
      projectTitle: projectTitle,
      clientName: clientName,
      description: description,
      priority: priority,
      startDate: startDate,
      endDate: endDate,
      technicians: technicians,
      notes: notes,
      folio: folio,
      company: company,
      client: client,
    );
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONSTRUCCIÓN DEL PDF
  // ═══════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildPdf({
    required String projectTitle,
    required String clientName,
    required String description,
    required String priority,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<Map<String, String>> technicians,
    required String notes,
    required String folio,
    required CompanySettingsModel company,
    Client? client,
  }) async {
    final pdf = pw.Document(
      title: 'Orden de Trabajo $folio',
      author: company.name.isNotEmpty ? company.name : 'ICI Process',
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
          folio,
          startDate,
          priority,
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
          _buildInfoBar(contentW, folio, startDate),

          pw.SizedBox(height: 6),

          // ── Datos: Proyecto + Clasificación (2 columnas) ──
          _buildDataRow(contentW, projectTitle, clientName, priority, startDate, endDate),

          pw.SizedBox(height: 8),

          // ── Descripción ────────────────────────────────────
          _buildSectionBar(contentW, 'ALCANCE Y DESCRIPCIÓN'),
          _buildDescriptionBlock(contentW, description),

          pw.SizedBox(height: 8),

          // ── Personal asignado ─────────────────────────────
          _buildSectionBar(contentW, 'PERSONAL ASIGNADO'),
          _buildPersonnelTable(contentW, technicians),

          // ── Indicaciones especiales (si aplica) ───────────
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _buildSectionBar(contentW, 'INDICACIONES ESPECIALES'),
            _buildNotesBlock(contentW, notes),
          ],

          pw.SizedBox(height: 12),

          // ── Firmas ────────────────────────────────────────
          _buildSignatures(contentW),

          pw.SizedBox(height: 8),

          // ── Nota legal ────────────────────────────────────
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
    String folio,
    DateTime? startDate,
    String priority,
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
                pw.Text('ORDEN DE TRABAJO',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _black),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1),
                pw.SizedBox(height: 2),
                pw.Text('PLANIFICACIÓN DE SERVICIO EN CAMPO',
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
                    'INICIO: ${_dateFmt.format(startDate ?? DateTime.now()).toUpperCase()}  |  FOLIO: ${folio.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: _black),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text('Prioridad: ${priority.toUpperCase()}',
                    style: const pw.TextStyle(fontSize: 4.5, color: _grey600),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1),
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
  static Future<pw.ImageProvider?> _tryLoadImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      return await networkImage(url);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INFO BAR
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildInfoBar(double w, String folio, DateTime? startDate) {
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
          pw.Text('DOCUMENTO OFICIAL DE TRABAJO',
              style: const pw.TextStyle(fontSize: 5, color: _grey600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATOS — Proyecto + Clasificación (2 columnas)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildDataRow(
    double w,
    String projectTitle,
    String clientName,
    String priority,
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
                    pw.Text('PROYECTO',
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

        // ── Clasificación + Fechas ──
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
                    pw.Text('CLASIFICACIÓN Y CRONOGRAMA',
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
                    // Prioridad + Tipo en fila
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('PRIORIDAD',
                                  style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              // 👇 Se eliminó el Container con fondo _grey800 y se dejó el texto en _black igual que "TIPO"
                              pw.Text(priority,
                                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black)),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('TIPO',
                                  style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text('Servicio en Campo',
                                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    // Fechas en fila
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
                                    fontSize: 7,
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
                                    fontSize: 7,
                                    fontWeight: pw.FontWeight.bold,
                                    color: endDate != null ? _grey800 : _grey600),
                              ),
                            ],
                          ),
                        ),
                      ],
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
  //  SECTION BAR — Barra oscura (idéntica a PurchaseOrder)
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
  //  DESCRIPCIÓN — Bloque de texto
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildDescriptionBlock(double w, String description) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _grey50,
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Text(
        description.isNotEmpty ? description : 'Sin descripción registrada.',
        style: const pw.TextStyle(fontSize: 7, color: _black, lineSpacing: 2.5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TABLA DE PERSONAL — Misma densidad que la tabla de materiales
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildPersonnelTable(double w, List<Map<String, String>> technicians) {
    if (technicians.isEmpty) {
      return pw.Container(
        width: w,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _grey300, width: 0.5),
        ),
        child: pw.Text('Sin personal asignado.',
            style: const pw.TextStyle(fontSize: 7, color: _grey600)),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),       // #
        1: const pw.FlexColumnWidth(3.5),       // Nombre
        2: const pw.FlexColumnWidth(2.0),       // NSS
        3: const pw.FlexColumnWidth(1.2),       // Tipo Sangre
        4: const pw.FlexColumnWidth(2.0),       // Contacto
      },
      children: [
        // ── Cabecera ──
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _grey200),
          children: [
            _tableHeader('#', center: true),
            _tableHeader('NOMBRE / TÉCNICO'),
            _tableHeader('NSS', center: true),
            _tableHeader('SANGRE', center: true),
            _tableHeader('CONTACTO EMERGENCIA'),
          ],
        ),

        // ── Filas ──
        ...technicians.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final isEven = i % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? _white : _grey50),
            children: [
              // #
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: pw.Text(
                  '${i + 1}',
                  style: const pw.TextStyle(fontSize: 6, color: _grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Nombre
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(
                  t['name'] ?? '—',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
                ),
              ),
              // NSS
              _tableCell(
                t['nss']?.isNotEmpty == true ? t['nss']! : '—',
                center: true,
                muted: t['nss']?.isEmpty != false,
              ),
              // Tipo de sangre
              _buildBloodTypeCell(t['bloodType'] ?? ''),
              // Contacto
              _buildEmergencyCell(t['emergencyPhone'] ?? ''),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildBloodTypeCell(String bloodType) {
    final hasValue = bloodType.isNotEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: hasValue
          ? pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFEBEE),
                border: pw.Border.all(color: _red, width: 0.5),
              ),
              child: pw.Text(
                bloodType,
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _red),
                textAlign: pw.TextAlign.center,
              ),
            )
          : pw.Text('—',
              style: const pw.TextStyle(fontSize: 7, color: _grey400),
              textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _buildEmergencyCell(String phone) {
    final hasValue = phone.isNotEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        hasValue ? phone : '—',
        style: pw.TextStyle(
          fontSize: 7,
          color: hasValue ? _grey800 : _grey400,
          fontWeight: hasValue ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  INDICACIONES ESPECIALES — Mismo patrón de bloque con borde
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildNotesBlock(double w, String notes) {
    return pw.Container(
      width: w,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _amber, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: w,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: const PdfColor.fromInt(0xFFFFFBEB),
            child: pw.Text('ATENCIÓN',
                style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: _amber, letterSpacing: 0.5)),
          ),
          pw.Container(height: 0.5, color: _amber),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              notes,
              style: const pw.TextStyle(fontSize: 7, color: _black, lineSpacing: 2.5),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FIRMAS — Idéntico al estilo de PurchaseOrder
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildSignatures(double w) {
    const sigH = 55.0;
    final sigW = (w - 10) / 3;

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
            child: pw.Text('FIRMAS DE AUTORIZACIÓN',
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
          ),
          pw.Container(height: 0.5, color: _grey400),
          // Slots de firma
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signatureSlot(sigW, 'Elaboró', 'Responsable de logística'),
                pw.Container(width: 0.5, height: sigH - 10, color: _grey300),
                _signatureSlot(sigW, 'Supervisor', 'Gerente de proyecto'),
                pw.Container(width: 0.5, height: sigH - 10, color: _grey300),
                _signatureSlot(sigW, 'Recibió en Sitio', 'Contacto del cliente'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureSlot(double slotW, String title, String subtitle) {
    return pw.Container(
      width: slotW,
      child: pw.Column(
        children: [
          pw.SizedBox(height: 28),
          pw.Container(width: slotW * 0.85, height: 0.5, color: _grey400),
          pw.SizedBox(height: 4),
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
  //  NOTA LEGAL — Idéntica a PurchaseOrder (borde izquierdo)
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
        'Esta orden de trabajo es un documento oficial emitido por ICI Process. '
        'El personal asignado deberá presentar este documento al llegar al sitio del cliente. '
        'Cualquier modificación al alcance debe ser autorizada por escrito por el supervisor del proyecto.',
        style: const pw.TextStyle(fontSize: 5.5, color: _grey600, lineSpacing: 2),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FOOTER — Idéntico a PurchaseOrder
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
  //  HELPERS DE TABLA (idénticos a PurchaseOrder)
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, color: muted ? _grey600 : _black),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }
}