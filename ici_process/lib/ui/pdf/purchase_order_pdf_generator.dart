import 'package:flutter/foundation.dart';
import 'package:ici_process/core/utils/web_utils.dart';
import 'package:ici_process/models/purchase_order_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// Generador de PDF para Órdenes de Compra
/// Diseño compacto y utilitario — misma armonía visual que el Reporte de Servicio
/// ════════════════════════════════════════════════════════════════════════════
class PurchaseOrderPdfGenerator {
  // ── PALETA (idéntica al reporte de servicio) ──────────────
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
  static const _green   = PdfColor.fromInt(0xFF4CAF50);
  static const _blue    = PdfColor.fromInt(0xFF2563EB);

  static final _currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFmt = DateFormat('dd/MM/yyyy', 'es');

  // ── CONSTANTES DE LAYOUT (mismas proporciones que el reporte) ──
  static const double _margin = 14.4;
  static const double _pageW  = 612.0; // Letter

  // ── API PÚBLICA ───────────────────────────────────────────
  static Future<void> generateAndPrint({
    required PurchaseOrder order,
    required String projectTitle,
    required String clientName,
    required String folio,
    required String generatedBy,
  }) async {
    final pdf = _buildPdf(
      order: order,
      projectTitle: projectTitle,
      clientName: clientName,
      folio: folio,
      generatedBy: generatedBy,
    );

    final bytes = await pdf.save();
    final fileName = 'OC-$folio-${order.providerName}.pdf';

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
    required PurchaseOrder order,
    required String projectTitle,
    required String clientName,
    required String folio,
    required String generatedBy,
  }) async {
    final pdf = _buildPdf(
      order: order,
      projectTitle: projectTitle,
      clientName: clientName,
      folio: folio,
      generatedBy: generatedBy,
    );
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONSTRUCCIÓN DEL PDF
  // ═══════════════════════════════════════════════════════════════
  static pw.Document _buildPdf({
    required PurchaseOrder order,
    required String projectTitle,
    required String clientName,
    required String folio,
    required String generatedBy,
  }) {
    final pdf = pw.Document(
      title: 'Orden de Compra $folio',
      author: 'ICI Process',
    );

    final double contentW = _pageW - _margin * 2;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.all(_margin),
        header: (_) => _buildHeader(contentW, folio, order.date, generatedBy),
        footer: (ctx) => _buildFooter(contentW, ctx),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 6),

          // ── Barra de info: Fecha + Folio + Generado por ────
          _buildInfoBar(contentW, folio, order.date, generatedBy),

          pw.SizedBox(height: 6),

          // ── Datos: Proveedor + Proyecto (2 columnas) ───────
          _buildDataRow(contentW, order, projectTitle, clientName),

          pw.SizedBox(height: 8),

          // ── Tabla de materiales ────────────────────────────
          _buildSectionBar(contentW, 'DETALLE DE LA ORDEN'),

          _buildMaterialTable(contentW, order),

          pw.SizedBox(height: 6),

          // ── Totales ───────────────────────────────────────
          _buildTotals(contentW, order),

          // ── Justificación de excedente (si aplica) ────────
          if (order.hasExcess && order.justification != null) ...[
            pw.SizedBox(height: 8),
            _buildExcessBlock(contentW, order),
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
  //  HEADER — 3 columnas (empresa | título | folio)
  //  Mismo patrón que el reporte de servicio
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader(double w, String folio, DateTime date, String generatedBy) {
    const headerH = 42.0;
    final centerW = w * 0.36;
    final sideW = (w - centerW) / 2;

    return pw.Container(
      height: headerH,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _black, width: 0.5),
      ),
      child: pw.Row(
        children: [
          // ── Col 1: Empresa ──────────────────────────────
          pw.Container(
            width: sideW,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: _grey400, width: 0.5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('ICI PROCESS',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _black)),
                pw.Text('Ingeniería, Control e Instrumentación',
                    style: const pw.TextStyle(fontSize: 5, color: _grey700)),
                pw.SizedBox(height: 2),
                pw.Text('Tel: (449) 000-0000  |  info@iciprocess.com',
                    style: const pw.TextStyle(fontSize: 4, color: _grey600)),
              ],
            ),
          ),

          // ── Col 2: Título + Fecha ──────────────────────
          pw.Container(
            width: centerW,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(color: _grey400, width: 0.5)),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('ORDEN DE COMPRA',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _black),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 3),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: _grey200,
                    border: pw.Border.all(color: _grey400, width: 0.5),
                  ),
                  child: pw.Text(
                    'FECHA: ${_dateFmt.format(date)}',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _black),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // ── Col 3: Folio ───────────────────────────────
          pw.Container(
            width: sideW,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('FOLIO', style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: _grey800,
                  ),
                  child: pw.Text(
                    '# $folio',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _white),
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
  //  INFO BAR — Barra compacta con metadata
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildInfoBar(double w, String folio, DateTime date, String generatedBy) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _grey100,
        border: pw.Border.all(color: _grey400, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Text('GENERADO POR: ', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey600)),
          pw.Text(generatedBy, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _black)),
          pw.Spacer(),
          pw.Text('DOCUMENTO OFICIAL DE COMPRA', style: pw.TextStyle(fontSize: 5, color: _grey600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATOS — Proveedor + Proyecto (2 columnas con borde)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildDataRow(double w, PurchaseOrder order, String projectTitle, String clientName) {
    final colW = (w - 4) / 2;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Proveedor ──
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
                    pw.Text('DATOS DEL PROVEEDOR',
                        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('EMPRESA', style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(order.providerName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _black)),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 4),

        // ── Proyecto ──
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
                    pw.Container(width: 3, height: 8, color: _green),
                    pw.SizedBox(width: 6),
                    pw.Text('DATOS DEL PROYECTO',
                        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PROYECTO', style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(projectTitle, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _black)),
                    pw.SizedBox(height: 6),
                    pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 5, color: _grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(clientName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _black)),
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
  //  SECTION BAR — Barra oscura de sección (igual al reporte)
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
  //  TABLA DE MATERIALES — Compacta, misma densidad que el reporte
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildMaterialTable(double w, PurchaseOrder order) {
    final excess = order.quantity - order.quotedQuantity;
    final isExcess = excess > 0;

    return pw.Table(
      border: pw.TableBorder.all(color: _grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4.0),   // Material
        1: const pw.FlexColumnWidth(1.2),   // Unidad
        2: const pw.FlexColumnWidth(1.4),   // Cant. Cot.
        3: const pw.FlexColumnWidth(1.6),   // Cant. Comprada
        4: const pw.FlexColumnWidth(1.6),   // Precio Unit.
        5: const pw.FlexColumnWidth(1.8),   // Total
      },
      children: [
        // ── Cabecera ──
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _grey200),
          children: [
            _tableHeader('MATERIAL / DESCRIPCIÓN'),
            _tableHeader('UNIDAD', center: true),
            _tableHeader('CANT. COT.', center: true),
            _tableHeader('CANT. COMPRA', center: true),
            _tableHeader('PRECIO UNIT.', center: true),
            _tableHeader('TOTAL', center: true),
          ],
        ),

        // ── Fila de datos ──
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isExcess ? const PdfColor.fromInt(0xFFFFF8F8) : _white,
          ),
          children: [
            // Material
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(
                order.materialName,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _black),
              ),
            ),
            // Unidad
            _tableCell(order.unit, center: true, muted: true),
            // Cant. Cotizada
            _tableCell(_fmtQty(order.quotedQuantity), center: true, muted: true),
            // Cant. Comprada
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: pw.Column(
                children: [
                  pw.Text(
                    _fmtQty(order.quantity),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: isExcess ? _red : _green,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (isExcess) ...[
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: _red,
                      child: pw.Text(
                        '+${_fmtQty(excess)} extra',
                        style: pw.TextStyle(fontSize: 5, color: _white, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Precio unitario
            _tableCell(_currFmt.format(order.unitPrice), center: true),
            // Total
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(
                _currFmt.format(order.totalPrice),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _blue),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

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

  // ═══════════════════════════════════════════════════════════════
  //  TOTALES — Alineados a la derecha, estilo compacto
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildTotals(double w, PurchaseOrder order) {
    final subtotal = order.totalPrice;
    final iva = subtotal * 0.16;
    final total = subtotal + iva;
    const totalW = 200.0;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: totalW,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grey300, width: 0.5),
          ),
          child: pw.Column(
            children: [
              // Header
              pw.Container(
                width: totalW,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: _grey200,
                child: pw.Text('RESUMEN DE PAGO',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: _grey700, letterSpacing: 0.5)),
              ),
              // Subtotal
              _totalLine('Subtotal (sin IVA)', _currFmt.format(subtotal)),
              pw.Container(height: 0.5, color: _grey200, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
              // IVA
              _totalLine('IVA (16%)', _currFmt.format(iva)),
              // Total
              pw.Container(
                width: totalW,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                color: _grey800,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL A PAGAR',
                            style: pw.TextStyle(color: _grey400, fontSize: 5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('IVA incluido', style: const pw.TextStyle(color: _grey400, fontSize: 4.5)),
                      ],
                    ),
                    pw.Text(
                      _currFmt.format(total),
                      style: pw.TextStyle(color: _white, fontSize: 12, fontWeight: pw.FontWeight.bold),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: _grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _black)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  EXCEDENTE — Bloque rojo compacto (mismo patrón que hallazgos)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildExcessBlock(double w, PurchaseOrder order) {
    final excess = order.quantity - order.quotedQuantity;

    return pw.Container(
      width: w,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _red, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header rojo
          pw.Container(
            width: w,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: _red,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('EXCEDENTE JUSTIFICADO',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _white, letterSpacing: 0.5)),
                pw.Text('+${_fmtQty(excess)} ${order.unit} sobre lo cotizado',
                    style: pw.TextStyle(fontSize: 6, color: _white, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          // Contenido
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('MOTIVO / JUSTIFICACIÓN',
                    style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: _red, letterSpacing: 0.5)),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: w,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: _grey50,
                    border: pw.Border.all(color: _grey300, width: 0.5),
                  ),
                  child: pw.Text(
                    order.justification ?? '',
                    style: const pw.TextStyle(fontSize: 7, color: _black, lineSpacing: 2),
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
  //  FIRMAS — Mismo estilo que el reporte de servicio
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
                _signatureSlot(sigW, 'Elaboró', 'Responsable de compras'),
                pw.Container(width: 0.5, height: sigH - 10, color: _grey300),
                _signatureSlot(sigW, 'Autorizó', 'Director / Gerente'),
                pw.Container(width: 0.5, height: sigH - 10, color: _grey300),
                _signatureSlot(sigW, 'Proveedor Aceptó', 'Representante autorizado'),
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
          pw.SizedBox(height: 28), // espacio para firma
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
  //  NOTA LEGAL — Borde izquierdo como el reporte
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
        'Este documento es una orden de compra oficial emitida por ICI Process. '
        'El proveedor deberá conservar una copia firmada y entregarla junto con '
        'la factura correspondiente. Cualquier modificación debe ser autorizada '
        'por escrito por el responsable de compras.',
        style: const pw.TextStyle(fontSize: 5.5, color: _grey600, lineSpacing: 2),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FOOTER — Mismo patrón que el reporte de servicio
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
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════
  static String _fmtQty(double qty) =>
      qty == qty.truncateToDouble()
          ? qty.toStringAsFixed(0)
          : qty.toStringAsFixed(2);
}