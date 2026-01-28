import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider_model.dart';

class ProviderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference _providersRef;

  ProviderService() {
    _providersRef = _db.collection('providers'); // Nombre de la colección en Firebase
  }

  // 1. LEER (Stream)
  Stream<List<Provider>> getProviders() {
    return _providersRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Provider.fromFirestore(doc);
      }).toList();
    });
  }

  // 2. CREAR
  Future<void> addProvider(String name, String contactName, String phone, String email) async {
    await _providersRef.add({
      'name': name,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. ACTUALIZAR
  Future<void> updateProvider(Provider provider) async {
    await _providersRef.doc(provider.id).update(provider.toMap());
  }

  // 4. ELIMINAR
  Future<void> deleteProvider(String id) async {
    await _providersRef.doc(id).delete();
  }
}