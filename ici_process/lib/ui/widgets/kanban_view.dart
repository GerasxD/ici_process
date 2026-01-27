import 'package:flutter/material.dart';
import '../../services/process_service.dart';
import '../../models/process_model.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import 'process_card.dart';
import 'process_modal/process_modal.dart';

class KanbanView extends StatelessWidget {
  final UserModel currentUser; // Necesitamos al usuario para filtrar visibilidad

  const KanbanView({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ProcessService _service = ProcessService();

    return Container(
      color: const Color(0xFFF8FAFC), // Fondo mejorado más claro
      child: StreamBuilder<List<ProcessModel>>(
        stream: _service.getProcessesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allProcesses = snapshot.data ?? [];

          // Filtramos qué etapas puede ver este usuario según las constantes
          final visibleStages = ProcessStage.values.where((stage) {
            return stageConfigs[stage]!.visibility.contains(currentUser.role);
          }).toList();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(24), // Más padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visibleStages.map((stage) {
                final config = stageConfigs[stage]!;
                // Filtramos procesos que pertenecen a esta columna
                final stageProcesses = allProcesses.where((p) => p.stage == stage).toList();

                return _buildKanbanColumn(context, stage, config, stageProcesses);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanColumn(BuildContext context, ProcessStage stage, StageConfig config, List<ProcessModel> processes) {
    return Container(
      width: 320, // Ancho un poco más amplio
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white, // Fondo blanco en lugar de gris
        borderRadius: BorderRadius.circular(16), // Bordes más redondeados
        border: Border.all(color: const Color(0xFFE2E8F0)), // Borde sutil
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header de la Columna - Diseño mejorado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  config.color,
                  config.color.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: config.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono con fondo
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(config.icon, size: 18, color: config.textColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.title,
                    style: TextStyle(
                      color: config.textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Badge de contador mejorado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    "${processes.length}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: config.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de Tarjetas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12), // Padding mejorado
              itemCount: processes.length,
              itemBuilder: (context, index) {
                final process = processes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12), // Más espacio entre cards
                  child: ProcessCard(
                    item: {
                      'id': process.id,
                      'title': process.title,
                      'client': process.client,
                      'priority': process.priority,
                      'amount': process.amount,
                      'updatedAt': process.updatedAt.toIso8601String(),
                    },
                    onClick: () => showDialog(
                      context: context, 
                      builder: (_) => ProcessModal(process: process, user: currentUser,)
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}