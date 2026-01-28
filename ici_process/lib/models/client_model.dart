import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String billingAddress;
  final List<String> branchAddresses;

  Client({
    required this.id, 
    required this.name,
    required this.billingAddress,
    required this.branchAddresses,
  });

  // --- AGREGAR ESTO PARA CORREGIR EL ERROR ---
  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      billingAddress: data['billingAddress'] ?? '',
      branchAddresses: data['branchAddresses'] != null 
          ? List<String>.from(data['branchAddresses']) 
          : [],
    );
  }
  // -------------------------------------------

  // Tu método existente (puedes dejarlo o borrarlo si solo usas fromFirestore)
  factory Client.fromMap(Map<String, dynamic> data, String documentId) {
    return Client(
      id: documentId,
      name: data['name'] ?? '',
      billingAddress: data['billingAddress'] ?? '',
      branchAddresses: data['branchAddresses'] != null 
          ? List<String>.from(data['branchAddresses']) 
          : [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Client &&
      other.id == id; // Comparamos por ID único
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'billingAddress': billingAddress,
      'branchAddresses': branchAddresses,
    };
  }
}