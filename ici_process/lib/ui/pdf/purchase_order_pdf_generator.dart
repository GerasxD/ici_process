import 'package:ici_process/models/purchase_order_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PurchaseOrderPdfGenerator {
  // ── PALETA DE COLORES REFINADA ────────────────────────────
  static const PdfColor _ink = PdfColor.fromInt(0xFF0A0F1E);       // Negro azulado premium
  static const PdfColor _navy = PdfColor.fromInt(0xFF1B2A4A);      // Azul marino profundo
  static const PdfColor _blue = PdfColor.fromInt(0xFF2563EB);      // Azul acción
  static const PdfColor _blueMid = PdfColor.fromInt(0xFF3B82F6);   // Azul medio
  static const PdfColor _blueLight = PdfColor.fromInt(0xFFEFF6FF); // Azul pálido
  static const PdfColor _teal = PdfColor.fromInt(0xFF0D9488);      // Teal acento
  // ignore: unused_field
  static const PdfColor _tealLight = PdfColor.fromInt(0xFFF0FDFA); // Teal pálido
  static const PdfColor _amber = PdfColor.fromInt(0xFFD97706);     // Ámbar
  static const PdfColor _red = PdfColor.fromInt(0xFFDC2626);       // Rojo error
  static const PdfColor _redLight = PdfColor.fromInt(0xFFFFF1F2);  // Rojo pálido
  static const PdfColor _green = PdfColor.fromInt(0xFF059669);     // Verde éxito
  static const PdfColor _slate100 = PdfColor.fromInt(0xFFF1F5F9);  // Gris muy claro
  static const PdfColor _slate200 = PdfColor.fromInt(0xFFE2E8F0);  // Borde
  static const PdfColor _slate400 = PdfColor.fromInt(0xFF94A3B8);  // Texto auxiliar
  static const PdfColor _slate600 = PdfColor.fromInt(0xFF475569);  // Texto secundario
  static const PdfColor _slate800 = PdfColor.fromInt(0xFF1E293B);  // Texto primario
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);

  static final _currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFmt = DateFormat('dd/MM/yyyy', 'es');

  // ── API PÚBLICA ───────────────────────────────────────────
  static Future<void> generateAndPrint({
    required PurchaseOrder order,
    required String projectTitle,
    required String clientName,
    required String folio,
    required String generatedBy,
  }) async {
    final pdf = await _buildPdf(
      order: order,
      projectTitle: projectTitle,
      clientName: clientName,
      folio: folio,
      generatedBy: generatedBy,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'OC-$folio-${order.providerName}.pdf',
    );
  }

  static Future<List<int>> generateBytes({
    required PurchaseOrder order,
    required String projectTitle,
    required String clientName,
    required String folio,
    required String generatedBy,
  }) async {
    final pdf = await _buildPdf(
      order: order,
      projectTitle: projectTitle,
      clientName: clientName,
      folio: folio,
      generatedBy: generatedBy,
    );
    return pdf.save();
  }

  // ── CONSTRUCCIÓN INTERNA ──────────────────────────────────
  static Future<pw.Document> _buildPdf({
    required PurchaseOrder order,
    required String projectTitle,
    required String clientName,
    required String folio,
    required String generatedBy,
  }) async {
    final pdf = pw.Document(
      title: 'Orden de Compra $folio',
      author: 'ICI Process',
      subject: 'Orden de Compra - ${order.providerName}',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (pw.Context ctx) => _buildHeader(folio, order.date, generatedBy),
        footer: (pw.Context ctx) => _buildFooter(ctx),
        build: (pw.Context ctx) => [
          // Banda decorativa superior bajo el header
          _buildAccentBand(),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 22),

                // ── Proveedor + Proyecto ──
                _buildInfoRow(order, projectTitle, clientName),

                pw.SizedBox(height: 22),

                // ── Tabla de materiales ──
                _buildMaterialTable(order),

                pw.SizedBox(height: 18),

                // ── Totales ──
                _buildTotalsBlock(order),

                // ── Justificación de excedente ──
                if (order.hasExcess && order.justification != null) ...[
                  pw.SizedBox(height: 22),
                  _buildJustificationBlock(order),
                ],

                pw.SizedBox(height: 32),

                // ── Firmas ──
                _buildSignatureBlock(),

                pw.SizedBox(height: 24),

                // ── Nota legal ──
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
  static pw.Widget _buildHeader(String folio, DateTime date, String generatedBy) {
    return pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Marca / Logo
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Cuadro decorativo de la marca
                  pw.Container(
                    width: 4,
                    height: 28,
                    color: _blue,
                  ),
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
              // Metadatos del documento
              pw.Row(
                children: [
                  _metaChip('Fecha', _dateFmt.format(date)),
                  pw.SizedBox(width: 10),
                  _metaChip('Generado por', generatedBy),
                ],
              ),
            ],
          ),

          // Folio badge
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'ORDEN DE COMPRA',
                style: pw.TextStyle(
                  color: _slate400,
                  fontSize: 7,
                  letterSpacing: 2.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: _blue,
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
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontSize: 7, color: _slate400),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7,
              color: _white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── BANDA DECORATIVA ──────────────────────────────────────
  static pw.Widget _buildAccentBand() {
    return pw.Row(
      children: [
        pw.Expanded(flex: 5, child: pw.Container(height: 3, color: _blue)),
        pw.Expanded(flex: 2, child: pw.Container(height: 3, color: _teal)),
        pw.Expanded(flex: 1, child: pw.Container(height: 3, color: _amber)),
      ],
    );
  }

  // ── INFO: PROVEEDOR + PROYECTO ────────────────────────────
  static pw.Widget _buildInfoRow(
      PurchaseOrder order, String projectTitle, String clientName) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildInfoCard(
            icon: '●',
            iconColor: _blue,
            title: 'DATOS DEL PROVEEDOR',
            children: [
              _infoField('Empresa', order.providerName),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: _buildInfoCard(
            icon: '◆',
            iconColor: _teal,
            title: 'DATOS DEL PROYECTO',
            children: [
              _infoField('Proyecto', projectTitle),
              pw.SizedBox(height: 6),
              _infoField('Cliente', clientName),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInfoCard({
    required String icon,
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
          // Header de la tarjeta
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: pw.BoxDecoration(
              color: _white,
              // borderRadius omitido: pdf no admite radius con Border no uniforme
              border: pw.Border(bottom: pw.BorderSide(color: _slate200, width: 1)),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 3,
                  height: 12,
                  decoration: pw.BoxDecoration(
                    color: iconColor,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _slate600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Contenido
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
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 6.5,
            color: _slate400,
            letterSpacing: 1,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10.5,
            color: _slate800,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── TABLA DE MATERIALES ───────────────────────────────────
  static pw.Widget _buildMaterialTable(PurchaseOrder order) {
    const headers = [
      'MATERIAL / DESCRIPCIÓN',
      'UNIDAD',
      'CANT. COT.',
      'CANT. COMPRADA',
      'PRECIO UNIT.',
      'TOTAL',
    ];

    final excess = order.quantity - order.quotedQuantity;
    final isExcess = excess > 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Encabezado de sección
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
              child: pw.Text(
                'DETALLE DE LA ORDEN',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 1,
                color: _slate200,
                margin: const pw.EdgeInsets.only(bottom: 0),
              ),
            ),
          ],
        ),

        // Tabla
        pw.Table(
          border: pw.TableBorder(
            left: pw.BorderSide(color: _slate200, width: 1),
            right: pw.BorderSide(color: _slate200, width: 1),
            bottom: pw.BorderSide(color: _slate200, width: 1),
            horizontalInside: pw.BorderSide(color: _slate200, width: 0.5),
            verticalInside: pw.BorderSide(color: _slate200, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.8),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.8),
            4: const pw.FlexColumnWidth(1.8),
            5: const pw.FlexColumnWidth(1.8),
          },
          children: [
            // Cabecera de tabla
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _slate100),
              children: headers.asMap().entries.map((e) {
                final isNumeric = e.key >= 2;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: pw.Text(
                    e.value,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: _slate600,
                      letterSpacing: 0.6,
                    ),
                    textAlign: isNumeric
                        ? pw.TextAlign.center
                        : pw.TextAlign.left,
                  ),
                );
              }).toList(),
            ),

            // Fila de datos
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isExcess ? _redLight : _white,
              ),
              children: [
                // Material
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        order.materialName,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unidad
                _cell(order.unit, centered: true, muted: true),
                // Cant cotizada
                _cell(_fmtQty(order.quotedQuantity), centered: true, muted: true),
                // Cant comprada
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        _fmtQty(order.quantity),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: isExcess ? _red : _green,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (isExcess) ...[
                        pw.SizedBox(height: 2),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: _red,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            '+${_fmtQty(excess)} extra',
                            style: pw.TextStyle(
                              fontSize: 6.5,
                              color: _white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Precio unitario
                _cell(_currFmt.format(order.unitPrice), centered: true),
                // Total
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 12),
                  child: pw.Text(
                    _currFmt.format(order.totalPrice),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _blue,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String text,
      {bool centered = false, bool muted = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: muted ? _slate600 : _slate800,
        ),
        textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  // ── TOTALES ───────────────────────────────────────────────
  static pw.Widget _buildTotalsBlock(PurchaseOrder order) {
    final subtotal = order.totalPrice;
    final iva = subtotal * 0.16;
    final total = subtotal + iva;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 270,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _slate200, width: 1),
          ),
          child: pw.Column(
            children: [
              // Encabezado totales
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: const pw.BoxDecoration(
                  color: _slate100,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(7),
                    topRight: pw.Radius.circular(7),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'RESUMEN DE PAGO',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: _slate600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _totalLine('Subtotal (sin IVA)', _currFmt.format(subtotal)),
              pw.Container(height: 0.5, color: _slate200,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 14)),
              _totalLine('IVA (16%)', _currFmt.format(iva)),
              // Total final
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: const pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(7),
                    bottomRight: pw.Radius.circular(7),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL A PAGAR',
                          style: pw.TextStyle(
                            color: _slate400,
                            fontSize: 7,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.Text(
                          'IVA incluido',
                          style: pw.TextStyle(
                            color: _slate400,
                            fontSize: 6.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      _currFmt.format(total),
                      style: pw.TextStyle(
                        color: _white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
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

  static pw.Widget _totalLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: _slate600)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _slate800)),
        ],
      ),
    );
  }

  // ── JUSTIFICACIÓN DE EXCEDENTE ────────────────────────────
  static pw.Widget _buildJustificationBlock(PurchaseOrder order) {
    final excess = order.quantity - order.quotedQuantity;
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _redLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _red, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Encabezado de alerta
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: pw.BoxDecoration(
              color: _red,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '⚠  EXCEDENTE JUSTIFICADO',
                  style: pw.TextStyle(
                    color: _white,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0x33000000),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '+${_fmtQty(excess)} ${order.unit} sobre lo cotizado',
                    style: pw.TextStyle(
                      color: _white,
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Contenido justificación
          pw.Padding(
            padding: const pw.EdgeInsets.all(14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MOTIVO / JUSTIFICACIÓN',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _red,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: _white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: _slate200, width: 0.5),
                  ),
                  child: pw.Text(
                    order.justification ?? '',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _slate800,
                      lineSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FIRMAS ────────────────────────────────────────────────
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
          _signatureSlot('Elaboró', 'Responsable de compras'),
          _verticalSeparator(),
          _signatureSlot('Autorizó', 'Director / Gerente'),
          _verticalSeparator(),
          _signatureSlot('Proveedor Aceptó', 'Representante autorizado'),
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
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _slate800,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(fontSize: 7, color: _slate400),
        ),
      ],
    );
  }

  static pw.Widget _verticalSeparator() {
    return pw.Container(
      width: 0.5,
      height: 60,
      color: _slate200,
    );
  }

  // ── NOTA LEGAL ────────────────────────────────────────────
  static pw.Widget _buildLegalNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        // Border izquierdo solo → NO se puede combinar con borderRadius en el package pdf
        border: pw.Border(
          left: pw.BorderSide(color: _blueMid, width: 3),
        ),
        color: _blueLight,
      ),
      child: pw.Text(
        'Este documento es una orden de compra oficial emitida por ICI Process. '
        'El proveedor deberá conservar una copia firmada y entregarla junto con '
        'la factura correspondiente. Cualquier modificación a esta orden debe ser '
        'autorizada por escrito por el responsable de compras.',
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
              pw.Container(width: 3, height: 3, color: _blue),
              pw.SizedBox(width: 6),
              pw.Text(
                'ICI Process S.A. de C.V.  —  Documento Confidencial',
                style: pw.TextStyle(fontSize: 7, color: _slate400),
              ),
            ],
          ),
          pw.Text(
            'Pág. ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 7,
              color: _slate400,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────
  static String _fmtQty(double qty) =>
      qty == qty.truncateToDouble()
          ? qty.toStringAsFixed(0)
          : qty.toStringAsFixed(2);
}