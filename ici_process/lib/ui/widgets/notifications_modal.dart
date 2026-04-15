// lib/ui/widgets/notifications_modal.dart
//
// ╔══════════════════════════════════════════════════════════════╗
// ║  PANEL DE NOTIFICACIONES — Diseño profesional               ║
// ║  - Tipos de notificación con iconos y colores específicos   ║
// ║  - Clic para navegar al proceso                             ║
// ║  - Marcar todas como leídas                                 ║
// ║  - Agrupación Nuevas / Anteriores                           ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/user_model.dart';
import '../../services/process_service.dart';
import '../widgets/process_modal/process_modal.dart';

// ════════════════════════════════════════════════════════════════
//  CONFIGURACIÓN DE TIPOS DE NOTIFICACIÓN
// ════════════════════════════════════════════════════════════════

class _NotifConfig {
  final IconData icon;
  final Color color;
  final String defaultTitle;

  const _NotifConfig({
    required this.icon,
    required this.color,
    required this.defaultTitle,
  });
}

const Map<String, _NotifConfig> _notifTypes = {
  'mention': _NotifConfig(
    icon: LucideIcons.atSign,
    color: Color(0xFF2563EB),
    defaultTitle: 'Te mencionaron',
  ),
  'oc_received': _NotifConfig(
    icon: LucideIcons.shoppingBag,
    color: Color(0xFF7C3AED),
    defaultTitle: 'O.C. Recibida',
  ),
  'stage_advance': _NotifConfig(
    icon: LucideIcons.arrowRightCircle,
    color: Color(0xFF059669),
    defaultTitle: 'Proceso Avanzó',
  ),
  'stage_regress': _NotifConfig(
    icon: LucideIcons.arrowLeftCircle,
    color: Color(0xFFEA580C),
    defaultTitle: 'Proceso Retrocedió',
  ),
  'process_created': _NotifConfig(
    icon: LucideIcons.plusCircle,
    color: Color(0xFF0891B2),
    defaultTitle: 'Nuevo Proceso',
  ),
  'process_discarded': _NotifConfig(
    icon: LucideIcons.archive,
    color: Color(0xFF64748B),
    defaultTitle: 'Proceso Descartado',
  ),
  'execution_started': _NotifConfig(
    icon: LucideIcons.hardHat,
    color: Color(0xFFC2410C),
    defaultTitle: 'Ejecución Iniciada',
  ),
  'invoice_pending': _NotifConfig(
    icon: LucideIcons.receipt,
    color: Color(0xFF16A34A),
    defaultTitle: 'Factura Pendiente',
  ),
};

_NotifConfig _resolveConfig(String? type) =>
    _notifTypes[type] ??
    const _NotifConfig(
      icon: LucideIcons.bell,
      color: Color(0xFF475569),
      defaultTitle: 'Notificación',
    );

// ════════════════════════════════════════════════════════════════
//  HELPER — Tiempo relativo legible
// ════════════════════════════════════════════════════════════════

String _relativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inSeconds < 60) return 'Hace un momento';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'Ayer · ${DateFormat('HH:mm').format(date)}';
  if (diff.inDays < 7) {
    return '${DateFormat('EEEE', 'es').format(date)} · ${DateFormat('HH:mm').format(date)}';
  }
  return DateFormat('dd MMM, HH:mm', 'es').format(date);
}

// ════════════════════════════════════════════════════════════════
//  WIDGET PRINCIPAL
// ════════════════════════════════════════════════════════════════

class NotificationsModal extends StatelessWidget {
  final UserModel currentUser;

  const NotificationsModal({super.key, required this.currentUser});

  // ── Marcar TODAS como leídas ──────────────────────────────
  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!(data['read'] ?? false)) {
        batch.update(doc.reference, {'read': true});
      }
    }
    await batch.commit();
  }

  // ── Marcar una como leída y navegar ──────────────────────
  Future<void> _handleTap(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final processId = data['processId'] as String? ?? '';

    // 1. Marcar como leída
    if (!(data['read'] ?? false)) {
      await doc.reference.update({'read': true});
    }

    if (processId.isEmpty) return;

    // ⭐ EL SECRETO: Capturamos el contexto de la app ANTES de cerrar el panel
    final parentContext = Navigator.of(context, rootNavigator: true).context;

    // 2. Cerramos el panel de notificaciones
    Navigator.of(context, rootNavigator: true).pop();

    try {
      // 3. Buscamos el proceso en Firebase
      final process = await ProcessService().getProcessById(processId);
      
      if (process == null) return;
      
      // 4. Verificamos que el contexto padre siga vivo
      if (!parentContext.mounted) return;

      // 5. Abrimos el ProcessModal usando el contexto que guardamos
      await showDialog(
        context: parentContext, // <-- ¡Usamos parentContext, no context!
        builder: (_) => ProcessModal(
          process: process,
          user: currentUser,
        ),
      );
    } catch (e) {
      print("Error al abrir el proceso: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('targetUserId', isEqualTo: currentUser.id)
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final unread = docs
              .where((d) =>
                  !((d.data() as Map<String, dynamic>)['read'] ?? false))
              .toList();
          final hasUnread = unread.isNotEmpty;

          return Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, docs, hasUnread),
                  Flexible(child: _buildBody(context, docs, snapshot)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    bool hasUnread,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Row(
        children: [
          // Ícono con puntito animado
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.bellRing,
                    color: Colors.white, size: 20),
              ),
              if (hasUnread)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0F172A), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notificaciones",
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                if (hasUnread)
                  Text(
                    "${docs.where((d) => !((d.data() as Map)['read'] ?? false)).length} sin leer",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    "Todo al día",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
          // Marcar todas como leídas
          if (hasUnread)
            Tooltip(
              message: "Marcar todas como leídas",
              child: InkWell(
                onTap: () => _markAllRead(docs),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.checkCheck,
                          size: 13, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(
                        "Leer todo",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Cerrar
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child:
                  Icon(LucideIcons.x, size: 18, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  // ── BODY ──────────────────────────────────────────────────
  Widget _buildBody(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    AsyncSnapshot<QuerySnapshot> snapshot,
  ) {
    // Estado de error
    if (snapshot.hasError) {
      return _buildEmptyState(
        icon: LucideIcons.wifiOff,
        iconColor: const Color(0xFFEF4444),
        title: "Error de conexión",
        subtitle: "No se pudieron cargar las notificaciones",
      );
    }

    // Estado de carga
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2563EB),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Estado vacío
    if (docs.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.bellOff,
        iconColor: const Color(0xFFCBD5E1),
        title: "Sin notificaciones",
        subtitle: "Cuando recibas notificaciones, aparecerán aquí",
      );
    }

    // Separar no leídas / leídas
    final unread = docs
        .where((d) =>
            !((d.data() as Map<String, dynamic>)['read'] ?? false))
        .toList();
    final read = docs
        .where((d) =>
            ((d.data() as Map<String, dynamic>)['read'] ?? false))
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (unread.isNotEmpty) ...[
          _buildSectionLabel("NUEVAS"),
          ...unread.map((doc) =>
              _buildNotifTile(context, doc, isRead: false)),
          if (read.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                  color: const Color(0xFFE2E8F0), height: 24),
            ),
        ],
        if (read.isNotEmpty) ...[
          if (unread.isNotEmpty) _buildSectionLabel("ANTERIORES"),
          ...read.map((doc) =>
              _buildNotifTile(context, doc, isRead: true)),
        ],
      ],
    );
  }

  // ── LABEL DE SECCIÓN ─────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── TILE DE NOTIFICACIÓN ──────────────────────────────────
  Widget _buildNotifTile(
    BuildContext context,
    QueryDocumentSnapshot doc, {
    required bool isRead,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? '';
    final config = _resolveConfig(type);
    final title = data['title'] as String? ?? config.defaultTitle;
    final body = data['body'] as String? ?? '';
    final processId = data['processId'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? '';
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final hasProcess = processId.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleTap(context, doc),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isRead ? Colors.white : config.color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead
                    ? const Color(0xFFF1F5F9)
                    : config.color.withOpacity(0.18),
                width: isRead ? 1 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ícono ─────────────────────────────────
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isRead
                        ? config.color.withOpacity(0.08)
                        : config.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(config.icon,
                      size: 18,
                      color: isRead
                          ? config.color.withOpacity(0.7)
                          : config.color),
                ),
                const SizedBox(width: 12),

                // ── Contenido ──────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título + puntito
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _cleanTitle(title),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: isRead
                                    ? const Color(0xFF334155)
                                    : const Color(0xFF0F172A),
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: config.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Cuerpo del mensaje
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _cleanBody(body),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isRead
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Footer: sender + tiempo + ir al proceso
                      Row(
                        children: [
                          if (senderName.isNotEmpty) ...[
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: config.color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  senderName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: config.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              senderName,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              " · ",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              _relativeTime(date),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          if (hasProcess)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Ver proceso",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: config.color,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(LucideIcons.arrowRight,
                                    size: 11, color: config.color),
                              ],
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
      ),
    );
  }

  // ── ESTADO VACÍO ──────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FORMATEO PROFESIONAL DE MENSAJES
  // ════════════════════════════════════════════════════════════

  /// Limpia emojis de prefijo del título
  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'^[💬📌🔔✅⚠️📦🧾🚀💼]+\s*'), '')
        .trim();
  }

  /// Hace el cuerpo más conciso y profesional
  String _cleanBody(String raw) {
    return raw.trim();
  }
}

// ════════════════════════════════════════════════════════════════
//  HELPER ESTÁTICO — Crear notificaciones con mensajes
//  profesionales desde cualquier parte de la app.
//  Uso: NotificationHelper.send(...)
// ════════════════════════════════════════════════════════════════

class NotificationHelper {
  NotificationHelper._();

  static final _col = FirebaseFirestore.instance.collection('notifications');

  /// Envía una notificación a uno o varios usuarios.
  static Future<void> send({
    required List<String> targetUserIds,
    required String type,
    required String title,
    required String body,
    required String senderName,
    String processId = '',
  }) async {
    if (targetUserIds.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final uid in targetUserIds) {
      batch.set(_col.doc(), {
        'targetUserId': uid,
        'type': type,
        'title': title,
        'body': body,
        'senderName': senderName,
        'processId': processId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ── Fábricas con mensajes estándar ─────────────────────────

  static Future<void> mention({
    required List<String> targetUserIds,
    required String senderName,
    required String processTitle,
    required String processId,
  }) =>
      send(
        targetUserIds: targetUserIds,
        type: 'mention',
        title: 'Mención en comentario',
        body: '$senderName te mencionó en "$processTitle".',
        senderName: senderName,
        processId: processId,
      );

  static Future<void> ocReceived({
    required List<String> targetUserIds,
    required String senderName,
    required String processTitle,
    required String processId,
    String? ocNumber,
  }) =>
      send(
        targetUserIds: targetUserIds,
        type: 'oc_received',
        title: 'Orden de Compra Recibida',
        body: ocNumber != null && ocNumber.isNotEmpty
            ? 'O.C. $ocNumber recibida para el proyecto "$processTitle".'
            : 'Orden de compra registrada en el proyecto "$processTitle".',
        senderName: senderName,
        processId: processId,
      );

  static Future<void> stageAdvance({
    required List<String> targetUserIds,
    required String senderName,
    required String processTitle,
    required String processId,
    required String fromStage,
    required String toStage,
  }) =>
      send(
        targetUserIds: targetUserIds,
        type: 'stage_advance',
        title: 'Proceso Avanzó de Etapa',
        body: '"$processTitle" avanzó de $fromStage a $toStage.',
        senderName: senderName,
        processId: processId,
      );

  static Future<void> stageRegress({
    required List<String> targetUserIds,
    required String senderName,
    required String processTitle,
    required String processId,
    required String fromStage,
    required String toStage,
    String reason = '',
  }) =>
      send(
        targetUserIds: targetUserIds,
        type: 'stage_regress',
        title: 'Proceso Regresó de Etapa',
        body: reason.isNotEmpty
            ? '"$processTitle" regresó de $fromStage a $toStage. Motivo: $reason'
            : '"$processTitle" regresó de $fromStage a $toStage.',
        senderName: senderName,
        processId: processId,
      );

  static Future<void> executionStarted({
    required List<String> targetUserIds,
    required String senderName,
    required String processTitle,
    required String processId,
    required List<String> technicianNames,
  }) =>
      send(
        targetUserIds: targetUserIds,
        type: 'execution_started',
        title: 'Ejecución Programada',
        body: technicianNames.isNotEmpty
            ? '"$processTitle" fue agendado. Equipo: ${technicianNames.join(', ')}.'
            : '"$processTitle" fue agendado para ejecución en sitio.',
        senderName: senderName,
        processId: processId,
      );
}