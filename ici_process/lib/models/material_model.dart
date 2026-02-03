import 'package:cloud_firestore/cloud_firestore.dart';

// --- CLASE AUXILIAR PARA EL PRECIO (Sin cambios) ---
class PriceEntry {
  final String providerId;
  final String providerName;
  final double price;
  final DateTime updatedAt;

  PriceEntry({
    required this.providerId,
    required this.providerName,
    required this.price,
    required this.updatedAt,
  });

  // Leer de Firebase
  factory PriceEntry.fromMap(Map<String, dynamic> map) {
    return PriceEntry(
      providerId: map['providerId'] ?? '',
      providerName: map['providerName'] ?? 'Desconocido',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] as double? ?? 0.0),
      updatedAt: (map['updatedAt'] is Timestamp) 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convertir a Mapa para Firebase
  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'price': price,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// --- CLASE PRINCIPAL DEL MATERIAL ---
class MaterialItem {
  final String id;
  final String name;
  final String unit;
  final double stock; // <--- 1. NUEVO CAMPO: STOCK
  final List<PriceEntry> prices;

  MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    this.stock = 0.0, // <--- 2. INICIALIZAR EN EL CONSTRUCTOR (Por defecto 0.0)
    required this.prices,
  });

  // Leer de Firebase
  factory MaterialItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialItem(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? '',
      
      // <--- 3. LEER STOCK DE FORMA SEGURA ---
      // Si viene como int lo convierte a double, si es null pone 0.0
      stock: (data['stock'] is int) 
          ? (data['stock'] as int).toDouble() 
          : (data['stock'] as double? ?? 0.0),
      // --------------------------------------

      prices: (data['prices'] as List<dynamic>?)
          ?.map((e) => PriceEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // Guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'stock': stock, // <--- 4. GUARDAR STOCK
      'prices': prices.map((price) => price.toMap()).toList(), 
    };
  }
}