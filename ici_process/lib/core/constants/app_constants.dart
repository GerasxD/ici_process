import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum UserRole { superAdmin, admin, accountant, purchasing, manager, technician }

enum ProcessStage { E1, E2, E2A, E3, E4, E5, E6, E7, E8, X }

class StageConfig {
  final String title;
  final Color color;
  final Color textColor;
  final IconData icon;
  final List<UserRole> visibility;
  final List<UserRole> editing;

  const StageConfig({
    required this.title,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.visibility,
    required this.editing,
  });
}

// Configuración Maestra de Etapas (Copia fiel de tu lógica React)
final Map<ProcessStage, StageConfig> stageConfigs = {
  ProcessStage.E1: const StageConfig(
    title: 'E1 - Solicitud Cotización',
    color: Color(0xFFF3F4F6),
    textColor: Color(0xFF374151),
    icon: LucideIcons.fileText,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.manager],
  ),
  ProcessStage.E2: const StageConfig(
    title: 'E2 - Cotizando',
    color: Color(0xFFE0F2FE),
    textColor: Color(0xFF0369A1),
    icon: LucideIcons.penTool,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.purchasing],
  ),
  ProcessStage.E2A: const StageConfig(
    title: 'E2A - Espera Autorización',
    color: Color(0xFFF3E8FF),
    textColor: Color(0xFF7E22CE),
    icon: LucideIcons.fileCheck,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.manager],
  ),
  ProcessStage.E3: const StageConfig(
    title: 'E3 - Cotización Enviada',
    color: Color(0xFFDBEAFE),
    textColor: Color(0xFF1D4ED8),
    icon: LucideIcons.send,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.manager],
  ),
  ProcessStage.E4: const StageConfig(
    title: 'E4 - O.C. Sin Atender',
    color: Color(0xFFE0E7FF),
    textColor: Color(0xFF4338CA),
    icon: LucideIcons.shoppingCart,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.purchasing],
  ),
  ProcessStage.E5: const StageConfig(
    title: 'E5 - Logística',
    color: Color(0xFFFEF3C7),
    textColor: Color(0xFFB45309),
    icon: LucideIcons.truck,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.purchasing],
  ),
  ProcessStage.E6: const StageConfig(
    title: 'E6 - En Ejecución',
    color: Color(0xFFFFEDD5),
    textColor: Color(0xFFC2410C),
    icon: LucideIcons.wrench,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.manager, UserRole.technician],
  ),
  ProcessStage.E7: const StageConfig(
    title: 'E7 - Reporte y Factura',
    color: Color(0xFFCCFBF1),
    textColor: Color(0xFF0F766E),
    icon: LucideIcons.dollarSign,
    visibility: [UserRole.superAdmin, UserRole.admin, UserRole.accountant, UserRole.manager],
    editing: [UserRole.superAdmin, UserRole.admin, UserRole.accountant],
  ),
  ProcessStage.E8: const StageConfig(
    title: 'E8 - Finalizado',
    color: Color(0xFFD1FAE5),
    textColor: Color(0xFF047857),
    icon: LucideIcons.checkCircle,
    visibility: UserRole.values,
    editing: [UserRole.superAdmin, UserRole.admin],
  ),
  ProcessStage.X: const StageConfig(
    title: 'X - Descartado',
    color: Color(0xFFE2E8F0),
    textColor: Color(0xFF64748B),
    icon: LucideIcons.xCircle,
    visibility: [UserRole.superAdmin, UserRole.admin, UserRole.manager],
    editing: [UserRole.superAdmin, UserRole.admin],
  ),
};