import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/models/event_model.dart';
import 'package:ici_process/services/event_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';


class EventDetailDialog extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback? onFinalized;

  const EventDetailDialog({
    super.key,
    required this.event,
    required this.onEdit,
    this.onFinalized,
  });

  @override
  Widget build(BuildContext context) {
    final color = event.color;
    final dateRange = _buildDateRange();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────
            _buildHeader(context, color),

            // ── Divider ───────────────────────────────────
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // ── Cuerpo ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fechas
                  _buildInfoRow(
                    icon: LucideIcons.calendar,
                    label: "Fecha",
                    value: dateRange,
                  ),

                  const SizedBox(height: 16),

                  // Ubicación / Cliente
                  _buildInfoRow(
                    icon: LucideIcons.mapPin,
                    label: "Ubicación",
                    value: event.clientName.isNotEmpty
                        ? event.clientName
                        : "Sin dirección registrada",
                    valueColor: event.clientName.isEmpty
                        ? const Color(0xFFCBD5E1)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Contacto
                  _buildInfoRow(
                    icon: LucideIcons.phone,
                    label: "Contacto Sitio",
                    value: _contactText(),
                    valueColor: _contactText() == "Sin contacto registrado"
                        ? const Color(0xFFCBD5E1)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Vehículo
                  _buildVehicleRow(),

                  const SizedBox(height: 16),

                  // Personal asignado
                  _buildPersonnelRow(color),
                ],
              ),
            ),

            // ── Divider ───────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 24, color: Color(0xFFF1F5F9)),
            ),

            // ── Footer ────────────────────────────────────
            _buildFooter(context, color),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Cliente subtitle
                    if (event.clientName.isNotEmpty) ...[
                      Text(
                        event.clientName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Tipo badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.type.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: event.type.color.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(event.type.icon,
                              size: 11, color: event.type.color),
                          const SizedBox(width: 5),
                          Text(
                            event.type.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: event.type.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botón editar (lápiz)
          _headerIconButton(
            icon: LucideIcons.pencil,
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          const SizedBox(width: 4),
          // Botón cerrar (X)
          _headerIconButton(
            icon: LucideIcons.x,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
      ),
    );
  }

  // ── INFO ROW ──────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: valueColor ?? const Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── VEHICLE ROW ───────────────────────────────────────────
  Widget _buildVehicleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.truck,
              size: 16, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Vehículos Asignados",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              event.vehicleModel != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        event.vehicleModel!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    )
                  : Text(
                      "Sin vehículo asignado",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PERSONNEL ROW ─────────────────────────────────────────
  Widget _buildPersonnelRow(Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.users,
              size: 16, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personal Asignado",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              event.technicianNames.isEmpty
                  ? Text(
                      "Sin personal asignado",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFCBD5E1),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: event.technicianNames
                          .map((name) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ── FOOTER ────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context, Color color) {
    final isToday = _coversToday();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text(
                  "¿Finalizar servicio?",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                content: Text(
                  "Se registrará como finalizado el día de hoy. Esta acción no se puede deshacer.",
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF64748B)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text("Cancelar",
                        style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text("Finalizar",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );

            if (confirm == true && context.mounted) {
              try {
                await EventService().finalizeEvent(event.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  onFinalized?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Servicio finalizado correctamente",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(LucideIcons.checkCircle2, size: 18),
          label: Text(
            isToday ? "Finalizar Servicio (Hoy)" : "Finalizar Servicio",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────
  String _buildDateRange() {
    final fmt = DateFormat('dd/MM/yyyy');
    final start = fmt.format(event.startDate);
    final end = fmt.format(event.endDate);
    return start == end ? start : "$start  →  $end";
  }

  String _contactText() {
    final name = event.contactName.trim();
    final phone = event.contactPhone.trim();
    if (name.isEmpty && phone.isEmpty) return "Sin contacto registrado";
    if (name.isNotEmpty && phone.isNotEmpty) return "$name - $phone";
    return name.isNotEmpty ? name : phone;
  }

  bool _coversToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
        event.startDate.year, event.startDate.month, event.startDate.day);
    final end = DateTime(
        event.endDate.year, event.endDate.month, event.endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }
}