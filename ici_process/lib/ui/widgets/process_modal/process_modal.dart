import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'general_info_section.dart';
import '../../../models/process_model.dart';
import '../../../models/user_model.dart';
import '../../../services/process_service.dart';
import '../../../core/constants/app_constants.dart';

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
  final _regressionController = TextEditingController(); // Motivo retroceso

  String _priority = 'Media';
  String? _requestedBy;
  DateTime _requestDate = DateTime.now();
  List<CommentModel> _comments = [];
  final ProcessService _processService = ProcessService();

  @override
  void initState() {
    super.initState();
    if (widget.process != null) {
      _titleController.text = widget.process!.title;
      _clientController.text = widget.process!.client;
      _descriptionController.text = widget.process!.description;
      _priority = widget.process!.priority;
      _requestedBy = widget.process!.requestedBy;
      _requestDate = widget.process!.requestDate;
      _comments = List.from(widget.process!.comments);
    }
  }

  // --- LÓGICA DE ELIMINACIÓN ---
  Future<void> _handleDelete() async {
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
    // 1. Validaciones iniciales
    if (widget.process == null) return;

    final stages = ProcessStage.values;
    final currentIndex = stages.indexOf(widget.process!.stage);

    // Evitar avanzar si ya es la última etapa
    if (currentIndex >= stages.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Este proceso ya se encuentra en la etapa final.")),
      );
      return;
    }

    final nextStage = stages[currentIndex + 1];

    // 2. Diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Avanzar Etapa?"),
        content: Text("El proceso pasará a la siguiente fase: ${nextStage.name}. ¿Deseas continuar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancelar")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text("Avanzar"),
          ),
        ],
      ),
    );

    // 3. Ejecutar cambio si confirmó
    if (confirm == true) {
      final fechaActual = DateTime.now();

      // Crear entrada de historial
      final historyEntry = HistoryEntry(
        action: "Avance de Etapa",
        userName: widget.user.name,
        date: fechaActual,
        details: "Avance exitoso a etapa ${nextStage.name}",
      );

      // Opcional: Agregar un comentario automático de sistema
      setState(() {
         _comments.insert(0, CommentModel(
           id: fechaActual.millisecondsSinceEpoch.toString(),
           text: "🚀 AVANCE DE ETAPA: El proceso avanzó a ${nextStage.name}",
           userName: widget.user.name,
           date: fechaActual,
         ));
      });

      // Construir y guardar
      final updated = _buildModelFromState(nextStage, historyEntry);
      
      await _processService.updateProcess(updated);
      
      if (mounted) Navigator.pop(context); // Cerrar modal al finalizar
    }
  }

  // --- LÓGICA DE RETROCESO ---
  void _handleRegressStage() {
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

      // 1. Creamos la entrada del historial
      final historyEntry = HistoryEntry(
        action: "Retroceso de Etapa",
        userName: widget.user.name,
        date: fechaActual,
        details: "Motivo: $motivo",
      );

      // 2. AGREGAMOS EL MOTIVO A LA LISTA DE COMENTARIOS AUTOMÁTICAMENTE
      setState(() {
        _comments.insert(0, CommentModel(
          id: fechaActual.millisecondsSinceEpoch.toString(),
          text: "🔄 RETROCESO DE ETAPA: $motivo", // Texto distintivo
          userName: widget.user.name,
          date: fechaActual,
        ));
      });

      // 3. Construimos el modelo con la nueva etapa y la lista de comentarios actualizada
      final updated = _buildModelFromState(prevStage, historyEntry);
      
      await _processService.updateProcess(updated);
      
      _regressionController.clear(); // Limpiamos el controlador
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
    );
  }

  Future<void> _save() async {
    // 1. Validación de campos obligatorios
    if (_titleController.text.isEmpty || _clientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Título y Cliente son obligatorios")),
      );
      return;
    }

    try {
      // 2. Determinar si es un proceso nuevo
      final bool isNew = widget.process == null;

      // 3. Crear la entrada de historial adecuada
      final entry = HistoryEntry(
        action: isNew ? "Solicitud Creada" : "Edición Manual",
        userName: widget.user.name,
        date: DateTime.now(),
      );

      // 4. Construir el modelo con los datos actuales
      final processModel = _buildModelFromState(
        widget.process?.stage ?? ProcessStage.E1, 
        entry
      );

      // 5. Lógica de persistencia diferenciada
      if (isNew) {
        // Crear: usa .set() para que el ID temporal se registre
        await _processService.createProcess(processModel);
      } else {
        // Actualizar: usa .update() para modificar el existente
        await _processService.updateProcess(processModel);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("❌ Error detallado al guardar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: ${e.toString()}")),
        );
      }
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
                    GeneralInfoSection(
                      titleController: _titleController,
                      clientController: _clientController,
                      descriptionController: _descriptionController,
                      selectedPriority: _priority,
                      selectedRequester: _requestedBy,
                      requestDate: _requestDate,
                      currentStage: widget.process?.stage,
                      onPriorityChanged: (val) => setState(() => _priority = val!),
                      onRequesterChanged: (val) => setState(() => _requestedBy = val),
                      onDateChanged: (val) => setState(() => _requestDate = val), onAdvance: () {  },
                      // ❌ YA NO PASAMOS onAdvance aquí, lo manejamos en el footer
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
          Text(widget.process == null ? "NUEVO PROCESO" : "EDITAR PROCESO", 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x))
        ],
      ),
    );
  }

  // ✅ AQUÍ ES DONDE AGREGAMOS EL BOTÓN
  Widget _buildModalFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          if (widget.process != null) ...[
            // BOTÓN ELIMINAR
            IconButton(
              onPressed: _handleDelete, 
              icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
              tooltip: "Eliminar Proceso",
            ),
            const SizedBox(width: 8),
            
            // BOTÓN REGRESAR (Naranja)
            TextButton.icon(
              onPressed: _handleRegressStage,
              icon: const Icon(LucideIcons.arrowLeftCircle, size: 18, color: Color(0xFFEA580C)),
              label: const Text("Regresar", style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
            ),

            const SizedBox(width: 8),

            // ✅ NUEVO BOTÓN AVANZAR (Verde) - SOLO SI NO ESTAMOS EDITANDO UN NUEVO PROCESO
            TextButton.icon(
              onPressed: _handleAdvanceStage,
              icon: const Icon(LucideIcons.arrowRightCircle, size: 18, color: Color(0xFF10B981)), // Verde
              label: const Text("Avanzar Etapa", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
          ],
          
          const Spacer(), // Empuja los botones de Guardar a la derecha
          
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
        ],
      ),
    );
  }

  // --- Sección de Comentarios ---
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
          // Encabezado
          const Row(
            children: [
              Icon(LucideIcons.messageSquare, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 12),
              Text(
                "NOTAS Y COMENTARIOS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Campo de texto para nuevo comentario
          TextField(
            controller: _commentController,
            onSubmitted: (_) => _addComment(), 
            decoration: InputDecoration(
              hintText: "Escribe una actualización...",
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                onPressed: _addComment,
                icon: const Icon(LucideIcons.send, color: Color(0xFF2563EB), size: 20),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Lista de comentarios
          if (_comments.isEmpty)
            const Center(
              child: Text(
                "No hay comentarios aún.",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            )
          else
            Column(
              children: _comments.map((c) => _buildCommentItem(c)).toList(),
            ),
        ],
      ),
    );
  }

  // Helper para renderizar cada burbuja de comentario
  Widget _buildCommentItem(CommentModel c) {
    // Detectar si es un mensaje de sistema por retroceso o avance
    bool isRegression = c.text.contains("🔄 RETROCESO");
    bool isAdvance = c.text.contains("🚀 AVANCE"); // Nuevo: estilo para avance

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isRegression) {
      bgColor = const Color(0xFFFFF7ED); // Naranja claro
      borderColor = Colors.orange.shade200;
      textColor = const Color(0xFF9A3412);
    } else if (isAdvance) {
      bgColor = const Color(0xFFECFDF5); // Verde claro
      borderColor = Colors.green.shade200;
      textColor = const Color(0xFF065F46);
    } else {
      bgColor = const Color(0xFFF1F5F9); // Gris default
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
                  color: isRegression ? Colors.orange.shade700 : (isAdvance ? Colors.green.shade700 : const Color(0xFF2563EB)),
                ),
              ),
              Text(
                DateFormat('dd/MM HH:mm').format(c.date),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.text,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: (isRegression || isAdvance) ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}