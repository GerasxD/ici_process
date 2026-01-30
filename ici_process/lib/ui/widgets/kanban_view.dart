import 'package:flutter/material.dart';
import '../../services/process_service.dart';
import '../../models/process_model.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import 'process_card.dart';
import 'process_modal/process_modal.dart';
// 1. IMPORTAMOS EL GESTOR DE PERMISOS
import '../../core/utils/permission_manager.dart'; 

class KanbanView extends StatelessWidget {
  final UserModel currentUser;

  const KanbanView({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ProcessService _service = ProcessService();
    // 2. Instanciamos el Manager
    final PermissionManager _pm = PermissionManager();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: StreamBuilder<List<ProcessModel>>(
        stream: _service.getProcessesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allProcesses = snapshot.data ?? [];

          // 3. FILTRO DINÁMICO:
          // Recorremos todas las etapas definidas en el Enum y filtramos solo las permitidas.
          final visibleStages = ProcessStage.values.where((stage) {
            // Obtenemos el código de la etapa, ej: "E1", "E2A", "X"
            final stageCode = stage.toString().split('.').last;
            
            // Construimos el nombre del permiso esperado: 'stage_view_E1'
            final permissionCode = 'stage_view_$stageCode';
            
            // Verificamos si el usuario tiene ese permiso activado en la DB
            return _pm.can(currentUser, permissionCode);
          }).toList();

          // Si no tiene permisos para ninguna columna, mostramos un aviso
          if (visibleStages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("No tienes permisos para ver ninguna etapa del flujo.", 
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visibleStages.map((stage) {
                // Seguimos usando stageConfigs para obtener Colores e Iconos (Estética)
                final config = stageConfigs[stage]!;
                
                // Filtramos las tarjetas que pertenecen a esta columna
                final stageProcesses = allProcesses.where((p) => p.stage == stage).toList();

                return _buildKanbanColumn(context, stage, config, stageProcesses);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // Este widget se mantiene igual visualmente
  Widget _buildKanbanColumn(BuildContext context, ProcessStage stage, StageConfig config, List<ProcessModel> processes) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Header de la Columna
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
              padding: const EdgeInsets.all(12),
              itemCount: processes.length,
              itemBuilder: (context, index) {
                final process = processes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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