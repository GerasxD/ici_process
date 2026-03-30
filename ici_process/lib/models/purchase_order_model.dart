// ============================================================
//  MODELO: PurchaseOrder
//  Representa una orden de compra registrada para un material
// ============================================================

class PurchaseOrder {
  final String id;
  final String materialId;
  final String materialName;
  final String unit;
  final String providerName;
  final String providerId;
  final double quantity;        // Cantidad que se compró en esta orden
  final double quotedQuantity;  // Cantidad que estaba cotizada
  final double unitPrice;
  final double totalPrice;
  final DateTime date;
  final String? justification;  // Obligatoria si quantity > quotedQuantity
  final bool hasExcess;         // True si se compró más de lo cotizado

  PurchaseOrder({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.providerName,
    required this.providerId,
    required this.quantity,
    required this.quotedQuantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.date,
    this.justification,
    this.hasExcess = false,
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) => PurchaseOrder(
        id: map['id'] ?? '',
        materialId: map['materialId'] ?? '',
        materialName: map['materialName'] ?? '',
        unit: map['unit'] ?? '',
        providerName: map['providerName'] ?? '',
        providerId: map['providerId'] ?? '',
        quantity: (map['quantity'] ?? 0).toDouble(),
        quotedQuantity: (map['quotedQuantity'] ?? 0).toDouble(),
        unitPrice: (map['unitPrice'] ?? 0).toDouble(),
        totalPrice: (map['totalPrice'] ?? 0).toDouble(),
        date: map['date'] != null
            ? DateTime.tryParse(map['date']) ?? DateTime.now()
            : DateTime.now(),
        justification: map['justification'],
        hasExcess: map['hasExcess'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'materialId': materialId,
        'materialName': materialName,
        'unit': unit,
        'providerName': providerName,
        'providerId': providerId,
        'quantity': quantity,
        'quotedQuantity': quotedQuantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'date': date.toIso8601String(),
        'justification': justification,
        'hasExcess': hasExcess,
      };
}