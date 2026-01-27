import 'package:flutter/material.dart';
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../services/ai_service.dart';

class GeneralInfoSection extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController clientController;
  final TextEditingController descriptionController;
  final String selectedPriority;
  final String? selectedRequester;
  final DateTime requestDate;
  final Function(String?) onPriorityChanged;
  final Function(String?) onRequesterChanged;
  final Function(DateTime) onDateChanged;

  const GeneralInfoSection({
    super.key,
    required this.titleController,
    required this.clientController,
    required this.descriptionController,
    required this.selectedPriority,
    required this.selectedRequester,
    required this.requestDate,
    required this.onPriorityChanged,
    required this.onRequesterChanged,
    required this.onDateChanged, ProcessStage? currentStage, required Null Function() onAdvance,
  });

  @override
  State<GeneralInfoSection> createState() => _GeneralInfoSectionState();
}

class _GeneralInfoSectionState extends State<GeneralInfoSection> {
  bool _isGenerating = false;

  int get daysElapsed => DateTime.now().difference(widget.requestDate).inDays;

  Color get priorityColor {
    switch (widget.selectedPriority) {
      case "Urgente": return const Color(0xFFDC2626);
      case "Alta": return const Color(0xFFEA580C);
      case "Media": return const Color(0xFFF59E0B);
      case "Baja": return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CARD 1: Información Principal
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Información Principal", LucideIcons.fileText),
              const SizedBox(height: 20),
              
              // Título (campo grande destacado)
              _buildInputField(
                label: "Título del Proyecto",
                controller: widget.titleController,
                icon: LucideIcons.briefcase,
                hint: "Ej: Instalación de Cámaras de Seguridad - Edificio Central",
                isLarge: true,
              ),
              const SizedBox(height: 20),
              
              // Cliente y Solicitante en fila
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: "Cliente",
                      value: widget.clientController.text.isEmpty ? null : widget.clientController.text,
                      icon: LucideIcons.building2,
                      items: ["Cliente A", "Cliente B", "Cliente C"],
                      onChanged: (val) => setState(() => widget.clientController.text = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      label: "Solicitada por",
                      value: widget.selectedRequester,
                      icon: LucideIcons.userCheck,
                      items: ["Gerardo Super Admin", "Ana Admin", "Carlos Pérez"],
                      onChanged: widget.onRequesterChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // CARD 2: Seguimiento
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Seguimiento", LucideIcons.clock),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildDaysCounter()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildPrioritySelector()),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // CARD 3: Descripción
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSectionTitle("Alcance del Proyecto", LucideIcons.fileText),
                  _buildAIButton(),
                ],
              ),
              const SizedBox(height: 16),
              _buildDescriptionField(),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGETS DE CONSTRUCCIÓN ---

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool isLarge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: isLarge ? 15 : 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isLarge ? 18 : 14,
            ),
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
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e),
          )).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: "Seleccionar...",
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "FECHA DE SOLICITUD",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: widget.requestDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              builder: (context, child) => Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
                ),
                child: child!,
              ),
            );
            if (picked != null) widget.onDateChanged(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM, yyyy').format(widget.requestDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysCounter() {
    final isUrgent = daysElapsed > 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TIEMPO TRANSCURRIDO",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUrgent
                ? const Color(0xFFFEF3C7).withOpacity(0.5)
                : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent
                  ? const Color(0xFFF59E0B).withOpacity(0.3)
                  : const Color(0xFF10B981).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$daysElapsed días",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isUrgent ? "Atención requerida" : "En proceso",
                  style: TextStyle(
                    fontSize: 12,
                    color: isUrgent ? const Color(0xFFD97706) : const Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isUrgent ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                size: 16,
                color: isUrgent ? const Color(0xFFD97706) : const Color(0xFF059669),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "PRIORIDAD",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: widget.selectedPriority,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
          items: ["Baja", "Media", "Alta", "Urgente"].map((e) {
            Color color;
            switch (e) {
              case "Urgente": color = const Color(0xFFDC2626); break;
              case "Alta": color = const Color(0xFFEA580C); break;
              case "Media": color = const Color(0xFFF59E0B); break;
              case "Baja": color = const Color(0xFF10B981); break;
              default: color = const Color(0xFF64748B);
            }
            return DropdownMenuItem(
              value: e,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(e),
                ],
              ),
            );
          }).toList(),
          onChanged: widget.onPriorityChanged,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            filled: true,
            fillColor: priorityColor.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: priorityColor.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: priorityColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: priorityColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: widget.descriptionController,
      maxLines: 6,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: "Describe el alcance, requerimientos técnicos, entregables esperados...",
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          height: 1.6,
        ),
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    );
  }

  Widget _buildAIButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isGenerating
                ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                : [const Color(0xFF7C3AED), const Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: (_isGenerating ? const Color(0xFF64748B) : const Color(0xFF7C3AED))
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isGenerating ? null : _handleAI,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isGenerating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isGenerating ? "Generando..." : "Mejorar con IA",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAI() async {
    if (widget.titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.alertCircle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text("Por favor, ingresa un título para ayudar a la IA"),
            ],
          ),
          backgroundColor: const Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    setState(() => _isGenerating = true);
    try {
      String res = await AIService.generateDescription(
        title: widget.titleController.text,
        client: widget.clientController.text,
      );
      setState(() => widget.descriptionController.text = res);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text("Descripción generada exitosamente"),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.xCircle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text("Error: ${e.toString()}"),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}