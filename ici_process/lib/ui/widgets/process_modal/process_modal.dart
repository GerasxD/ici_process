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

    if (widget.process?.stage == ProcessStage.X) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(LucideIcons.trash2, color: Colors.red),
              SizedBox(width: 10),
              Text("Eliminar Permanente", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Este proceso será eliminado definitivamente y no podrá recuperarse.\n\n¿Estás seguro?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Sí, Eliminar Para Siempre"),
            ),
          ],
        ),
      );

      if (confirm == true && widget.process != null) {
        await _processService.deleteProcess(widget.process!.id);
        if (mounted) Navigator.pop(context);
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(LucideIcons.xCircle, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Text("Descartar Proceso", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "El proceso se moverá a la sección 'Descartado'.\n\nPodrá recuperarse o eliminarse permanentemente desde ahí.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64748B),
                foregroundColor: Colors.white,
              ),
              child: const Text("Sí, Descartar"),
            ),
          ],
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

    String dialogTitle =
        isAuthorizing ? "¿Autorizar Cotización?" : "¿Avanzar Etapa?";
    String dialogContent = isAuthorizing
        ? "La cotización será enviada a Autorización (E2A). ¿Confirmas que los montos son correctos?"
        : "El proceso pasará a la siguiente fase: ${nextStage.name}. ¿Deseas continuar?";
    String confirmBtnText = isAuthorizing ? "Autorizar y Enviar" : "Avanzar";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAuthorizing ? const Color(0xFF4338CA) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmBtnText),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.arrowLeftCircle, color: Color(0xFFEA580C)),
            SizedBox(width: 12),
            Text("Retroceder Etapa",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Por favor, indica el motivo por el cual estás regresando este proyecto:",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regressionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Escribe el motivo aquí...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_regressionController.text.isNotEmpty) {
                Navigator.pop(context);
                _confirmRegress();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Confirmar Retroceso"),
          ),
        ],
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