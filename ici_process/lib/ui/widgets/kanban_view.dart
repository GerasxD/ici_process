import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../services/process_service.dart';
import '../../models/process_model.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import 'process_card.dart';
import 'process_modal/process_modal.dart';
import '../../core/utils/permission_manager.dart';

class KanbanView extends StatefulWidget {
  final UserModel currentUser;

  const KanbanView({super.key, required this.currentUser});

  @override
  State<KanbanView> createState() => _KanbanViewState();
}

class _KanbanViewState extends State<KanbanView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProcessService service = ProcessService();
    final PermissionManager pm = PermissionManager();
    final bool canViewFinancials = pm.can(widget.currentUser, 'view_financials');

    return StreamBuilder<List<ProcessModel>>(
      stream: service.getProcessesStream(
        currentUserId: widget.currentUser.id,
        currentUserRole: widget.currentUser.role,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allProcesses = snapshot.data ?? [];

        final visibleStages = ProcessStage.values.where((stage) {
          final stageCode = stage.toString().split('.').last;
          return pm.can(widget.currentUser, 'stage_view_$stageCode');
        }).toList();

        if (visibleStages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  "No tienes permisos para ver ninguna etapa del flujo.",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visibleStages.map((stage) {
                final config = stageConfigs[stage]!;
                final stageProcesses =
                    allProcesses.where((p) => p.stage == stage).toList();
                return _buildKanbanColumn(
                    context, stage, config, stageProcesses, canViewFinancials);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn(BuildContext context, ProcessStage stage,
      StageConfig config, List<ProcessModel> processes, bool canViewFinancials) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [config.color, config.color.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                      // ── Campos para seguimiento de etapas ──
                      'stage': process.stage.toString().split('.').last,
                      'attendedBy': _findUserForAction(process.history, 'a etapa E2'),
                      'quotedBy': _findUserForAction(process.history, 'revisión (E2A)'),
                      'authorizedBy': _findUserForAction(process.history, 'a etapa E3'),
                      'ocReceivedBy': _findUserForAction(process.history, 'a etapa E4'),
                      'handledBy': _findUserForAction(process.history, 'a etapa E5'),
                      'isPrivate': process.isPrivate,
                      'reportSent': process.reportBillingData?['reportSent'] ?? false,
                      'invoiceSent': process.reportBillingData?['invoiceSent'] ?? false,
                    },
                    canViewPrices: canViewFinancials,
                    onClick: () => showDialog(
                      context: context,
                      builder: (_) => ProcessModal(
                          process: process, user: widget.currentUser),
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

  /// Busca en el historial quién ejecutó una acción específica.
  /// Retorna el nombre del usuario o cadena vacía si no se encuentra.
  String _findUserForAction(List<HistoryEntry> history, String detailMatch) {
    try {
      final entry = history.lastWhere(
        (h) => h.details != null && h.details!.contains(detailMatch),
      );
      return entry.userName;
    } catch (_) {
      return '';
    }
  }
}