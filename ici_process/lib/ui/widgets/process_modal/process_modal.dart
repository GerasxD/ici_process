import 'package:flutter/material.dart';
import 'package:ici_process/ui/widgets/process_modal/quote_form_modal.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'general_info_section.dart';
import '../../../models/process_model.dart';
import '../../../models/user_model.dart';
import '../../../services/process_service.dart';
import '../../../core/constants/app_constants.dart';
// 1. IMPORTAR GESTOR DE PERMISOS
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

  String _priority = 'Media';
  String? _requestedBy;
  DateTime _requestDate = DateTime.now();
  List<CommentModel> _comments = [];
  final ProcessService _processService = ProcessService();

  // 2. VARIABLES DE PERMISOS
  bool canEditData = false; // Puede editar textos (título, descripción)
  bool canMoveStage = false; // Puede avanzar/retroceder etapas

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkPermissions(); // Verificamos permisos al iniciar
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
    }
  }

  // 3. LÓGICA DE PERMISOS CORREGIDA
  void _checkPermissions() {
    final pm = PermissionManager();
    final currentStage = widget.process?.stage ?? ProcessStage.E1;
    final stageCode = currentStage.toString().split('.').last;
    
    // A. Permiso para EDITAR DATOS (Títulos, montos, etc.)
    // Depende de si tiene permiso de edición específico en esta etapa
    canEditData = pm.can(widget.user, 'stage_edit_$stageCode');

    // B. Permiso para MOVER ETAPAS (Botones Avanzar/Regresar)
    // Requiere DOS cosas:
    // 1. Tener activado el switch global "Mover Etapas (Kanban)" ('move_stage')
    // 2. Tener permiso de edición en la etapa actual ('stage_edit_XX')
    bool globalMovePermission = pm.can(widget.user, 'move_stage');
    
    canMoveStage = globalMovePermission && canEditData;
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
    super.dispose();
  }

  // --- LÓGICA DE ELIMINACIÓN ---
  Future<void> _handleDelete() async {
    // Solo si puede editar datos
    if (!canEditData) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar Proceso?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Eliminar")
          ),
        ],
      ),
    );

    if (confirm == true && widget.process != null) {
      await _processService.deleteProcess(widget.process!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  // --- LÓGICA DE AVANCE DE ETAPA ---
  Future<void> _handleAdvanceStage() async {
    // Validación de seguridad estricta
    if (!canMoveStage) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tienes permiso para mover etapas.")));
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Avanzar Etapa?"),
        content: Text("El proceso pasará a la siguiente fase: ${nextStage.name}. ¿Deseas continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            child: const Text("Avanzar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final fechaActual = DateTime.now();
      final historyEntry = HistoryEntry(
        action: "Avance de Etapa",
        userName: widget.user.name,
        date: fechaActual,
        details: "Avance exitoso a etapa ${nextStage.name}",
      );

      setState(() {
         _comments.insert(0, CommentModel(
           id: fechaActual.millisecondsSinceEpoch.toString(),
           text: "🚀 AVANCE DE ETAPA: El proceso avanzó a ${nextStage.name}",
           userName: widget.user.name,
           date: fechaActual,
         ));
      });

      final updated = _buildModelFromState(nextStage, historyEntry);
      await _processService.updateProcess(updated);
      if (mounted) Navigator.pop(context);
    }
  }

  // --- LÓGICA DE RETROCESO ---
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
            Text("Retroceder Etapa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Por favor, indica el motivo por el cual estás regresando este proyecto:",
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
        _comments.insert(0, CommentModel(
          id: fechaActual.millisecondsSinceEpoch.toString(),
          text: "🔄 RETROCESO DE ETAPA: $motivo", 
          userName: widget.user.name,
          date: fechaActual,
        ));
      });

      final updated = _buildModelFromState(prevStage, historyEntry);
      await _processService.updateProcess(updated);
      _regressionController.clear(); 
      if (mounted) Navigator.pop(context);
    }
  }

  // --- MÉTODOS DE APOYO ---
  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      _comments.insert(0, CommentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: _commentController.text.trim(),
        userName: widget.user.name,
        date: DateTime.now(),
      ));
      _commentController.clear();
    });
  }

  ProcessModel _buildModelFromState(ProcessStage stage, HistoryEntry newEntry) {
    double finalAmount = double.tryParse(_amountController.text) ?? 0.0;
    double finalCost = double.tryParse(_costController.text) ?? 0.0;
    return ProcessModel(
      id: widget.process?.id ?? "PROC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
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
    );
  }

  Future<void> _save() async {
    // Si no puede editar datos, no puede guardar
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
        entry
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

  // En ProcessModal, modifica el método _openQuoteModal para que sea async y recargue datos

  Future<void> _openQuoteModal() async {
    if (widget.process == null) return;
    
    // 1. Abrimos el modal y esperamos a que se cierre (await)
    await showDialog(
      context: context, 
      builder: (_) => QuoteFormModal(process: widget.process!)
    );

    // 2. Al volver, recargamos el proceso desde la base de datos
    // Esto asegura que GeneralInfoSection reciba los montos nuevos
    final updatedProcess = await _processService.getProcessById(widget.process!.id);
    
    if (updatedProcess != null && mounted) {
      setState(() {
        // Actualizamos los controladores locales con los nuevos valores
        _amountController.text = updatedProcess.amount.toString();
        _costController.text = updatedProcess.estimatedCost.toString();
      });
    }
  }
  @override
  Widget build(BuildContext context) {
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
                    // 4. Bloqueo de inputs basado en canEditData
                    AbsorbPointer(
                      absorbing: !canEditData, 
                      child: Opacity(
                        opacity: canEditData ? 1.0 : 0.7, 
                        child: GeneralInfoSection(
                          titleController: _titleController,
                          clientController: _clientController,
                          descriptionController: _descriptionController,
                          amountController: _amountController,
                          costController: _costController,
                          selectedPriority: _priority,
                          selectedRequester: _requestedBy,
                          requestDate: _requestDate,
                          currentStage: widget.process?.stage,
                          onPriorityChanged: (val) => setState(() => _priority = val!),
                          onRequesterChanged: (val) => setState(() => _requestedBy = val),
                          onDateChanged: (val) => setState(() => _requestDate = val),
                          onOpenQuote: _openQuoteModal,
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

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(widget.process == null ? "NUEVO PROCESO" : "EDITAR PROCESO", 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              if (!canEditData) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: const Row(children: [Icon(LucideIcons.lock, size: 12, color: Colors.grey), SizedBox(width: 4), Text("Solo Lectura", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                )
              ]
            ],
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x))
        ],
      ),
    );
  }

  // ✅ FOOTER: Aquí está la magia de los botones
  Widget _buildModalFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          if (widget.process != null) ...[
            // ELIMINAR: Depende de canEditData (editar/borrar datos)
            if (canEditData)
              IconButton(
                onPressed: _handleDelete, 
                icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                tooltip: "Eliminar Proceso",
              ),
            
            const SizedBox(width: 8),
            
            // MOVER ETAPAS: Depende de canMoveStage (Switch global + permiso específico)
            if (canMoveStage) ...[
              TextButton.icon(
                onPressed: _handleRegressStage,
                icon: const Icon(LucideIcons.arrowLeftCircle, size: 18, color: Color(0xFFEA580C)),
                label: const Text("Regresar", style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
              ),

              const SizedBox(width: 8),

              TextButton.icon(
                onPressed: _handleAdvanceStage,
                icon: const Icon(LucideIcons.arrowRightCircle, size: 18, color: Color(0xFF10B981)), 
                label: const Text("Avanzar Etapa", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
            ],
          ],
          
          const Spacer(),
          
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar")),
          
          // GUARDAR: Depende de canEditData
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
            ),
          ]
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.messageSquare, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 12),
              Text("NOTAS Y COMENTARIOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            onSubmitted: (_) => _addComment(), 
            decoration: InputDecoration(
              hintText: "Escribe una actualización...",
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(onPressed: _addComment, icon: const Icon(LucideIcons.send, color: Color(0xFF2563EB), size: 20)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          if (_comments.isEmpty)
            const Center(child: Text("No hay comentarios aún.", style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)))
          else
            Column(children: _comments.map((c) => _buildCommentItem(c)).toList()),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel c) {
    bool isRegression = c.text.contains("🔄 RETROCESO");
    bool isAdvance = c.text.contains("🚀 AVANCE"); 
    Color bgColor; Color borderColor; Color textColor;

    if (isRegression) {
      bgColor = const Color(0xFFFFF7ED); borderColor = Colors.orange.shade200; textColor = const Color(0xFF9A3412);
    } else if (isAdvance) {
      bgColor = const Color(0xFFECFDF5); borderColor = Colors.green.shade200; textColor = const Color(0xFF065F46);
    } else {
      bgColor = const Color(0xFFF1F5F9); borderColor = Colors.transparent; textColor = const Color(0xFF334155);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: (isRegression || isAdvance) ? Border.all(color: borderColor) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isRegression ? Colors.orange.shade700 : (isAdvance ? Colors.green.shade700 : const Color(0xFF2563EB)))),
              Text(DateFormat('dd/MM HH:mm').format(c.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.text, style: TextStyle(fontSize: 13, color: textColor, fontWeight: (isRegression || isAdvance) ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}