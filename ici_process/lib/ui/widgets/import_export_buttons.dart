import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../services/import_export_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
///  WIDGET CON LOS BOTONES DE IMPORTAR / EXPORTAR EXCEL
/// ═══════════════════════════════════════════════════════════════════════
class ImportExportButtons extends StatefulWidget {
  /// Callback opcional para notificar que algo cambió (opcional, ya que
  /// los streams se auto-actualizan).
  final VoidCallback? onImportComplete;

  const ImportExportButtons({super.key, this.onImportComplete});

  @override
  State<ImportExportButtons> createState() => _ImportExportButtonsState();
}

class _ImportExportButtonsState extends State<ImportExportButtons> {
  final ImportExportService _service = ImportExportService();
  bool _isExporting = false;
  bool _isImporting = false;

  // ── Colores consistentes con el catálogo ──
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _accentGreen = const Color(0xFF10B981);
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);

  // ─────────────────────────────────────────────────────────────────────
  //  IMPORTAR
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final preview = await _service.pickAndAnalyzeFile();
      if (preview == null) {
        // Usuario canceló
        setState(() => _isImporting = false);
        return;
      }

      if (!mounted) return;
      setState(() => _isImporting = false);

      // Mostrar diálogo de preview
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ImportPreviewDialog(preview: preview),
      );

      if (confirmed != true) return;

      // Ejecutar importación con indicador de progreso
      if (!mounted) return;
      _showLoadingDialog("Importando materiales...");
      final report = await _service.executeImport(preview);
      if (mounted) Navigator.pop(context); // cerrar loader

      if (!mounted) return;
      await _showReportDialog(report);
      widget.onImportComplete?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        _showErrorSnack("Error al importar: $e");
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  EXPORTAR
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final path = await _service.exportToExcel();
      if (!mounted) return;
      _showSuccessSnack("Excel generado: ${path.split('/').last}");
    } catch (e) {
      if (mounted) _showErrorSnack("Error al exportar: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          icon: LucideIcons.upload,
          label: "Importar Excel",
          color: _primaryBlue,
          loading: _isImporting,
          onTap: _handleImport,
        ),
        const SizedBox(width: 10),
        _buildButton(
          icon: LucideIcons.download,
          label: "Exportar Excel",
          color: _accentGreen,
          loading: _isExporting,
          onTap: _handleExport,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  SNACKS Y DIÁLOGOS AUXILIARES
  // ─────────────────────────────────────────────────────────────────────
  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryBlue),
              const SizedBox(height: 20),
              Text(msg,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
              const SizedBox(height: 6),
              Text("Esto puede tardar unos segundos...",
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReportDialog(ImportReport report) async {
    final hasErrors = report.errors.isNotEmpty;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (hasErrors ? Colors.orange : _accentGreen)
                      .withOpacity(0.08),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasErrors ? Colors.orange : _accentGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasErrors
                            ? LucideIcons.alertTriangle
                            : LucideIcons.checkCircle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasErrors
                                ? "Importación con advertencias"
                                : "¡Importación completada!",
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${report.total} materiales procesados",
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Stats
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _statRow(LucideIcons.plusCircle, "Nuevos creados",
                        report.created, _accentGreen),
                    const SizedBox(height: 10),
                    _statRow(LucideIcons.refreshCw, "Actualizados",
                        report.updated, _primaryBlue),
                    if (report.newProvidersCreated > 0) ...[
                      const SizedBox(height: 10),
                      _statRow(LucideIcons.store, "Proveedores creados",
                          report.newProvidersCreated, const Color(0xFF8B5CF6)),
                    ],
                    if (report.skipped > 0) ...[
                      const SizedBox(height: 10),
                      _statRow(LucideIcons.skipForward, "Omitidos",
                          report.skipped, Colors.grey),
                    ],
                  ],
                ),
              ),
              // Errores
              if (hasErrors)
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Advertencias (${report.errors.length})",
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF991B1B))),
                        const SizedBox(height: 8),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: report.errors
                                  .take(15)
                                  .map((e) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text("• $e",
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF7F1D1D))),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Botón cerrar
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text("Cerrar",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, int value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary)),
        ),
        Text(
          "$value",
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════
///  DIÁLOGO DE PREVIEW ANTES DE IMPORTAR
/// ═══════════════════════════════════════════════════════════════════════
class _ImportPreviewDialog extends StatelessWidget {
  final ImportPreview preview;
  const _ImportPreviewDialog({required this.preview});

  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _accentGreen = const Color(0xFF10B981);
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _primaryBlue.withOpacity(0.08),
                  _primaryBlue.withOpacity(0.02)
                ]),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.fileSpreadsheet,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Confirmar importación",
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                            "${preview.totalRows} filas leídas · ${preview.uniqueMaterials} materiales únicos",
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Stats ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildStat("Se crearán nuevos", preview.willCreate,
                      _accentGreen, LucideIcons.plusCircle),
                  const SizedBox(height: 10),
                  _buildStat("Se actualizarán existentes", preview.willUpdate,
                      _primaryBlue, LucideIcons.refreshCw),
                  if (preview.newProviders > 0) ...[
                    const SizedBox(height: 10),
                    _buildStat(
                        "Proveedores nuevos (se crearán automáticamente)",
                        preview.newProviders,
                        const Color(0xFF8B5CF6),
                        LucideIcons.store),
                  ],
                ],
              ),
            ),
            // ── Aviso importante ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info,
                      size: 16, color: Color(0xFF92400E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Los materiales que ya existen mantendrán su stock actual y stock apartado. "
                      "Solo se actualizará la unidad y la lista de precios.",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF78350F),
                          fontWeight: FontWeight.w500,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            // ── Warnings (si hay) ──
            if (preview.warnings.isNotEmpty)
              Flexible(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "${preview.warnings.length} advertencias al leer",
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF991B1B))),
                      const SizedBox(height: 6),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            preview.warnings.take(10).join('\n'),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF7F1D1D),
                                height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ── Footer con botones ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Text("Cancelar",
                          style: GoogleFonts.inter(
                              color: _textSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.upload, size: 16),
                          const SizedBox(width: 8),
                          Text("Confirmar e importar",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary))),
          Text("$value",
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}