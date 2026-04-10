import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class ProcessCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onClick;
  final bool canViewPrices;

  const ProcessCard({
    super.key,
    required this.item,
    required this.onClick,
    this.canViewPrices = true,
  });

  @override
  State<ProcessCard> createState() => _ProcessCardState();
}

class _ProcessCardState extends State<ProcessCard> {
  bool _isHovered = false;

  Map<String, dynamic> get _priorityConfig {
    final priority = widget.item['priority'] ?? 'Media';
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'urgente':
        return {
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
          'icon': LucideIcons.zap,
          'label': 'URGENTE',
        };
      case 'high':
      case 'alta':
        return {
          'color': const Color(0xFFEA580C),
          'bg': const Color(0xFFFFEDD5),
          'icon': LucideIcons.alertTriangle,
          'label': 'ALTA',
        };
      case 'medium':
      case 'media':
        return {
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFFFEF3C7),
          'icon': LucideIcons.minus,
          'label': 'MEDIA',
        };
      case 'low':
      case 'baja':
        return {
          'color': const Color(0xFF10B981),
          'bg': const Color(0xFFD1FAE5),
          'icon': LucideIcons.arrowDown,
          'label': 'BAJA',
        };
      default:
        return {
          'color': const Color(0xFF64748B),
          'bg': const Color(0xFFF1F5F9),
          'icon': LucideIcons.circle,
          'label': 'NORMAL',
        };
    }
  }

  String get _formatDate {
    try {
      final date = DateTime.parse(widget.item['updatedAt']);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      if (difference == 0) return 'Hoy';
      if (difference == 1) return 'Ayer';
      if (difference < 7) return 'Hace $difference días';
      return DateFormat('d MMM yyyy').format(date);
    } catch (e) {
      return 'Sin fecha';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _priorityConfig;
    final String client = widget.item['client'] ?? 'Cliente no asignado';
    // Soporta tanto 'branch' como 'sucursal' como nombre de campo
    final String? branch = widget.item['branch'] ?? widget.item['sucursal'];
    final bool hasBranch = branch != null && branch.trim().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF3B82F6).withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER con gradiente ─────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ID Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.hash,
                              size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            widget.item['id'] ?? 'S/ID',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF334155),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Priority Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: config['bg'],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (config['color'] as Color).withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(config['icon'],
                              size: 11, color: config['color']),
                          const SizedBox(width: 5),
                          Text(
                            config['label'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: config['color'],
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── CUERPO ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      widget.item['title'] ?? 'Sin título',
                      // Sin maxLines ni overflow → muestra todo el título
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Bloque Cliente + Sucursal ────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFBAE6FD).withOpacity(0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Etiqueta de sección
                          Row(
                            children: const [
                              Icon(LucideIcons.building2,
                                  size: 12, color: Color(0xFF0369A1)),
                              SizedBox(width: 6),
                              Text(
                                'CLIENTE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0369A1),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Nombre del cliente (completo, sin truncar)
                          Text(
                            client,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0C4A6E),
                              height: 1.35,
                            ),
                          ),

                          // Sucursal (si existe)
                          if (hasBranch) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.mapPin,
                                      size: 11, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      branch,
                                      // Sin overflow → muestra la sucursal completa
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0369A1),
                                        height: 1.3,
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

                    const SizedBox(height: 14),

                    // ── Divider ──────────────────────────────
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFE2E8F0).withOpacity(0),
                            const Color(0xFFE2E8F0),
                            const Color(0xFFE2E8F0).withOpacity(0),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Footer: Fecha + Monto ─────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(
                          icon: LucideIcons.clock,
                          label: _formatDate,
                          color: const Color(0xFF64748B),
                        ),
                        if (widget.item['amount'] != null)
                          _buildInfoChip(
                            icon: widget.canViewPrices
                                ? LucideIcons.dollarSign
                                : LucideIcons.lock,
                            label: widget.canViewPrices
                                ? '\$${NumberFormat('#,###').format(widget.item['amount'])}'
                                : '• • •',
                            color: widget.canViewPrices
                                ? const Color(0xFF059669)
                                : const Color(0xFF94A3B8),
                            isBold: true,
                            isMasked: !widget.canViewPrices,
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
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    bool isBold = false,
    bool isMasked = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: isMasked ? 3.0 : 0.2,
            ),
          ),
        ],
      ),
    );
  }
}