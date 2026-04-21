import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// IDs de los roles base del sistema. Se migran a Firestore vía RoleService.
// Estos strings se siguen usando como referencia en los valores por defecto
// de `visibility` y `editing` de cada etapa del proceso.
class SystemRoles {
  static const String superAdmin = 'superAdmin';
  static const String admin = 'admin';
  static const String accountant = 'accountant';
  static const String purchasing = 'purchasing';
  static const String manager = 'manager';
  static const String technician = 'technician';

  static const List<String> all = [
    superAdmin,
    admin,
    accountant,
    purchasing,
    manager,
    technician,
  ];
}

enum ProcessStage { E1, E2, E2A, E3, E4, E5, E6, E7, E8, X }

class StageConfig {
  final String title;
  final Color color;
  final Color textColor;
  final IconData icon;
  final List<String> visibility;
  final List<String> editing;

  const StageConfig({
    required this.title,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.visibility,
    required this.editing,
  });
}

// Configuración Maestra de Etapas
final Map<ProcessStage, StageConfig> stageConfigs = {
  ProcessStage.E1: const StageConfig(
    title: 'E1 - Solicitud Cotización',
    color: Color(0xFFF3F4F6),
    textColor: Color(0xFF374151),
    icon: LucideIcons.fileText,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.manager],
  ),
  ProcessStage.E2: const StageConfig(
    title: 'E2 - Cotizando',
    color: Color(0xFFE0F2FE),
    textColor: Color(0xFF0369A1),
    icon: LucideIcons.penTool,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.manager, SystemRoles.purchasing],
  ),
  ProcessStage.E2A: const StageConfig(
    title: 'E2A - Espera Autorización',
    color: Color(0xFFF3E8FF),
    textColor: Color(0xFF7E22CE),
    icon: LucideIcons.fileCheck,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.manager],
  ),
  ProcessStage.E3: const StageConfig(
    title: 'E3 - Cotización Enviada',
    color: Color(0xFFDBEAFE),
    textColor: Color(0xFF1D4ED8),
    icon: LucideIcons.send,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.manager],
  ),
  ProcessStage.E4: const StageConfig(
    title: 'E4 - O.C. Sin Atender',
    color: Color(0xFFE0E7FF),
    textColor: Color(0xFF4338CA),
    icon: LucideIcons.shoppingCart,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.purchasing],
  ),
  ProcessStage.E5: const StageConfig(
    title: 'E5 - Logística',
    color: Color(0xFFFEF3C7),
    textColor: Color(0xFFB45309),
    icon: LucideIcons.truck,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.purchasing],
  ),
  ProcessStage.E6: const StageConfig(
    title: 'E6 - En Ejecución',
    color: Color(0xFFFFEDD5),
    textColor: Color(0xFFC2410C),
    icon: LucideIcons.wrench,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.manager, SystemRoles.technician],
  ),
  ProcessStage.E7: const StageConfig(
    title: 'E7 - Reporte y Factura',
    color: Color(0xFFCCFBF1),
    textColor: Color(0xFF0F766E),
    icon: LucideIcons.dollarSign,
    visibility: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.accountant, SystemRoles.manager],
    editing: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.accountant],
  ),
  ProcessStage.E8: const StageConfig(
    title: 'E8 - Finalizado',
    color: Color(0xFFD1FAE5),
    textColor: Color(0xFF047857),
    icon: LucideIcons.checkCircle,
    visibility: SystemRoles.all,
    editing: [SystemRoles.superAdmin, SystemRoles.admin],
  ),
  ProcessStage.X: const StageConfig(
    title: 'X - Descartado',
    color: Color(0xFFE2E8F0),
    textColor: Color(0xFF64748B),
    icon: LucideIcons.xCircle,
    visibility: [SystemRoles.superAdmin, SystemRoles.admin, SystemRoles.manager],
    editing: [SystemRoles.superAdmin, SystemRoles.admin],
  ),
};
