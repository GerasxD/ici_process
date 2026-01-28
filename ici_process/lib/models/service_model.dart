import 'package:cloud_firestore/cloud_firestore.dart';

// Reutilizamos la lógica de PriceEntry porque es idéntica
class ServicePriceEntry {
  final String providerId;
  final String providerName;
  final double price;
  final DateTime updatedAt;

  ServicePriceEntry({
    required this.providerId,
    required this.providerName,
    required this.price,
    required this.updatedAt,
  });

  factory ServicePriceEntry.fromMap(Map<String, dynamic> map) {
    return ServicePriceEntry(
      providerId: map['providerId']?.toString() ?? '',
      providerName: map['providerName']?.toString() ?? 'Desconocido',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] as double? ?? 0.0),
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'price': price,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class ServiceItem {
  final String id;
  final String name;
  final String unit; // Ej: Hora, Día, Mes, Evento
  final List<ServicePriceEntry> prices;

  ServiceItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.prices,
  });

  factory ServiceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceItem(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? '',
      prices: (data['prices'] as List<dynamic>?)
          ?.map((e) {
            if (e is Map<String, dynamic>) return ServicePriceEntry.fromMap(e);
            if (e is Map) return ServicePriceEntry.fromMap(Map<String, dynamic>.from(e));
            return null;
          })
          .whereType<ServicePriceEntry>()
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'prices': prices.map((e) => e.toMap()).toList(),
    };
  }
}