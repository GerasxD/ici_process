import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ici_process/services/tool_service.dart';
import 'package:ici_process/services/user_service.dart';
import 'package:ici_process/ui/widgets/process_modal/execution_status_section.dart';
import 'package:ici_process/ui/widgets/process_modal/logistics_section.dart';
import 'package:ici_process/ui/widgets/process_modal/mention_text_field.dart';
import 'package:ici_process/ui/widgets/process_modal/quote_form_modal.dart';
import 'package:ici_process/ui/widgets/process_modal/report_billing_section.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'general_info_section.dart';
import '../../../models/process_model.dart';
import '../../../models/user_model.dart';
import '../../../services/process_service.dart';
import '../../../services/material_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/permission_manager.dart';

class ProcessModal extends StatefulWidget {
  final ProcessModel? process;
  final UserModel user;

  const ProcessModal({super.key, this.process, required this.user});

  @override
  State<ProcessModal> createState() => _ProcessModalState();
}

class _ProcessModalState extends State<ProcessModal> {
  final _titleController = TextEditingController();
  final _clientController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _commentController = TextEditingController();
  final _regressionController = TextEditingController();
  final _amountController = TextEditingController();
  final _costController = TextEditingController();

  Map<String, dynamic>? _currentQuotationData;

  // ── NUEVO: datos de logística ─────────────────────────────
  Map<String, dynamic>? _currentLogisticsData;
  Map<String, dynamic>? _currentReportBillingData;

  String _priority = 'Media';
  String? _requestedBy;
  DateTime _requestDate = DateTime.now();
  List<CommentModel> _comments = [];
  final ProcessService _processService = ProcessService();
  final MaterialService _materialService = MaterialService();
  final ToolService _toolService = ToolService();

  bool canEditData = false;
  bool canMoveStage = false;
  bool canViewFinancials = false; 

  final _ocNumberController = TextEditingController();
  bool _isNoOc = false;
  DateTime? _ocReceptionDate;

  List<String> _pendingMentionIds = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkPermissions();
  }

  void _initializeData() {
    if (widget.process != null) {
      _titleController.text = widget.process!.title;
      _clientController.text = widget.process!.client;
      _descriptionController.text = widget.process!.description;
      _priority = widget.process!.priority;
      _requestedBy = widget.process!.requestedBy;
      _requestDate = widget.process!.requestDate;
      _comments = List.from(widget.process!.comments);
      _amountController.text = widget.process!.amount.toString();
      _costController.text = widget.process!.estimatedCost.toString();
      _currentQuotationData = widget.process!.quotationData;
      _ocNumberController.text = widget.process!.poNumber ?? '';
      _isNoOc = widget.process!.skipClientPO;
      // ── Cargar datos de logística ─────────────────────────
      _currentLogisticsData = widget.process!.logisticsData;
      _currentReportBillingData = widget.process!.reportBillingData;

      if (widget.process!.poDate != null && widget.process!.poDate!.isNotEmpty) {
        try {
          _ocReceptionDate = DateTime.parse(widget.process!.poDate!);
        } catch (_) {
          _ocReceptionDate = null;
        }
      }
    }
  }

  void _checkPermissions() {
    final pm = PermissionManager();
    final currentStage = widget.process?.stage ?? ProcessStage.E1;
    final stageCode = currentStage.toString().split('.').last;
    canEditData = pm.can(widget.user, 'stage_edit_$stageCode');
    canMoveStage = pm.can(widget.user, 'move_stage');
    canViewFinancials = pm.can(widget.user, 'view_financials');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _clientController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    _regressionController.dispose();
    _amountController.dispose();
    _costController.dispose();
    _ocNumberController.dispose();
    super.dispose();
  }

  // ── Helper: calcula logisticsStatus para el modelo ────────
  String _resolveLogisticsStatus() {
    if (_currentLogisticsData == null) return 'ToBuy';
    final status = _currentLogisticsData!['status'] as String? ?? 'Por Comprar';
    switch (status) {
      case 'Completo':
        return 'Complete';
      case 'Incompleto':
        return 'Incomplete';
      default:
        return 'ToBuy';
    }
  }

  // ── DELETE ────────────────────────────────────────────────
  Future<void> _handleDelete() async {
    // ── ELIMINAR PERMANENTEMENTE (desde etapa X) ──────────
    if (widget.process?.stage == ProcessStage.X) {
      if (!canEditData) return;
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: 460,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(LucideIcons.trash2, color: Color(0xFFDC2626), size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Eliminar Permanentemente",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Esta acción es irreversible",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // Contenido
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    children: [
                      // Info del proyecto
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.fileText, size: 16, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.process?.title ?? "Sin título",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.process?.client ?? "",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Advertencia
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFDC2626)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Este proceso será eliminado definitivamente junto con su historial, comentarios y datos de logística. No podrá recuperarse.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: const Text(
                            "Cancelar",
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.trash2, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Eliminar Para Siempre",
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
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
        ),
      );

      if (confirm == true && widget.process != null) {
        if (widget.process!.stage == ProcessStage.E5) {
          await _cancelStockReservations();
        }
        await _processService.deleteProcess(widget.process!.id);
        if (mounted) Navigator.pop(context);
      }
    }
    // ── DESCARTAR (mover a etapa X) ───────────────────────
    else {
      if (!PermissionManager().can(widget.user, 'discard_process')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No tienes permiso para descartar procesos.")),
        );
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(LucideIcons.archive, color: Color(0xFF64748B), size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Descartar Proceso",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Se moverá a la sección de descartados",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // Contenido
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    children: [
                      // Info del proyecto
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (stageConfigs[widget.process!.stage]?.color ?? const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                stageConfigs[widget.process!.stage]?.icon ?? LucideIcons.fileText,
                                size: 16,
                                color: stageConfigs[widget.process!.stage]?.textColor ?? const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.process?.title ?? "Sin título",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        widget.process?.client ?? "",
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (stageConfigs[widget.process!.stage]?.color ?? const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          stageConfigs[widget.process!.stage]?.title ?? "",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: stageConfigs[widget.process!.stage]?.textColor ?? const Color(0xFF64748B),
                                          ),
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

                      const SizedBox(height: 16),

                      // Transición visual compacta
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              stageConfigs[widget.process!.stage]?.icon ?? LucideIcons.circle,
                              size: 16,
                              color: stageConfigs[widget.process!.stage]?.textColor ?? const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.process!.stage.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: stageConfigs[widget.process!.stage]?.textColor ?? const Color(0xFF64748B),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF64748B).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.arrowRight, size: 14, color: Color(0xFF64748B)),
                              ),
                            ),
                            const Icon(LucideIcons.xCircle, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            const Text(
                              "Descartado",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Nota informativa
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.info, size: 16, color: Color(0xFF0369A1)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "El proceso se moverá a Descartados. Podrás recuperarlo o eliminarlo permanentemente desde ahí.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0C4A6E),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: const Text(
                            "Cancelar",
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF475569),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.archive, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Sí, Descartar",
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
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
        ),
      );

      if (confirm == true && widget.process != null) {
        if (widget.process!.stage == ProcessStage.E5) {
          await _cancelStockReservations();
        }
        final fechaActual = DateTime.now();
        final historyEntry = HistoryEntry(
          action: "Proceso Descartado",
          userName: widget.user.name,
          date: fechaActual,
          details: "Movido a Descartado por ${widget.user.name}",
        );
        setState(() {
          _comments.insert(
            0,
            CommentModel(
              id: fechaActual.millisecondsSinceEpoch.toString(),
              text: "PROCESO DESCARTADO por ${widget.user.name}",
              userName: widget.user.name,
              date: fechaActual,
            ),
          );
        });
        final updated = _buildModelFromState(ProcessStage.X, historyEntry);
        await _processService.updateProcess(updated);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  List<String> _getPlannedToolIds() {
    final planning = _currentLogisticsData?['executionPlanning'] 
        as Map<String, dynamic>?;
    return List<String>.from(planning?['toolIds'] ?? []);
  }

  Future<void> _setToolsInUse() async {
    final ids = _getPlannedToolIds();
    if (ids.isEmpty) return;
    await _toolService.updateToolsStatus(ids, 'En Uso');
  }

  Future<void> _releaseTools() async {
    final ids = _getPlannedToolIds();
    if (ids.isEmpty) return;
    await _toolService.updateToolsStatus(ids, 'Disponible');
  }

  // ── ADVANCE ───────────────────────────────────────────────
  Future<void> _handleAdvanceStage() async {
    if (!canMoveStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No tienes permiso para mover etapas.")),
      );
      return;
    }
    if (widget.process == null) return;

    final stages = ProcessStage.values;
    final currentIndex = stages.indexOf(widget.process!.stage);
    if (currentIndex >= stages.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Este proceso ya se encuentra en la etapa final.")),
      );
      return;
    }

    final nextStage = stages[currentIndex + 1];
    bool isAuthorizing = widget.process!.stage == ProcessStage.E2;

    // NUEVO: VALIDACION ESTRICTA DE ORDEN DE COMPRA EN E4
    if (widget.process!.stage == ProcessStage.E4) {
      final bool missingOc = !_isNoOc && _ocNumberController.text.trim().isEmpty;

      if (missingOc) {
        // Lanzamos la advertencia visual y bloqueamos el avance
        await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: 460,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── HEADER ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.fileX2,
                          color: Color(0xFFDC2626),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Falta Orden de Compra",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Requerida para avanzar a la siguiente etapa",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.x,
                            color: Color(0xFF94A3B8), size: 20),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // ── CONTENIDO ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    children: [
                      // Tarjeta del proceso
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.fileText,
                                  size: 16, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.process?.title ?? "Sin título",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.process?.client ?? "",
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Advertencia principal
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.alertTriangle,
                                size: 16, color: Color(0xFFDC2626)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Para avanzar debes ingresar el número de O.C. en el campo correspondiente.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nota alternativa
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.info,
                                size: 16, color: Color(0xFF0369A1)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Si el proyecto no requiere O.C., marca la casilla \"Trabajo sin O.C.\" para continuar.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0C4A6E),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── FOOTER ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle2, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Entendido, Completar O.C. para Avanzar",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
        return; // Esto detiene el flujo y evita que pase a E5
      }
    }

    // ── VALIDACIÓN E7: Archivos requeridos antes de Finalizar ──
    if (widget.process!.stage == ProcessStage.E7) {
      final photoFiles = (_currentReportBillingData?['photoReportFiles'] as List? ?? []);
      final xmlFiles   = (_currentReportBillingData?['invoiceXmlFiles']  as List? ?? []);
      final pdfFiles   = (_currentReportBillingData?['invoicePdfFiles']  as List? ?? []);

      final bool missingPhoto = photoFiles.isEmpty;
      final bool missingXml   = xmlFiles.isEmpty;
      final bool missingPdf   = pdfFiles.isEmpty;

      if (missingPhoto || missingXml || missingPdf) {
        final List<Map<String, dynamic>> missingItems = [
          if (missingPhoto) {
            'label': 'Reporte Fotográfico (PDF)',
            'icon': LucideIcons.camera,
            'color': const Color(0xFF2563EB),
          },
          if (missingXml) {
            'label': 'Factura XML (CFDI)',
            'icon': LucideIcons.fileCode,
            'color': const Color(0xFFEA580C),
          },
          if (missingPdf) {
            'label': 'Factura PDF',
            'icon': LucideIcons.fileText,
            'color': const Color(0xFFDC2626),
          },
        ];

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 460,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── HEADER ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            LucideIcons.clipboardX,
                            color: Color(0xFFDC2626),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Documentos Incompletos",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${missingItems.length} archivo${missingItems.length > 1 ? 's' : ''} requerido${missingItems.length > 1 ? 's' : ''} para finalizar",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(LucideIcons.x,
                              color: Color(0xFF94A3B8), size: 20),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // ── CONTENIDO ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarjeta del proceso
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(LucideIcons.fileText,
                                    size: 16, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.process?.title ?? "Sin título",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.process?.client ?? "",
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Label sección faltantes
                        const Row(
                          children: [
                            Icon(LucideIcons.alertCircle,
                                size: 14, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text(
                              "ARCHIVOS PENDIENTES DE SUBIR",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Lista de archivos faltantes
                        ...missingItems.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (item['color'] as Color)
                                          .withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      size: 15,
                                      color: item['color'] as Color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item['label'] as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                  const Icon(LucideIcons.xCircle,
                                      size: 16, color: Color(0xFFDC2626)),
                                ],
                              ),
                            )),

                        const SizedBox(height: 12),

                        // Nota informativa
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFBAE6FD)
                                    .withOpacity(0.5)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info,
                                  size: 16, color: Color(0xFF0369A1)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Sube los archivos faltantes en la sección \"Reporte de Servicio y Facturación\" para poder finalizar el proceso.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0C4A6E),
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── FOOTER ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.upload, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Entendido, Subir Archivos para Finalizar",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return; // Bloquea el avance
      }
    }
    // ── FIN VALIDACIÓN E7 ──

    // ── Verificar materiales pendientes al avanzar desde E5 ──
    if (widget.process!.stage == ProcessStage.E5 && _currentLogisticsData != null) {
      final items = (_currentLogisticsData!['items'] as List? ?? []);
      List<Map<String, dynamic>> pendingMaterials = [];

      for (final rawItem in items) {
        final map = Map<String, dynamic>.from(rawItem);
        final name = map['materialName'] ?? 'Material desconocido';
        final requiredQty = (map['requiredQty'] ?? 0).toDouble();
        final stock = (map['stockQty'] ?? 0).toDouble();
        final purchased = (map['purchasedQty'] ?? 0).toDouble();
        final pending = (requiredQty - stock - purchased).clamp(0.0, double.infinity);
        if (pending > 0) {
          pendingMaterials.add({
            'name': name,
            'required': requiredQty,
            'covered': stock + purchased,
            'pending': pending,
          });
        }
      }

      if (pendingMaterials.isNotEmpty) {
        final totalItems = items.length;
        final completedItems = totalItems - pendingMaterials.length;
        final progressPercent = totalItems > 0 ? (completedItems / totalItems * 100).round() : 0;

        final proceedAnyway = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 520,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── HEADER ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFF7ED), Color(0xFFFEF2F2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(LucideIcons.packageX, color: Color(0xFFEA580C), size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Compras Incompletas",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${pendingMaterials.length} de $totalItems materiales sin cubrir",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Barra de progreso
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Progreso de compras",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B).withOpacity(0.8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: progressPercent >= 80
                                        ? const Color(0xFFECFDF5)
                                        : progressPercent >= 50
                                            ? const Color(0xFFFEF9C3)
                                            : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "$completedItems / $totalItems completados ($progressPercent%)",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: progressPercent >= 80
                                          ? const Color(0xFF059669)
                                          : progressPercent >= 50
                                              ? const Color(0xFFB45309)
                                              : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalItems > 0 ? completedItems / totalItems : 0,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progressPercent >= 80
                                      ? const Color(0xFF10B981)
                                      : progressPercent >= 50
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── LISTA DE MATERIALES PENDIENTES ──────────────
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.alertCircle, size: 14, color: Color(0xFFDC2626)),
                              SizedBox(width: 8),
                              Text(
                                "MATERIALES PENDIENTES",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...pendingMaterials.map((mat) {
                            final name = mat['name'] as String;
                            final required = mat['required'] as double;
                            final covered = mat['covered'] as double;
                            final pending = mat['pending'] as double;
                            final coveragePercent = required > 0 ? (covered / required * 100).round() : 0;

                            String fmtQty(double v) => v == v.truncateToDouble()
                                ? v.toStringAsFixed(0)
                                : v.toStringAsFixed(2);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA).withOpacity(0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(LucideIcons.package, size: 14, color: Color(0xFFDC2626)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "Faltan ${fmtQty(pending)}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Mini barra de progreso del material
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: required > 0 ? (covered / required).clamp(0.0, 1.0) : 0,
                                            minHeight: 5,
                                            backgroundColor: const Color(0xFFE2E8F0),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              coveragePercent >= 75
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "${fmtQty(covered)} / ${fmtQty(required)} ($coveragePercent%)",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // ── FOOTER ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        // Mensaje de advertencia
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.info, size: 16, color: Color(0xFFB45309)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Si avanzas, el proyecto pasará a Ejecución sin todos los materiales comprados.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Botones
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text(
                                      "Revisar Compras",
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA580C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.arrowRightCircle, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      "Avanzar Así",
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
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
          ),
        );

        if (proceedAnyway != true) return;
      }
    }
    // ── FIN de verificación E5 ──

    if (widget.process!.stage == ProcessStage.E5) {
      final planningData = _currentLogisticsData?['executionPlanning'] as Map<String, dynamic>?;

      final String? startDate = planningData?['startDate'];
      final String? endDate = planningData?['endDate'];
      final List techIds = planningData?['technicianIds'] as List? ?? [];

      final bool missingStart = startDate == null || startDate.isEmpty;
      final bool missingEnd = endDate == null || endDate.isEmpty;
      final bool missingTechs = techIds.isEmpty;

      final List<String> missing = [];
      if (missingStart) missing.add("Fecha de inicio de ejecución");
      if (missingEnd) missing.add("Fecha de fin de ejecución");
      if (missingTechs) missing.add("Al menos un técnico asignado");

      if (missing.isNotEmpty) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 480,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── HEADER ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB45309).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            LucideIcons.calendarX2,
                            color: Color(0xFFB45309),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Planificación Incompleta",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${missing.length} campo${missing.length > 1 ? 's' : ''} requerido${missing.length > 1 ? 's' : ''} para ejecutar",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // ── CONTENIDO ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarjeta del proceso
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(LucideIcons.layoutList, size: 16, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.process?.title ?? "Sin título",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.process?.client ?? "",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Label de campos faltantes
                        const Row(
                          children: [
                            Icon(LucideIcons.alertCircle, size: 14, color: Color(0xFFB45309)),
                            SizedBox(width: 8),
                            Text(
                              "INFORMACIÓN REQUERIDA",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Lista de campos faltantes
                        ...missing.map((field) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.6)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFB45309),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  field,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                              const Icon(LucideIcons.xCircle, size: 16, color: Color(0xFFB45309)),
                            ],
                          ),
                        )),

                        const SizedBox(height: 12),

                        // Nota informativa
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info, size: 16, color: Color(0xFF0369A1)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Completa la sección \"Planificación de Ejecución\" en Logística antes de avanzar a Ejecución.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0C4A6E),
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── FOOTER ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.checkCircle2, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Entendido, Completar Planificación",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return; // ← Bloquea el avance
      }
    }
    // ── FIN de validación planificación de ejecución ──

    if (widget.process!.stage == ProcessStage.E5) {
      if (_currentLogisticsData != null) {
        final items = (_currentLogisticsData!['items'] as List? ?? []);
        final unreservedWithStock = items.where((rawItem) {
          if (rawItem is! Map) return false;
          final map = rawItem as Map<String, dynamic>;
          final isReserved = map['isStockReserved'] ?? false;
          final stockQty = (map['stockQty'] ?? 0).toDouble();
          final requiredQty = (map['requiredQty'] ?? 0).toDouble();
          return !isReserved && stockQty > 0 && requiredQty > 0;
        }).toList();
  
        if (unreservedWithStock.isNotEmpty) {
          final proceedWithout = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── HEADER ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(LucideIcons.packageSearch, color: Color(0xFFD97706), size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Stock sin Apartar",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${unreservedWithStock.length} material${unreservedWithStock.length > 1 ? 'es' : ''} con stock disponible",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // ── CONTENIDO ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        children: [
                          // Tarjeta del proceso
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(LucideIcons.fileText, size: 16, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.process?.title ?? "Sin título",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.process?.client ?? "",
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Advertencia principal
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9C3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.6)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFB45309)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Hay ${unreservedWithStock.length} material${unreservedWithStock.length > 1 ? 'es' : ''} con stock disponible en almacén que no han sido apartados para este proyecto.",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Consecuencia
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(LucideIcons.packageX, size: 16, color: Color(0xFFDC2626)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Si avanzas sin apartar, el stock NO se descontará del almacén y quedará disponible para otros proyectos.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Nota informativa
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBAE6FD).withOpacity(0.5)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(LucideIcons.info, size: 16, color: Color(0xFF0369A1)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Puedes regresar y apartar el stock en la sección de Logística para asegurar la disponibilidad del material.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0C4A6E),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── FOOTER ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text(
                                    "Regresar a Apartar",
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.arrowRightCircle, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    "Avanzar sin Apartar",
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
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
            ),
          );
          if (proceedWithout != true) return;
        }
      }
      // Confirmar deducciones de lo que SÍ fue apartado
      await _confirmStockDeductions();
    }
    // ★ FIN GESTIÓN DE INVENTARIO

    // Configuración visual según tipo de avance
    final currentStageConfig = stageConfigs[widget.process!.stage];
    final nextStageConfig = stageConfigs[nextStage];

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── HEADER ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAuthorizing
                        ? [const Color(0xFFEEF2FF), const Color(0xFFF5F3FF)]
                        : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAuthorizing
                                ? const Color(0xFF4338CA).withOpacity(0.12)
                                : const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isAuthorizing ? LucideIcons.shieldCheck : LucideIcons.arrowRightCircle,
                            color: isAuthorizing ? const Color(0xFF4338CA) : const Color(0xFF10B981),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAuthorizing ? "Autorizar Cotización" : "Avanzar Etapa",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAuthorizing
                                    ? "Se enviará a revisión y aprobación"
                                    : "El proyecto avanzará en el flujo",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── TRANSICIÓN DE ETAPAS ────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.gitBranch, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text(
                          "TRANSICIÓN DE ETAPA",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Visualización de la transición
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          // Etapa actual
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: currentStageConfig?.color ?? const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (currentStageConfig?.textColor ?? const Color(0xFF64748B)).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    currentStageConfig?.icon ?? LucideIcons.circle,
                                    size: 16,
                                    color: currentStageConfig?.textColor ?? const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentStageConfig?.title ?? widget.process!.stage.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: currentStageConfig?.textColor ?? const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Flecha
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isAuthorizing
                                    ? const Color(0xFF4338CA).withOpacity(0.1)
                                    : const Color(0xFF10B981).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.arrowRight,
                                size: 16,
                                color: isAuthorizing ? const Color(0xFF4338CA) : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                          // Etapa siguiente
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: nextStageConfig?.color ?? const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (nextStageConfig?.textColor ?? const Color(0xFF64748B)).withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    nextStageConfig?.icon ?? LucideIcons.circle,
                                    size: 16,
                                    color: nextStageConfig?.textColor ?? const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nextStageConfig?.title ?? nextStage.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: nextStageConfig?.textColor ?? const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mensaje descriptivo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isAuthorizing
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAuthorizing
                              ? const Color(0xFFC7D2FE).withOpacity(0.5)
                              : const Color(0xFFBBF7D0).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.info,
                            size: 16,
                            color: isAuthorizing ? const Color(0xFF4338CA) : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAuthorizing
                                  ? "La cotización será enviada a Autorización (E2A). Confirma que los montos son correctos."
                                  : "El proceso avanzará a ${nextStageConfig?.title ?? nextStage.name}. Esta acción quedará registrada en el historial.",
                              style: TextStyle(
                                fontSize: 12,
                                color: isAuthorizing ? const Color(0xFF3730A3) : const Color(0xFF065F46),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── FOOTER ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAuthorizing ? const Color(0xFF4338CA) : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isAuthorizing ? LucideIcons.shieldCheck : LucideIcons.arrowRightCircle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isAuthorizing ? "Autorizar y Enviar" : "Confirmar Avance",
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
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
      ),
    );

    if (confirm == true) {
      final fechaActual = DateTime.now();
      String historyDetail = isAuthorizing
          ? "Cotización autorizada y enviada a revisión (E2A)"
          : "Avance exitoso a etapa ${nextStage.name}";
      final historyEntry = HistoryEntry(
        action: isAuthorizing ? "Autorización de Cotización" : "Avance de Etapa",
        userName: widget.user.name,
        date: fechaActual,
        details: historyDetail,
      );

      bool isReceivingOC = widget.process!.stage == ProcessStage.E3;
      setState(() {
        if (isReceivingOC && _ocReceptionDate == null) {
          _ocReceptionDate = fechaActual;
        }
        String commentText = isAuthorizing
            ? "COTIZACIÓN COMPLETADA: Se ha enviado a espera de autorización."
            : "AVANCE DE ETAPA: El proceso avanzó a ${nextStage.name}";
        _comments.insert(
          0,
          CommentModel(
            id: fechaActual.millisecondsSinceEpoch.toString(),
            text: commentText,
            userName: widget.user.name,
            date: fechaActual,
          ),
        );
      });

      if (widget.process!.stage == ProcessStage.E5) {
        await _setToolsInUse();
        } else if (widget.process!.stage == ProcessStage.E6) {
          await _releaseTools(); // E6 → E7
        }

      final updated = _buildModelFromState(nextStage, historyEntry);
      await _processService.updateProcess(updated);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── REGRESS ───────────────────────────────────────────────
  void _handleRegressStage() {
    if (!canMoveStage) return;
    if (widget.process == null) return;

    final stages = ProcessStage.values;
    final currentIndex = stages.indexOf(widget.process!.stage);
    if (currentIndex <= 0) return;

    final prevStage = widget.process!.stage == ProcessStage.X
    ? ProcessStage.E1
    : stages[currentIndex - 1];
    final currentStageConfig = stageConfigs[widget.process!.stage];
    final prevStageConfig = stageConfigs[prevStage];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── HEADER ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.arrowLeftCircle, color: Color(0xFFEA580C), size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Retroceder Etapa",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "El proyecto regresará a la etapa anterior",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // ── CONTENIDO ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transición visual
                    const Row(
                      children: [
                        Icon(LucideIcons.gitBranch, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text(
                          "TRANSICIÓN DE ETAPA",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: currentStageConfig?.color ?? const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (currentStageConfig?.textColor ?? const Color(0xFF64748B)).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    currentStageConfig?.icon ?? LucideIcons.circle,
                                    size: 16,
                                    color: currentStageConfig?.textColor ?? const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentStageConfig?.title ?? widget.process!.stage.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: currentStageConfig?.textColor ?? const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFFEA580C)),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: prevStageConfig?.color ?? const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (prevStageConfig?.textColor ?? const Color(0xFF64748B)).withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    prevStageConfig?.icon ?? LucideIcons.circle,
                                    size: 16,
                                    color: prevStageConfig?.textColor ?? const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      prevStageConfig?.title ?? prevStage.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: prevStageConfig?.textColor ?? const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Campo de motivo
                    const Row(
                      children: [
                        Icon(LucideIcons.messageSquare, size: 14, color: Color(0xFFEA580C)),
                        SizedBox(width: 8),
                        Text(
                          "MOTIVO DEL RETROCESO",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEA580C),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _regressionController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.5),
                      decoration: InputDecoration(
                        hintText: "Explica brevemente por qué se regresa esta etapa...",
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nota informativa
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFED7AA).withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.info, size: 16, color: Color(0xFFEA580C)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Esta acción quedará registrada en el historial del proyecto con el motivo indicado.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9A3412),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.process!.stage == ProcessStage.E6) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0).withOpacity(0.5)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.packagePlus, size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "El material que se descontó del almacén será reembolsado automáticamente al inventario general y quedará 'Apartado'.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── FOOTER ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _regressionController.clear();
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_regressionController.text.trim().isNotEmpty) {
                            Navigator.pop(ctx);
                            _confirmRegress();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.arrowLeftCircle, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Confirmar Retroceso",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
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
      ),
    );
  }

  Future<void> _confirmRegress() async {
    final stages = ProcessStage.values;
    final currentIndex = stages.indexOf(widget.process!.stage);
    if (currentIndex > 0) {
      final prevStage = widget.process!.stage == ProcessStage.X
      ? ProcessStage.E1
      : stages[currentIndex - 1];
      
      bool wasRefunded = false; // ★ NUEVO: bandera para saber si hubo reembolso

      // 1. Si retrocedemos DESDE Logística (E5) hacia atrás, cancelamos el stock que estaba "apartado".
      if (widget.process!.stage == ProcessStage.E5) {
        await _cancelStockReservations();
      }

      // 2. Si retrocedemos DESDE Ejecución (E6) a Logística (E5), REEMBOLSAMOS el stock físico.
      if (widget.process!.stage == ProcessStage.E6 && prevStage == ProcessStage.E5) {
        await _refundStockDeductions();
        await _releaseTools();
        wasRefunded = true; // ★ Marcamos que hubo reembolso
      }

      final motivo = _regressionController.text.trim();
      
      // ★ NUEVO: Agregamos nota automática al historial si hubo reembolso
      final detalleMotivo = wasRefunded 
          ? "Motivo: $motivo\n📦 Stock reembolsado al almacén." 
          : "Motivo: $motivo";

      final fechaActual = DateTime.now();
      final historyEntry = HistoryEntry(
        action: "Retroceso de Etapa",
        userName: widget.user.name,
        date: fechaActual,
        details: detalleMotivo, // Usamos el texto con la nota
      );
      
      setState(() {
        _comments.insert(
          0,
          CommentModel(
            id: fechaActual.millisecondsSinceEpoch.toString(),
            text: "RETROCESO DE ETAPA: $detalleMotivo", // Lo mostramos en los comentarios
            userName: widget.user.name,
            date: fechaActual,
          ),
        );
      });
      
      final updated = _buildModelFromState(prevStage, historyEntry);
      await _processService.updateProcess(updated);
      _regressionController.clear();
      
      if (mounted) Navigator.pop(context);
    }
  }

  // ── COMMENT ───────────────────────────────────────────────
  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    
    final currentStage = widget.process?.stage ?? ProcessStage.E1;
    final stageCode = currentStage.toString().split('.').last;
    
    final newComment = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _commentController.text.trim(),
      userName: widget.user.name,
      userId: widget.user.id,
      date: DateTime.now(),
      mentionedUserIds: List.from(_pendingMentionIds),
      stageAtCreation: stageCode,
    );

    setState(() {
      _comments.insert(0, newComment);
      _commentController.clear();
    });

    // Enviar notificaciones a los mencionados
    if (_pendingMentionIds.isNotEmpty) {
      _sendMentionNotifications(_pendingMentionIds, newComment.text);
      _pendingMentionIds = [];
    }
  }

  Future<void> _sendMentionNotifications(
      List<String> userIds, String commentText) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collRef = FirebaseFirestore.instance.collection('notifications');

      for (final targetId in userIds) {
        final docRef = collRef.doc();
        batch.set(docRef, {
          'targetUserId': targetId,
          'title': '💬 Te mencionaron en un comentario',
          'body':
              '${widget.user.name} te mencionó en: ${_titleController.text}',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderName': widget.user.name,
          'processId': widget.process?.id ?? '',
          'type': 'mention',
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error enviando notificaciones de mención: $e');
    }
  }

  void _editComment(CommentModel comment) {
    final editController = TextEditingController(text: comment.text);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 460,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.pencil,
                          size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Editar Comentario",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(LucideIcons.x,
                          color: Color(0xFF94A3B8), size: 18),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: TextField(
                  controller: editController,
                  maxLines: 4,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF1E293B), height: 1.5),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2563EB), width: 1.5),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                                color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: const Text("Cancelar",
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final newText = editController.text.trim();
                          if (newText.isEmpty) return;
                          setState(() {
                            final index = _comments.indexWhere(
                                (c) => c.id == comment.id);
                            if (index != -1) {
                              _comments[index] = CommentModel(
                                id: comment.id,
                                text: newText,
                                userName: comment.userName,
                                userId: comment.userId,
                                date: comment.date,
                                mentionedUserIds:
                                    comment.mentionedUserIds,
                                stageAtCreation:
                                    comment.stageAtCreation,
                                isEdited: true,
                              );
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text("Guardar Cambios",
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD MODEL ───────────────────────────────────────────
  ProcessModel _buildModelFromState(ProcessStage stage, HistoryEntry newEntry) {
    double finalAmount = double.tryParse(_amountController.text) ?? 0.0;
    double finalCost = double.tryParse(_costController.text) ?? 0.0;

    return ProcessModel(
      id: widget.process?.id ??
          "PROC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
      title: _titleController.text,
      client: _clientController.text,
      requestedBy: _requestedBy ?? "No asignado",
      requestDate: _requestDate,
      description: _descriptionController.text,
      priority: _priority,
      stage: stage,
      comments: _comments,
      history: [newEntry, ...widget.process?.history ?? []],
      updatedAt: DateTime.now(),
      amount: finalAmount,
      estimatedCost: finalCost,
      poNumber: _ocNumberController.text,
      skipClientPO: _isNoOc,
      poDate: _ocReceptionDate?.toIso8601String(),
      quotationData: _currentQuotationData,
      // ── Incluir logisticsData y status calculado ──────────
      logisticsData: _currentLogisticsData,
      logisticsStatus: _resolveLogisticsStatus(),
      reportBillingData: _currentReportBillingData,
    );
  }

  // ── SAVE ──────────────────────────────────────────────────
  Future<void> _save() async {
    final bool isNew = widget.process == null;
  
    // Validar permiso de creación
    if (isNew && !PermissionManager().can(widget.user, 'create_process')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No tienes permiso para crear procesos.")),
      );
      return;
    }
    
    if (!canEditData && !isNew) return;
    if (_titleController.text.isEmpty || _clientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Título y Cliente son obligatorios")),
      );
      return;
    }
    try {
      // ★ NUEVO: Procesar reservas pendientes antes de guardar
      await _processPendingReservations();

      final bool isNew = widget.process == null;
      final entry = HistoryEntry(
        action: isNew ? "Solicitud Creada" : "Edición Manual",
        userName: widget.user.name,
        date: DateTime.now(),
      );
      final processModel = _buildModelFromState(
        widget.process?.stage ?? ProcessStage.E1,
        entry,
      );
      if (isNew) {
        await _processService.createProcess(processModel);
      } else {
        await _processService.updateProcess(processModel);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: ${e.toString()}")),
        );
      }
    }
  }

  /// ★ NUEVO: Ejecuta las reservas reales en Firestore solo al momento de guardar
  Future<void> _processPendingReservations() async {
    if (_currentLogisticsData == null) return;

    final items = _currentLogisticsData!['items'] as List? ?? [];
    
    for (int i = 0; i < items.length; i++) {
      final rawItem = items[i];
      if (rawItem is! Map) continue;
      
      final map = rawItem as Map<String, dynamic>;
      final isPending = map['isPendingReservation'] ?? false;
      
      if (!isPending) continue;
      
      final materialId = map['materialId'] ?? '';
      final desiredQty = (map['reservedStockQty'] ?? 0).toDouble();
      
      if (materialId.isEmpty || desiredQty <= 0) continue;

      final actuallyReserved = await _materialService.reserveStock(
        materialId, 
        desiredQty,
      );

      if (actuallyReserved > 0) {
        // ★ Éxito: actualizar con la cantidad real reservada
        map['isStockReserved'] = true;
        map['reservedStockQty'] = actuallyReserved;
        map['stockQty'] = actuallyReserved;
        map['isPendingReservation'] = false;
      } else if (actuallyReserved == 0) {
        // No había stock disponible, revertir marca local
        map['isStockReserved'] = false;
        map['reservedStockQty'] = 0;
        map['isPendingReservation'] = false;
      } else {
        // Error de Firestore, revertir marca local
        map['isStockReserved'] = false;
        map['reservedStockQty'] = 0;
        map['isPendingReservation'] = false;
      }
    }
  }

  // ── QUOTE ─────────────────────────────────────────────────
  Future<void> _openQuoteModal() async {
    if (widget.process == null) return;

    // ✅ Usar los datos de cotización ya guardados en el estado local
    final processWithLatestQuote = ProcessModel(
      id: widget.process!.id,
      title: _titleController.text,
      client: _clientController.text,
      requestedBy: _requestedBy ?? widget.process!.requestedBy,
      requestDate: _requestDate,
      description: _descriptionController.text,
      priority: _priority,
      stage: widget.process!.stage,
      comments: _comments,
      history: widget.process!.history,
      updatedAt: widget.process!.updatedAt,
      amount: double.tryParse(_amountController.text) ?? widget.process!.amount,
      estimatedCost: double.tryParse(_costController.text) ?? widget.process!.estimatedCost,
      poNumber: _ocNumberController.text,
      skipClientPO: _isNoOc,
      poDate: widget.process!.poDate,
      quotationData: _currentQuotationData ?? widget.process!.quotationData, // ← clave
      logisticsData: _currentLogisticsData,
      logisticsStatus: _resolveLogisticsStatus(),
    );

    await showDialog(
      context: context,
      builder: (_) => QuoteFormModal(process: processWithLatestQuote), // ← proceso actualizado
    );

    final updatedProcess = await _processService.getProcessById(widget.process!.id);
    if (updatedProcess != null && mounted) {
      setState(() {
        _amountController.text = updatedProcess.amount.toStringAsFixed(2);
        _costController.text = updatedProcess.estimatedCost.toStringAsFixed(2);
        _currentQuotationData = updatedProcess.quotationData;
      });
    }
  }

  String _getQuoterName() {
    if (widget.process != null &&
        widget.process!.amount > 0 &&
        widget.process!.history.isNotEmpty) {
      return widget.process!.history.first.userName;
    }
    return widget.user.name;
  }

  // ── NOTIFY USERS ──────────────────────────────────────────
  Future<void> _handleNotifyUsers() async {
    Set<String> selectedUserIds = {};

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── HEADER ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.bellRing,
                          color: Color(0xFF7C3AED),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Notificar Usuarios",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "O.C. recibida · ${_titleController.text}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.x,
                            color: Color(0xFF94A3B8), size: 20),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // ── CONTENIDO ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label de sección
                      Row(
                        children: [
                          const Icon(LucideIcons.users,
                              size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          const Text(
                            "SELECCIONAR DESTINATARIOS",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const Spacer(),
                          if (selectedUserIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${selectedUserIds.length} seleccionado${selectedUserIds.length > 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Lista de usuarios
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: StreamBuilder<List<UserModel>>(
                            stream: UserService().getUsersStream(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF7C3AED),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              final users = snapshot.data!
                                  .where((u) => u.id != widget.user.id)
                                  .toList();

                              if (users.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                      "No hay otros usuarios disponibles.",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF94A3B8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                itemCount: users.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Color(0xFFE2E8F0),
                                ),
                                itemBuilder: (context, index) {
                                  final u = users[index];
                                  final isSelected =
                                      selectedUserIds.contains(u.id);
                                  final initials = u.name.isNotEmpty
                                      ? u.name
                                          .trim()
                                          .split(' ')
                                          .take(2)
                                          .map((w) => w[0].toUpperCase())
                                          .join()
                                      : '?';

                                  return InkWell(
                                    onTap: () {
                                      setStateDialog(() {
                                        if (isSelected) {
                                          selectedUserIds.remove(u.id);
                                        } else {
                                          selectedUserIds.add(u.id);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      color: isSelected
                                          ? const Color(0xFF7C3AED)
                                              .withOpacity(0.06)
                                          : Colors.transparent,
                                      child: Row(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF7C3AED)
                                                  : const Color(0xFFE2E8F0),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Nombre y email
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  u.name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: isSelected
                                                        ? const Color(0xFF7C3AED)
                                                        : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  u.email,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Checkbox visual
                                          AnimatedContainer(
                                            duration:
                                                const Duration(milliseconds: 150),
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF7C3AED)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF7C3AED)
                                                    : const Color(0xFFCBD5E1),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(LucideIcons.check,
                                                    size: 14, color: Colors.white)
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nota informativa
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  const Color(0xFFDDD6FE).withOpacity(0.6)),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.info,
                                size: 15, color: Color(0xFF7C3AED)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Los usuarios seleccionados recibirán una notificación sobre la O.C. recibida.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5B21B6),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── FOOTER ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: const Text(
                            "Cancelar",
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: selectedUserIds.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  try {
                                    final batch =
                                        FirebaseFirestore.instance.batch();
                                    final collRef = FirebaseFirestore.instance
                                        .collection('notifications');
                                    for (final targetId in selectedUserIds) {
                                      final docRef = collRef.doc();
                                      batch.set(docRef, {
                                        'targetUserId': targetId,
                                        'title': '📌 O.C. Recibida',
                                        'body':
                                            'Proyecto: ${_titleController.text}',
                                        'read': false,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                        'senderName': widget.user.name,
                                        'processId': widget.process?.id ?? '',
                                      });
                                    }
                                    await batch.commit();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Notificación enviada a ${selectedUserIds.length} usuario${selectedUserIds.length > 1 ? 's' : ''}"),
                                          backgroundColor:
                                              const Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                    setState(() {
                                      _comments.insert(
                                        0,
                                        CommentModel(
                                          id: DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                          text:
                                              "Se notificó sobre la O.C. a ${selectedUserIds.length} persona${selectedUserIds.length > 1 ? 's' : ''}.",
                                          userName: widget.user.name,
                                          date: DateTime.now(),
                                        ),
                                      );
                                    });
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Error al enviar notificaciones")),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFE2E8F0),
                            disabledForegroundColor:
                                const Color(0xFF94A3B8),
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.send, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                selectedUserIds.isEmpty
                                    ? "Selecciona usuarios"
                                    : "Enviar a ${selectedUserIds.length} usuario${selectedUserIds.length > 1 ? 's' : ''}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MÉTODOS DE CONTROL DE INVENTARIO (RECUPERADOS)
  // ═══════════════════════════════════════════════════════════

  Future<void> _confirmStockDeductions() async {
    if (_currentLogisticsData == null) return;

    final items = _currentLogisticsData!['items'] as List? ?? [];
    // ignore: unused_local_variable
    int deducted = 0;

    for (int i = 0; i < items.length; i++) {
      final rawItem = items[i];
      if (rawItem is! Map) continue;
      
      final map = rawItem as Map<String, dynamic>;
      final isReserved = map['isStockReserved'] ?? false;
      final reservedQty = (map['reservedStockQty'] ?? 0).toDouble();
      final materialId = map['materialId'] ?? '';

      if (!isReserved || reservedQty <= 0 || materialId.isEmpty) continue;

      final success = await _materialService.confirmStockDeduction(
        materialId, 
        reservedQty,
      );

      if (success) {
        // ★ PASO CLAVE: Guardar la memoria de los "23 cables" ANTES de limpiar
        map['deductedStockQty'] = reservedQty; 

        map['isStockReserved'] = false;
        map['reservedStockQty'] = 0;
        deducted++;
      }
    }
  }

  Future<void> _cancelStockReservations() async {
    if (_currentLogisticsData == null) return;

    final items = _currentLogisticsData!['items'] as List? ?? [];
    int cancelled = 0;

    for (int i = 0; i < items.length; i++) {
      final rawItem = items[i];
      if (rawItem is! Map) continue;
      
      final map = rawItem as Map<String, dynamic>;
      final isReserved = map['isStockReserved'] ?? false;
      final reservedQty = (map['reservedStockQty'] ?? 0).toDouble();
      final materialId = map['materialId'] ?? '';

      if (!isReserved || reservedQty <= 0 || materialId.isEmpty) continue;

      final success = await _materialService.cancelReservation(
        materialId, 
        reservedQty,
      );
      
      if (success) {
        map['isStockReserved'] = false;
        map['reservedStockQty'] = 0;
        cancelled++;
      } else {
        map['isStockReserved'] = false;
        map['reservedStockQty'] = 0;
      }
    }

    if (cancelled > 0) print("✅ Reservas canceladas para $cancelled material(es)");
  }

  Future<void> _refundStockDeductions() async {
    if (_currentLogisticsData == null) return;

    final items = _currentLogisticsData!['items'] as List? ?? [];
    // ignore: unused_local_variable
    int refunded = 0;

    for (int i = 0; i < items.length; i++) {
      final rawItem = items[i];
      if (rawItem is! Map) continue;
      
      final map = rawItem as Map<String, dynamic>;
      // ★ PASO CLAVE: Leer la memoria de los "23 cables"
      final deductedQty = (map['deductedStockQty'] ?? 0).toDouble();
      final materialId = map['materialId'] ?? '';

      if (deductedQty > 0 && materialId.isNotEmpty) {
        final success = await _materialService.refundStock(materialId, deductedQty);
        
        if (success) {
          // ★ Dejamos el material libre para que el usuario decida si lo vuelve a apartar
          map['isStockReserved'] = false; 
          map['reservedStockQty'] = 0;
          map['deductedStockQty'] = 0; // Limpiamos la memoria
          refunded++;
        }
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
   final bool showLogistics = widget.process != null && [
      ProcessStage.E5,
      ProcessStage.E6,
      ProcessStage.E7,
      ProcessStage.E8,
      ProcessStage.X,
    ].contains(widget.process!.stage);

     final bool showReportBilling = widget.process != null && [
      ProcessStage.E7,
      ProcessStage.E8,
      ProcessStage.X,
    ].contains(widget.process!.stage);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF1F5F9),
      child: Container(
        width: 1000,
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            _buildModalHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // ── Info general (bloqueada si no tiene permiso) ──
                    AbsorbPointer(
                      absorbing: !canEditData,
                      child: Opacity(
                        opacity: canEditData ? 1.0 : 0.7,
                        child: GeneralInfoSection(
                          currentUser: widget.user,
                          titleController: _titleController,
                          clientController: _clientController,
                          descriptionController: _descriptionController,
                          amountController: _amountController,
                          costController: _costController,
                          selectedPriority: _priority,
                          selectedRequester: _requestedBy,
                          requestDate: _requestDate,
                          currentStage: widget.process?.stage,
                          onPriorityChanged: (val) =>
                              setState(() => _priority = val!),
                          onRequesterChanged: (val) =>
                              setState(() => _requestedBy = val),
                          onDateChanged: (val) =>
                              setState(() => _requestDate = val),
                          quotedBy: _getQuoterName(),
                          onOpenQuote: _openQuoteModal,
                          onNotifyUsers: _handleNotifyUsers,
                          ocNumberController: _ocNumberController,
                          isNoOc: _isNoOc,
                          ocReceptionDate: _ocReceptionDate,
                          onNoOcChanged: (val) => setState(() {
                            _isNoOc = val ?? false;
                            if (_isNoOc) _ocNumberController.text = "S/N";
                          }),
                          onOcDateChanged: (val) =>
                              setState(() => _ocReceptionDate = val),
                          extraSection: showLogistics
                          ? Column(
                              children: [
                                // ── Logística ──────────────────────────
                                _buildStageHighlight(
                                  isActive: widget.process!.stage == ProcessStage.E5,
                                  activeLabel: "ETAPA ACTUAL · E5 - Logística y Compras",
                                  activeColor: const Color(0xFFB45309),
                                  child: LogisticsSection(
                                    process: widget.process!,
                                    isEditable: widget.process!.stage == ProcessStage.E5 ? canEditData : false,
                                    initialData: _currentLogisticsData,
                                    canViewFinancials: canViewFinancials,
                                    currentUserName: widget.user.name,
                                    currentUserRole: widget.user.role,
                                    onDataChanged: (data) {
                                      _currentLogisticsData = data;
                                    },
                                  ),
                                ),

                                // ── Estatus de Ejecución ───────────────
                                if (widget.process!.stage.index >= ProcessStage.E6.index) ...[
                                  const SizedBox(height: 16),
                                  _buildStageHighlight(
                                    isActive: widget.process!.stage == ProcessStage.E6,
                                    activeLabel: "ETAPA ACTUAL · E6 -  Ejecución en Sitio",
                                    activeColor: const Color(0xFFC2410C),
                                    child: ExecutionStatusSection(
                                      process: widget.process!,
                                      logisticsData: _currentLogisticsData,
                                      isEditable: widget.process!.stage == ProcessStage.E6 ? canEditData : false,
                                      onCompletionDateChanged: (date) {
                                        _currentLogisticsData ??= {};
                                        _currentLogisticsData!['realCompletionDate'] = date?.toIso8601String();
                                      },
                                    ),
                                  ),
                                ],

                                // ── Reporte y Facturación ──────────────
                                if (showReportBilling) ...[
                                  const SizedBox(height: 16),
                                  _buildStageHighlight(
                                    isActive: widget.process!.stage == ProcessStage.E7,
                                    activeLabel: "ETAPA ACTUAL · E7 -Reporte y Facturación",
                                    activeColor: const Color(0xFF16A34A),
                                    child: ReportBillingSection(
                                      process: widget.process!,
                                      isEditable: widget.process!.stage == ProcessStage.E7 ? canEditData : false,
                                      initialData: _currentReportBillingData,
                                      currentUserName: widget.user.name,
                                      onDataChanged: (data) {
                                        _currentReportBillingData = data;
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
            _buildModalFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStageHighlight({
    required bool isActive,
    required String activeLabel,
    required Color activeColor,
    required Widget child,
  }) {
    if (isActive) {
      // ── SECCIÓN ACTIVA: resaltada con borde de color y badge ──
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge indicador
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: activeColor.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  activeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: activeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // Contenido con borde lateral
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: activeColor.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
          ),
        ],
      );
    }

    // ── SECCIÓN INACTIVA: opacidad reducida ──
    return Opacity(
      opacity: 0.55,
      child: child,
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                widget.process == null ? "NUEVO PROCESO" : "EDITAR PROCESO",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              if (!canEditData) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.lock, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text("Solo Lectura",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x),
          ),
        ],
      ),
    );
  }

  Widget _buildModalFooter() {
    final bool mobile = MediaQuery.of(context).size.width < 700;
    bool isAuthStage = widget.process?.stage == ProcessStage.E2A;
    bool isSentStage = widget.process?.stage == ProcessStage.E3;

    String advanceLabel = mobile ? "Avanzar" : "Avanzar Etapa";
    IconData advanceIcon = LucideIcons.arrowRightCircle;
    Color advanceColor = const Color(0xFF10B981);

    if (isAuthStage) {
      advanceLabel = mobile ? "Autorizar" : "AUTORIZAR COTIZACIÓN";
      advanceIcon = LucideIcons.fileCheck2;
      advanceColor = const Color(0xFF4338CA);
    } else if (isSentStage) {
      advanceLabel = mobile ? "O.C. Recibida" : "ORDEN DE COMPRA RECIBIDA";
      advanceIcon = LucideIcons.shoppingBag;
      advanceColor = const Color(0xFF7C3AED);
    }

    if (mobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Fila 1: Acciones de etapa ──────────────────
            if (widget.process != null && canMoveStage)
              Row(
                children: [
                  if (canEditData || PermissionManager().can(widget.user, 'discard_process'))
                    IconButton(
                      onPressed: _handleDelete,
                      icon: Icon(
                        widget.process?.stage == ProcessStage.X
                            ? LucideIcons.trash2
                            : LucideIcons.xCircle,
                        color: widget.process?.stage == ProcessStage.X
                            ? Colors.red
                            : const Color(0xFF64748B),
                        size: 20,
                      ),
                      tooltip: widget.process?.stage == ProcessStage.X
                          ? "Eliminar"
                          : "Descartar",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleRegressStage,
                      icon: const Icon(LucideIcons.arrowLeftCircle, size: 16, color: Color(0xFFEA580C)),
                      label: const Text("Regresar", style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.w600, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFED7AA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleAdvanceStage,
                      icon: Icon(advanceIcon, size: 16, color: advanceColor),
                      label: Text(advanceLabel, style: TextStyle(color: advanceColor, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: advanceColor.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),

            if (widget.process != null && canMoveStage)
              const SizedBox(height: 10),

            // ── Fila 2: Cerrar + Guardar ───────────────────
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Text("Cerrar", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ),
                if (canEditData) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(LucideIcons.save, size: 16),
                      label: const Text("Guardar", style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // ── DESKTOP (tu diseño original) ──────────────────────
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (widget.process != null) ...[
            if (canEditData)
              IconButton(
                onPressed: _handleDelete,
                icon: Icon(
                  widget.process?.stage == ProcessStage.X
                      ? LucideIcons.trash2
                      : LucideIcons.xCircle,
                  color: widget.process?.stage == ProcessStage.X
                      ? Colors.red
                      : const Color(0xFF64748B),
                ),
                tooltip: widget.process?.stage == ProcessStage.X
                    ? "Eliminar Permanentemente"
                    : "Descartar Proceso",
              ),
            const SizedBox(width: 8),
            if (canMoveStage) ...[
              TextButton.icon(
                onPressed: _handleRegressStage,
                icon: const Icon(LucideIcons.arrowLeftCircle, size: 18, color: Color(0xFFEA580C)),
                label: const Text("Regresar", style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _handleAdvanceStage,
                icon: Icon(advanceIcon, size: 18, color: advanceColor),
                label: Text(advanceLabel, style: TextStyle(color: advanceColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          if (canEditData) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(LucideIcons.save, size: 16),
              label: const Text("Guardar Cambios"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera de sección ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.messageSquare,
                      size: 16, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                const Text(
                  "HISTORIAL Y COMENTARIOS",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                if (_comments.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_comments.length} ${_comments.length == 1 ? 'entrada' : 'entradas'}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Campo de nuevo comentario ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar del usuario actual
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name
                              .trim()
                              .split(' ')
                              .take(2)
                              .map((w) => w[0].toUpperCase())
                              .join()
                          : '?',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MentionTextField(
                    controller: _commentController,
                    onSubmit: _addComment,
                    onMentionsChanged: (ids) {
                      _pendingMentionIds = ids;
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de comentarios ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _comments.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          style: BorderStyle.solid),
                    ),
                    child: const Column(
                      children: [
                        Icon(LucideIcons.messageSquareDashed,
                            size: 28, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 10),
                        Text(
                          "Sin comentarios aún",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Las actualizaciones del proceso aparecerán aquí.",
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _comments
                        .map((c) => _buildCommentItem(c))
                        .toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel c) {
    // Clasificar el tipo de entrada
    final bool isRegression = c.text.startsWith("RETROCESO DE ETAPA");
    final bool isAdvance = c.text.startsWith("AVANCE DE ETAPA");
    final bool isAuthorized = c.text.startsWith("COTIZACIÓN COMPLETADA");
    final bool isDiscarded = c.text.startsWith("PROCESO DESCARTADO");
    final bool isNotification = c.text.startsWith("Notificación de O.C.");
    final bool isSystemEvent = isRegression ||
        isAdvance ||
        isAuthorized ||
        isDiscarded ||
        isNotification;

    // Determinar si el usuario actual puede editar este comentario
    final currentStageCode =
        (widget.process?.stage ?? ProcessStage.E1).toString().split('.').last;
    final bool canEditThisComment = !isSystemEvent &&
        c.userId == widget.user.id &&
        c.stageAtCreation == currentStageCode;

    // Paleta por tipo
    Color accentColor;
    Color bgColor;
    Color borderColor;
    IconData typeIcon;
    String? typeLabel;

    if (isRegression) {
      accentColor = const Color(0xFFEA580C);
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      typeIcon = LucideIcons.arrowLeftCircle;
      typeLabel = "RETROCESO";
    } else if (isAdvance) {
      accentColor = const Color(0xFF059669);
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFBBF7D0);
      typeIcon = LucideIcons.arrowRightCircle;
      typeLabel = "AVANCE";
    } else if (isAuthorized) {
      accentColor = const Color(0xFF4338CA);
      bgColor = const Color(0xFFEEF2FF);
      borderColor = const Color(0xFFC7D2FE);
      typeIcon = LucideIcons.shieldCheck;
      typeLabel = "AUTORIZACIÓN";
    } else if (isDiscarded) {
      accentColor = const Color(0xFF64748B);
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      typeIcon = LucideIcons.archive;
      typeLabel = "DESCARTADO";
    } else if (isNotification) {
      accentColor = const Color(0xFF7C3AED);
      bgColor = const Color(0xFFF5F3FF);
      borderColor = const Color(0xFFDDD6FE);
      typeIcon = LucideIcons.bellRing;
      typeLabel = "NOTIFICACIÓN";
    } else {
      accentColor = const Color(0xFF2563EB);
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      typeIcon = LucideIcons.messageSquare;
      typeLabel = null;
    }

    // Iniciales del autor
    final initials = c.userName.isNotEmpty
        ? c.userName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    // Texto limpio (quitar el prefijo de tipo si es evento de sistema)
    String displayText = c.text;
    if (isRegression) {
      displayText = c.text.replaceFirst("RETROCESO DE ETAPA: ", "");
    } else if (isAdvance) {
      displayText = c.text.replaceFirst("AVANCE DE ETAPA: ", "");
    } else if (isAuthorized) {
      displayText = c.text.replaceFirst("COTIZACIÓN COMPLETADA: ", "");
    } else if (isDiscarded) {
      displayText = c.text.replaceFirst("PROCESO DESCARTADO por ${c.userName}", "Movido a Descartados.");
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ícono / Avatar ────────────────────────────────
          if (isSystemEvent)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeIcon, size: 16, color: accentColor),
            )
          else
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ),

          const SizedBox(width: 12),

          // ── Contenido ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Badge de tipo (solo eventos de sistema)
                    if (typeLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        c.userName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSystemEvent ? accentColor : const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ── BADGE EDITADO ──
                    if (c.isEdited) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "editado",
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // ── BOTÓN EDITAR ──
                    if (canEditThisComment)
                      InkWell(
                        onTap: () => _editComment(c),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(LucideIcons.pencil,
                              size: 14, color: const Color(0xFF94A3B8)),
                        ),
                      ),
                    if (canEditThisComment) const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM · HH:mm', 'es').format(c.date),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // En lugar de Text(displayText, ...) usa:
                _buildMentionRichText(
                  displayText,
                  baseColor: isSystemEvent
                      ? accentColor.withOpacity(0.85)
                      : const Color(0xFF475569),
                  isSystemEvent: isSystemEvent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionRichText(String text,
      {required Color baseColor, bool isSystemEvent = false}) {
    final mentionRegex = RegExp(r'@[\wÀ-ÿ]+(?: [\wÀ-ÿ]+)?');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w700,
          backgroundColor: Color(0xFFEFF6FF),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: baseColor,
          fontWeight: isSystemEvent ? FontWeight.w500 : FontWeight.normal,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }
}