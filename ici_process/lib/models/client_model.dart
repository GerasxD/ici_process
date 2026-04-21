import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String businessName;      // Razón social
  final String contactName;       // Nombre de contacto
  final String phone;             // Teléfono
  final String email;             // Correo
  final String logoUrl;           // URL del logo en Firebase Storage
  final String billingAddress;
  final List<String> branchAddresses;

  Client({
    required this.id,
    required this.name,
    this.businessName = '',
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.logoUrl = '',
    required this.billingAddress,
    required this.branchAddresses,
  });

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      businessName: data['businessName'] ?? '',
      contactName: data['contactName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      billingAddress: data['billingAddress'] ?? '',
      branchAddresses: data['branchAddresses'] != null
          ? List<String>.from(data['branchAddresses'])
          : [],
    );
  }

  factory Client.fromMap(Map<String, dynamic> data, String documentId) {
    return Client(
      id: documentId,
      name: data['name'] ?? '',
      businessName: data['businessName'] ?? '',
      contactName: data['contactName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      billingAddress: data['billingAddress'] ?? '',
      branchAddresses: data['branchAddresses'] != null
          ? List<String>.from(data['branchAddresses'])
          : [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'businessName': businessName,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'logoUrl': logoUrl,
      'billingAddress': billingAddress,
      'branchAddresses': branchAddresses,
    };
  }
}