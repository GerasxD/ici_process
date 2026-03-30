import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ici_process/services/user_service.dart';
import 'package:ici_process/ui/widgets/process_modal/logistics_section.dart';
import 'package:ici_process/ui/widgets/process_modal/quote_form_modal.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'general_info_section.dart';
import '../../../models/process_model.dart';
import '../../../models/user_model.dart';
import '../../../services/process_service.dart';
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

  String _priority = 'Media';
  String? _requestedBy;
  DateTime _requestDate = DateTime.now();
  List<CommentModel> _comments = [];
  final ProcessService _processService = ProcessService();

  bool canEditData = false;
  bool canMoveStage = false;
  bool canViewFinancials = false; 

  final _ocNumberController = TextEditingController();
  bool _isNoOc = false;
  DateTime? _ocReceptionDate;

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
    if (!canEditData) return;

    // ── ELIMINAR PERMANENTEMENTE (desde etapa X) ──────────
    if (widget.process?.stage == ProcessStage.X) {
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
        await _processService.deleteProcess(widget.process!.id);
        if (mounted) Navigator.pop(context);
      }
    }
    // ── DESCARTAR (mover a etapa X) ───────────────────────
    else {
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
              text: "🗑️ PROCESO DESCARTADO por ${widget.user.name}",
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
            ? "✅ COTIZACIÓN COMPLETADA: Se ha enviado a espera de autorización."
            : "🚀 AVANCE DE ETAPA: El proceso avanzó a ${nextStage.name}";
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

    final prevStage = stages[currentIndex - 1];
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
      final prevStage = stages[currentIndex - 1];
      final motivo = _regressionController.text.trim();
      final fechaActual = DateTime.now();
      final historyEntry = HistoryEntry(
        action: "Retroceso de Etapa",
        userName: widget.user.name,
        date: fechaActual,
        details: "Motivo: $motivo",
      );
      setState(() {
        _comments.insert(
          0,
          CommentModel(
            id: fechaActual.millisecondsSinceEpoch.toString(),
            text: "🔄 RETROCESO DE ETAPA: $motivo",
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
    setState(() {
      _comments.insert(
        0,
        CommentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: _commentController.text.trim(),
          userName: widget.user.name,
          date: DateTime.now(),
        ),
      );
      _commentController.clear();
    });
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
    );
  }

  // ── SAVE ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!canEditData) return;
    if (_titleController.text.isEmpty || _clientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Título y Cliente son obligatorios")),
      );
      return;
    }
    try {
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

  // ── QUOTE ─────────────────────────────────────────────────
  Future<void> _openQuoteModal() async {
    if (widget.process == null) return;
    await showDialog(
      context: context,
      builder: (_) => QuoteFormModal(process: widget.process!),
    );
    final updatedProcess = await _processService.getProcessById(widget.process!.id);
    if (updatedProcess != null && mounted) {
      setState(() {
        _amountController.text = updatedProcess.amount.toString();
        _costController.text = updatedProcess.estimatedCost.toString();
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
    await showDialog(
      context: context,
      builder: (ctx) {
        Set<String> selectedUserIds = {};
        return AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.bellRing, color: Color(0xFF7C3AED)),
              SizedBox(width: 10),
              Text("Notificar Usuarios"),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: StreamBuilder<List<UserModel>>(
              stream: UserService().getUsersStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!;
                return StatefulBuilder(
                  builder: (context, setStateDialog) => ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      if (u.id == widget.user.id) return const SizedBox.shrink();
                      final isSelected = selectedUserIds.contains(u.id);
                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: const Color(0xFF7C3AED),
                        title: Text(u.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(u.email,
                            style: const TextStyle(fontSize: 12)),
                        secondary: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Text(u.name.isNotEmpty ? u.name[0] : 'U'),
                        ),
                        onChanged: (val) {
                          setStateDialog(() {
                            if (val == true) {
                              selectedUserIds.add(u.id);
                            } else {
                              selectedUserIds.remove(u.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (selectedUserIds.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  final collRef =
                      FirebaseFirestore.instance.collection('notifications');
                  for (final targetId in selectedUserIds) {
                    final docRef = collRef.doc();
                    batch.set(docRef, {
                      'targetUserId': targetId,
                      'title': '📌 O.C. Recibida',
                      'body': 'Proyecto: ${_titleController.text}',
                      'read': false,
                      'createdAt': FieldValue.serverTimestamp(),
                      'senderName': widget.user.name,
                      'processId': widget.process?.id ?? '',
                    });
                  }
                  await batch.commit();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Notificación enviada a ${selectedUserIds.length} usuarios"),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                  setState(() {
                    _comments.insert(
                      0,
                      CommentModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        text:
                            "🔔 Se notificó sobre la O.C. a ${selectedUserIds.length} personas.",
                        userName: widget.user.name,
                        date: DateTime.now(),
                      ),
                    );
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Error al enviar notificaciones")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(LucideIcons.send, size: 16),
              label: const Text("Enviar Notificación"),
            ),
          ],
        );
      },
    );
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isE5 = widget.process?.stage == ProcessStage.E5;

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
                          extraSection: (isE5 && widget.process != null) 
                          ? LogisticsSection(
                              process: widget.process!,
                              isEditable: canEditData,
                              initialData: _currentLogisticsData,
                              canViewFinancials: canViewFinancials,
                              currentUserName: widget.user.name, // ← NUEVO
                              onDataChanged: (data) {
                                _currentLogisticsData = data;
                              },
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

  // ── FOOTER ────────────────────────────────────────────────
  Widget _buildModalFooter() {
    bool isAuthStage = widget.process?.stage == ProcessStage.E2A;
    bool isSentStage = widget.process?.stage == ProcessStage.E3;

    String advanceLabel = "Avanzar Etapa";
    IconData advanceIcon = LucideIcons.arrowRightCircle;
    Color advanceColor = const Color(0xFF10B981);

    if (isAuthStage) {
      advanceLabel = "AUTORIZAR COTIZACIÓN";
      advanceIcon = LucideIcons.fileCheck2;
      advanceColor = const Color(0xFF4338CA);
    } else if (isSentStage) {
      advanceLabel = "ORDEN DE COMPRA RECIBIDA";
      advanceIcon = LucideIcons.shoppingBag;
      advanceColor = const Color(0xFF7C3AED);
    }

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
                icon: const Icon(LucideIcons.arrowLeftCircle,
                    size: 18, color: Color(0xFFEA580C)),
                label: const Text("Regresar",
                    style: TextStyle(
                        color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _handleAdvanceStage,
                icon: Icon(advanceIcon, size: 18, color: advanceColor),
                label: Text(advanceLabel,
                    style: TextStyle(
                        color: advanceColor, fontWeight: FontWeight.bold)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── COMMENTS ──────────────────────────────────────────────
  Widget _buildCommentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.messageSquare, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 12),
              Text("NOTAS Y COMENTARIOS",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            onSubmitted: (_) => _addComment(),
            decoration: InputDecoration(
              hintText: "Escribe una actualización...",
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                onPressed: _addComment,
                icon: const Icon(LucideIcons.send,
                    color: Color(0xFF2563EB), size: 20),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          if (_comments.isEmpty)
            const Center(
              child: Text("No hay comentarios aún.",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic)),
            )
          else
            Column(children: _comments.map((c) => _buildCommentItem(c)).toList()),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel c) {
    bool isRegression = c.text.contains("🔄 RETROCESO");
    bool isAdvance = c.text.contains("🚀 AVANCE");
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isRegression) {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = Colors.orange.shade200;
      textColor = const Color(0xFF9A3412);
    } else if (isAdvance) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = Colors.green.shade200;
      textColor = const Color(0xFF065F46);
    } else {
      bgColor = const Color(0xFFF1F5F9);
      borderColor = Colors.transparent;
      textColor = const Color(0xFF334155);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: (isRegression || isAdvance) ? Border.all(color: borderColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.userName,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isRegression
                        ? Colors.orange.shade700
                        : (isAdvance
                            ? Colors.green.shade700
                            : const Color(0xFF2563EB))),
              ),
              Text(DateFormat('dd/MM HH:mm').format(c.date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.text,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight:
                  (isRegression || isAdvance) ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}