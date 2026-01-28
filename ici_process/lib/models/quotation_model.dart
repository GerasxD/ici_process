class QuotationModel {
  double protectionRate; // 0.40 = 40%
  List<QuoteItem> materials;
  List<QuoteItem> indirects;
  List<QuoteItem> specialties;
  List<VehicleQuote> vehicles;
  List<LaborQuote> labor;
  TravelQuote travel;

  QuotationModel({
    this.protectionRate = 0.40,
    List<QuoteItem>? materials,
    List<QuoteItem>? indirects,
    List<QuoteItem>? specialties,
    List<VehicleQuote>? vehicles,
    List<LaborQuote>? labor,
    TravelQuote? travel,
  })  : materials = materials ?? [],
        indirects = indirects ?? [],
        specialties = specialties ?? [],
        vehicles = vehicles ?? [],
        labor = labor ?? [],
        travel = travel ?? TravelQuote();

  // Convertir a Mapa para guardar en Firebase (dentro del Proceso)
  Map<String, dynamic> toMap() {
    return {
      'protectionRate': protectionRate,
      'materials': materials.map((x) => x.toMap()).toList(),
      'indirects': indirects.map((x) => x.toMap()).toList(),
      'specialties': specialties.map((x) => x.toMap()).toList(),
      'vehicles': vehicles.map((x) => x.toMap()).toList(),
      'labor': labor.map((x) => x.toMap()).toList(),
      'travel': travel.toMap(),
    };
  }

  factory QuotationModel.fromMap(Map<String, dynamic> map) {
    return QuotationModel(
      protectionRate: (map['protectionRate'] ?? 0.40).toDouble(),
      materials: List<QuoteItem>.from((map['materials'] ?? []).map((x) => QuoteItem.fromMap(x))),
      indirects: List<QuoteItem>.from((map['indirects'] ?? []).map((x) => QuoteItem.fromMap(x))),
      specialties: List<QuoteItem>.from((map['specialties'] ?? []).map((x) => QuoteItem.fromMap(x))),
      vehicles: List<VehicleQuote>.from((map['vehicles'] ?? []).map((x) => VehicleQuote.fromMap(x))),
      labor: List<LaborQuote>.from((map['labor'] ?? []).map((x) => LaborQuote.fromMap(x))),
      travel: map['travel'] != null ? TravelQuote.fromMap(map['travel']) : TravelQuote(),
    );
  }
}

class QuoteItem {
  String id;
  String name;
  double quantity;
  double unitPrice;

  QuoteItem({required this.id, this.name = '', this.quantity = 1, this.unitPrice = 0});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'quantity': quantity, 'unitPrice': unitPrice};
  
  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 1).toDouble(),
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
    );
  }
}

class VehicleQuote {
  String id;
  String vehicleId; // ID del catálogo de vehículos
  double days;
  double distance;
  double tolls;

  VehicleQuote({required this.id, this.vehicleId = '', this.days = 1, this.distance = 100, this.tolls = 0});

  Map<String, dynamic> toMap() => {'id': id, 'vehicleId': vehicleId, 'days': days, 'distance': distance, 'tolls': tolls};

  factory VehicleQuote.fromMap(Map<String, dynamic> map) {
    return VehicleQuote(
      id: map['id'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      days: (map['days'] ?? 1).toDouble(),
      distance: (map['distance'] ?? 100).toDouble(),
      tolls: (map['tolls'] ?? 0).toDouble(),
    );
  }
}

class LaborQuote {
  String id;
  String categoryId; // ID del catálogo de puestos
  double quantity;
  double days;

  LaborQuote({required this.id, this.categoryId = '', this.quantity = 1, this.days = 1});

  Map<String, dynamic> toMap() => {'id': id, 'categoryId': categoryId, 'quantity': quantity, 'days': days};

  factory LaborQuote.fromMap(Map<String, dynamic> map) {
    return LaborQuote(
      id: map['id'] ?? '',
      categoryId: map['categoryId'] ?? '',
      quantity: (map['quantity'] ?? 1).toDouble(),
      days: (map['days'] ?? 1).toDouble(),
    );
  }
}

class TravelQuote {
  bool enabled;
  double foodCostPerDay;
  double lodgingCostPerDay;
  double peopleCount;
  double days;

  TravelQuote({this.enabled = false, this.foodCostPerDay = 250, this.lodgingCostPerDay = 750, this.peopleCount = 0, this.days = 0});

  Map<String, dynamic> toMap() => {'enabled': enabled, 'foodCostPerDay': foodCostPerDay, 'lodgingCostPerDay': lodgingCostPerDay, 'peopleCount': peopleCount, 'days': days};

  factory TravelQuote.fromMap(Map<String, dynamic> map) {
    return TravelQuote(
      enabled: map['enabled'] ?? false,
      foodCostPerDay: (map['foodCostPerDay'] ?? 250).toDouble(),
      lodgingCostPerDay: (map['lodgingCostPerDay'] ?? 750).toDouble(),
      peopleCount: (map['peopleCount'] ?? 0).toDouble(),
      days: (map['days'] ?? 0).toDouble(),
    );
  }
}