import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:ici_process/core/utils/web_utils.dart';

class WorkOrderPdfGenerator {
  // ── PALETA DE COLORES ─────────────────────────────────────
  // ignore: unused_field
  static const PdfColor _ink = PdfColor.fromInt(0xFF0A0F1E);
  static const PdfColor _navy = PdfColor.fromInt(0xFF1B2A4A);
  static const PdfColor _orange = PdfColor.fromInt(0xFFC2410C);
  static const PdfColor _orangeLight = PdfColor.fromInt(0xFFFFEDD5);
  static const PdfColor _blue = PdfColor.fromInt(0xFF2563EB);
  // ignore: unused_field
  static const PdfColor _blueLight = PdfColor.fromInt(0xFFEFF6FF);
  // ignore: unused_field
  static const PdfColor _green = PdfColor.fromInt(0xFF059669);
  // ignore: unused_field
  static const PdfColor _greenLight = PdfColor.fromInt(0xFFECFDF5);
  static const PdfColor _teal = PdfColor.fromInt(0xFF0D9488);
  static const PdfColor _amber = PdfColor.fromInt(0xFFD97706);
  static const PdfColor _slate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _slate400 = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor _slate600 = PdfColor.fromInt(0xFF475569);
  static const PdfColor _slate800 = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);

  static final _dateFmt = DateFormat('dd/MM/yyyy', 'es');

  // ── API PÚBLICA ───────────────────────────────────────────
  static Future<void> generateAndPrint({
    required String projectTitle,
    required String clientName,
    required String description,
    required String priority,
    required DateTime? startDate,
    required DateTime? endDate,
    required DateTime? realCompletionDate,
    required List<Map<String, String>> technicians,
    required List<String> toolNames,
    required List<Map<String, String>> materials,
    required String notes,
    required String folio,
  }) async {
    final pdf = await _buildPdf(
      projectTitle: projectTitle,
      clientName: clientName,
      description: description,
      priority: priority,
      startDate: startDate,
      endDate: endDate,
      realCompletionDate: realCompletionDate,
      technicians: technicians,
      toolNames: toolNames,
      materials: materials,
      notes: notes,
      folio: folio,
    );

    final bytes = await pdf.save();
    final fileName = 'OrdenTrabajo-$folio.pdf';

    if (kIsWeb) {
      // ── Flutter Web: abre el PDF en nueva pestaña del navegador ──
      _openPdfInBrowser(bytes, fileName);
    } else {
      // ── Mobile / Desktop: diálogo de impresión nativo ──
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: fileName,
      );
    }
  }

  static void _openPdfInBrowser(List<int> bytes, String fileName) {
    // La función correcta se resuelve automáticamente por el import condicional
    openPdfInBrowser(bytes, fileName);
  }

  // ── CONSTRUCCIÓN INTERNA ──────────────────────────────────
  static Future<pw.Document> _buildPdf({
    required String projectTitle,
    required String clientName,
    required String description,
    required String priority,
    required DateTime? startDate,
    required DateTime? endDate,
    required DateTime? realCompletionDate,
    required List<Map<String, String>> technicians,
    required List<String> toolNames,
    required List<Map<String, String>> materials,
    required String notes,
    required String folio,
  }) async {
    final pdf = pw.Document(
      title: 'Orden de Trabajo $folio',
      author: 'ICI Process',
      subject: 'Orden de Trabajo - $projectTitle',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (pw.Context ctx) => _buildHeader(folio, startDate),
        footer: (pw.Context ctx) => _buildFooter(ctx),
        build: (pw.Context ctx) => [
          // Banda decorativa
          _buildAccentBand(),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 22),

                // ── 1. Datos del Proyecto ──
                _buildProjectInfo(projectTitle, clientName, priority),

                pw.SizedBox(height: 20),

                // ── 2. Alcance y Descripción ──
                _buildDescriptionSection(description),

                pw.SizedBox(height: 20),

                // ── 3. Cronograma ──
                _buildScheduleSection(startDate, endDate, realCompletionDate),

                pw.SizedBox(height: 20),

                // ── 4. Personal Asignado ──
                _buildPersonnelSection(technicians),

                pw.SizedBox(height: 20),

                pw.SizedBox(height: 0),

                // ── 7. Notas / Indicaciones ──
                if (notes.isNotEmpty) ...[
                  _buildNotesSection(notes),
                  pw.SizedBox(height: 20),
                ],

                // ── 8. Firmas ──
                pw.SizedBox(height: 12),
                _buildSignatureBlock(),

                pw.SizedBox(height: 20),

                // ── 9. Nota legal ──
                _buildLegalNote(),

                pw.SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // ── HEADER ────────────────────────────────────────────────
  static pw.Widget _buildHeader(String folio, DateTime? startDate) {
    return pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 4, height: 28, color: _orange),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ICI PROCESS',
                        style: pw.TextStyle(
                          color: _white,
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                      pw.Text(
                        'GESTIÓN EMPRESARIAL INTEGRAL',
                        style: pw.TextStyle(
                          color: _slate400,
                          fontSize: 6.5,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                children: [
                  _metaChip('Fecha emisión', startDate != null ? _dateFmt.format(DateTime.now()) : '—'),
                  pw.SizedBox(width: 10),
                  _metaChip('Tipo', 'ORDEN DE TRABAJO'),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'ORDEN DE TRABAJO',
                style: pw.TextStyle(
                  color: _slate400,
                  fontSize: 7,
                  letterSpacing: 2.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: _orange,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  '# $folio',
                  style: pw.TextStyle(
                    color: _white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF243050),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 7, color: _slate400)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 7, color: _white, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── BANDA DECORATIVA ──────────────────────────────────────
  static pw.Widget _buildAccentBand() {
    return pw.Row(
      children: [
        pw.Expanded(flex: 5, child: pw.Container(height: 3, color: _orange)),
        pw.Expanded(flex: 2, child: pw.Container(height: 3, color: _teal)),
        pw.Expanded(flex: 1, child: pw.Container(height: 3, color: _amber)),
      ],
    );
  }

  // ── 1. DATOS DEL PROYECTO ─────────────────────────────────
  static pw.Widget _buildProjectInfo(String title, String client, String priority) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildInfoCard(
            iconColor: _orange,
            title: 'DATOS DEL PROYECTO',
            children: [
              _infoField('Proyecto', title),
              pw.SizedBox(height: 6),
              _infoField('Cliente', client),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: _buildInfoCard(
            iconColor: _blue,
            title: 'PRIORIDAD Y CLASIFICACIÓN',
            children: [
              _infoField('Prioridad', priority),
              pw.SizedBox(height: 6),
              _infoField('Tipo', 'Servicio en Campo'),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2. DESCRIPCIÓN ────────────────────────────────────────
  static pw.Widget _buildDescriptionSection(String description) {
    return _buildSectionContainer(
      title: 'ALCANCE Y DESCRIPCIÓN DEL PROYECTO',
      iconColor: _blue,
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _slate100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          description.isNotEmpty ? description : 'Sin descripción registrada.',
          style: pw.TextStyle(fontSize: 10, color: _slate800, lineSpacing: 4),
        ),
      ),
    );
  }

  // ── 3. CRONOGRAMA ─────────────────────────────────────────
 static pw.Widget _buildScheduleSection(
      DateTime? start, DateTime? end, DateTime? realCompletion) {
    return _buildSectionContainer(
      title: 'CRONOGRAMA DE EJECUCIÓN',
      iconColor: _teal,
      child: pw.Row(
        children: [
          pw.Expanded(child: _dateBox('Inicio Programado', start, _blue)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _dateBox('Fin Programado', end, _orange)),
        ],
      ),
    );
  }

  static pw.Widget _dateBox(String label, DateTime? date, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _slate200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              color: _slate400,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            date != null ? _dateFmt.format(date) : 'Pendiente',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: date != null ? color : _slate400,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. PERSONAL ASIGNADO ──────────────────────────────────
  static pw.Widget _buildPersonnelSection(List<Map<String, String>> technicians) {
    return _buildSectionContainer(
      title: 'PERSONAL ASIGNADO',
      iconColor: _orange,
      child: technicians.isEmpty
          ? pw.Text('Sin personal asignado.',
              style: pw.TextStyle(fontSize: 10, color: _slate400))
          : pw.Table(
              border: pw.TableBorder(
                left: pw.BorderSide(color: _slate200, width: 0.5),
                right: pw.BorderSide(color: _slate200, width: 0.5),
                bottom: pw.BorderSide(color: _slate200, width: 0.5),
                horizontalInside: pw.BorderSide(color: _slate200, width: 0.3),
                verticalInside: pw.BorderSide(color: _slate200, width: 0.3),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),  // #
                1: const pw.FlexColumnWidth(3),    // Nombre
                2: const pw.FlexColumnWidth(2),    // NSS
                3: const pw.FlexColumnWidth(1),    // Tipo de Sangre
                4: const pw.FlexColumnWidth(2),    // Contacto Emergencia
              },
              children: [
                // ── Encabezado ──
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _navy),
                  children: [
                    _tableHeaderWhite('#'),
                    _tableHeaderWhite('NOMBRE'),
                    _tableHeaderWhite('NSS'),
                    _tableHeaderWhite('TIPO DE SANGRE'),
                    _tableHeaderWhite('NUMERO DE EMERGENCIA'),
                  ],
                ),
                // ── Filas ──
                ...technicians.asMap().entries.map((entry) {
                  final t = entry.value;
                  final isEven = entry.key % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? _white : _slate100,
                    ),
                    children: [
                      _tableCell('${entry.key + 1}', centered: true),
                      _tableCellBold(t['name'] ?? '—'),
                      _tableCell(t['nss']?.isNotEmpty == true ? t['nss']! : '—'),
                      _tableCellBloodType(t['bloodType'] ?? ''),
                      _tableCellEmergency(t['emergencyPhone'] ?? ''),
                    ],
                  );
                }),
              ],
            ),
    );
  }

  // ── 7. NOTAS ──────────────────────────────────────────────
  static pw.Widget _buildNotesSection(String notes) {
    return _buildSectionContainer(
      title: 'INDICACIONES ESPECIALES',
      iconColor: _slate600,
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _orangeLight,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFFDBA74), width: 0.5),
        ),
        child: pw.Text(
          notes,
          style: pw.TextStyle(fontSize: 10, color: _slate800, lineSpacing: 3),
        ),
      ),
    );
  }

  // ── 8. FIRMAS ─────────────────────────────────────────────
  static pw.Widget _buildSignatureBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _slate100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _slate200, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _signatureSlot('Elaboró', 'Responsable de logística'),
          _verticalSeparator(),
          _signatureSlot('Supervisor', 'Gerente de proyecto'),
          _verticalSeparator(),
          _signatureSlot('Recibió en Sitio', 'Contacto del cliente'),
        ],
      ),
    );
  }

  static pw.Widget _signatureSlot(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 130, height: 38),
        pw.Container(width: 130, height: 1, color: _navy),
        pw.SizedBox(height: 6),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _slate800)),
        pw.SizedBox(height: 2),
        pw.Text(subtitle, style: pw.TextStyle(fontSize: 7, color: _slate400)),
      ],
    );
  }

  static pw.Widget _verticalSeparator() {
    return pw.Container(width: 0.5, height: 60, color: _slate200);
  }

  // ── 9. NOTA LEGAL ─────────────────────────────────────────
  static pw.Widget _buildLegalNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: _orange, width: 3)),
        color: _orangeLight,
      ),
      child: pw.Text(
        'Esta orden de trabajo es un documento oficial emitido por ICI Process. '
        'El personal asignado deberá presentar este documento al llegar al sitio del cliente. '
        'Cualquier modificación al alcance debe ser autorizada por el supervisor del proyecto.',
        style: pw.TextStyle(fontSize: 7.5, color: _slate600, lineSpacing: 2.5),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  // ── FOOTER ────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 3, height: 3, color: _orange),
              pw.SizedBox(width: 6),
              pw.Text(
                'ICI Process S.A. de C.V.  —  Orden de Trabajo Confidencial',
                style: pw.TextStyle(fontSize: 7, color: _slate400),
              ),
            ],
          ),
          pw.Text(
            'Pág. ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: _slate400, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────
  static pw.Widget _buildInfoCard({
    required PdfColor iconColor,
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _slate100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _slate200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: pw.BoxDecoration(
              color: _white,
              border: pw.Border(bottom: pw.BorderSide(color: _slate200, width: 1)),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 3, height: 12,
                  decoration: pw.BoxDecoration(color: iconColor, borderRadius: pw.BorderRadius.circular(2)),
                ),
                pw.SizedBox(width: 8),
                pw.Text(title,
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _slate600, letterSpacing: 1)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style: pw.TextStyle(fontSize: 6.5, color: _slate400, letterSpacing: 1, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 10.5, color: _slate800, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildSectionContainer({
    required String title,
    required PdfColor iconColor,
    required pw.Widget child,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: pw.BoxDecoration(
                color: _navy,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Container(width: 3, height: 10, color: iconColor),
                  pw.SizedBox(width: 8),
                  pw.Text(title,
                      style: pw.TextStyle(color: _white, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
                ],
              ),
            ),
            pw.Expanded(child: pw.Container(height: 1, color: _slate200)),
          ],
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _slate200, width: 0.5),
            borderRadius: const pw.BorderRadius.only(
              topRight: pw.Radius.circular(8),
              bottomLeft: pw.Radius.circular(8),
              bottomRight: pw.Radius.circular(8),
            ),
          ),
          child: child,
        ),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool centered = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, color: _slate800),
          textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left),
    );
  }

  static pw.Widget _tableHeaderWhite(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: _white,
          letterSpacing: 0.5,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableCellBold(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: _slate800,
        ),
      ),
    );
  }

  static pw.Widget _tableCellBloodType(String bloodType) {
    final bool hasValue = bloodType.isNotEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: hasValue
          ? pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFFE4E6), // rojo claro
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                bloodType,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFDC2626),
                ),
                textAlign: pw.TextAlign.center,
              ),
            )
          : pw.Text('—', style: pw.TextStyle(fontSize: 9, color: _slate400), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _tableCellEmergency(String phone) {
    final bool hasValue = phone.isNotEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        hasValue ? phone : '—',
        style: pw.TextStyle(
          fontSize: 9,
          color: hasValue ? PdfColor.fromInt(0xFFFF6B35) : _slate400,
          fontWeight: hasValue ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}