// --- Modelo para Categorías de Salarios (Labor) ---
class LaborCategory {
  final String id;
  final String name;
  final double baseDailySalary;

  LaborCategory({required this.id, required this.name, required this.baseDailySalary});

  factory LaborCategory.fromMap(Map<String, dynamic> map) {
    return LaborCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      baseDailySalary: (map['baseDailySalary'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'baseDailySalary': baseDailySalary,
  };
}

// --- Modelo para Configuración de Etapas ---
class StageConfig {
  final String stageId;
  final List<String> visibleToRoles; // Roles que pueden ver
  final List<String> editableByRoles; // Roles que pueden editar

  StageConfig({required this.stageId, required this.visibleToRoles, required this.editableByRoles});

  factory StageConfig.fromMap(Map<String, dynamic> map) {
    return StageConfig(
      stageId: map['stageId'] ?? '',
      visibleToRoles: List<String>.from(map['visibleToRoles'] ?? []),
      editableByRoles: List<String>.from(map['editableByRoles'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'stageId': stageId,
    'visibleToRoles': visibleToRoles,
    'editableByRoles': editableByRoles,
  };
}