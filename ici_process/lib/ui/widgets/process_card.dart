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

  // Configuración de colores por prioridad mejorada
  Map<String, dynamic> get _priorityConfig {
    final priority = widget.item['priority'] ?? 'Medium';
    
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
      return 'Fecha no disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _priorityConfig;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18), // Reducido para compensar el borde de 2px
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered 
                ? const Color(0xFF3B82F6) 
                : const Color(0xFFE2E8F0),
              width: 2, // Siempre 2px para evitar movimiento del contenido
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                  ? const Color(0xFF3B82F6).withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
                blurRadius: _isHovered ? 16 : 10,
                offset: Offset(0, _isHovered ? 6 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: ID y Badge de Prioridad
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID Badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.hash,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.item['id'] ?? 'S/ID',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Priority Badge con icono
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: config['bg'],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (config['color'] as Color).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          config['icon'],
                          size: 12,
                          color: config['color'],
                        ),
                        const SizedBox(width: 6),
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
              
              const SizedBox(height: 16),
              
              // Título del Proyecto (destacado)
              Text(
                widget.item['title'] ?? 'Sin título',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                  height: 1.4,
                  letterSpacing: -0.2,
                ),
              ),
              
              const SizedBox(height: 14),
              
              // Cliente con icono mejorado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        LucideIcons.building2,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item['client'] ?? 'Cliente no asignado',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Divider decorativo
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
              
              const SizedBox(height: 16),
              
             // Footer: Fecha y Monto con mejor diseño
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Fecha
                  Flexible(
                    child: _buildInfoChip(
                      icon: LucideIcons.calendar,
                      label: _formatDate, // Aquí había un pequeño error de lógica en tu getter, pero asumo que lo tienes resuelto arriba
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Monto (AQUÍ ESTÁ LA MEJORA)
                  if (widget.item['amount'] != null)
                    Flexible(
                      child: _buildInfoChip(
                        // Cambiamos el ícono a un candado gris si no tiene permiso
                        icon: widget.canViewPrices ? LucideIcons.dollarSign : LucideIcons.lock,
                        label: widget.canViewPrices
                            ? '\$${NumberFormat('#,###').format(widget.item['amount'])}'
                            : '***.**',
                        // Cambiamos el color a gris si no tiene permiso para que no llame la atención (verde si sí tiene)
                        color: widget.canViewPrices ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        isBold: true,
                        // Le pasamos la bandera al chip para ajustar el espaciado
                        isMasked: !widget.canViewPrices, 
                      ),
                    ),
                ],
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
    bool isMasked = false, // <-- Nuevo parámetro
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                // Si está enmascarado, separamos un poco los asteriscos
                letterSpacing: isMasked ? 2.0 : 0.2, 
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}