import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ici_process/models/client_model.dart';

class ClientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late final CollectionReference _clientsRef;

  ClientService() {
    _clientsRef = _db.collection('clientes');
  }

  // --- 1. OBTENER LISTA EN TIEMPO REAL ---
  Stream<List<Client>> getClients() {
    return _clientsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Client.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // --- HELPER: SUBIR LOGO ---
  Future<String> _uploadLogo(Uint8List logoBytes, String clientId) async {
    try {
      final ref = _storage.ref().child('client_logos/$clientId.jpg');
      final uploadTask = await ref.putData(
        logoBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print("❌ Error al subir logo: $e");
      return '';
    }
  }

  // --- HELPER: ELIMINAR LOGO ---
  Future<void> _deleteLogo(String clientId) async {
    try {
      await _storage.ref().child('client_logos/$clientId.jpg').delete();
    } catch (e) {
      // Si no existe, ignoramos
      print("ℹ Logo no existía o no se pudo eliminar: $e");
    }
  }

  // --- 2. AGREGAR CLIENTE ---
  Future<void> addClient({
    required String name,
    required String businessName,
    required String contactName,
    required String phone,
    required String email,
    required String billingAddress,
    required List<String> branchAddresses,
    Uint8List? logoBytes,
  }) async {
    try {
      print("⏳ Guardando cliente '$name'...");

      // 1. Crear el documento primero (sin logo)
      final docRef = await _clientsRef.add({
        'name': name,
        'businessName': businessName,
        'contactName': contactName,
        'phone': phone,
        'email': email,
        'logoUrl': '',
        'billingAddress': billingAddress,
        'branchAddresses': branchAddresses,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Si hay logo, subirlo y actualizar el doc
      if (logoBytes != null) {
        final url = await _uploadLogo(logoBytes, docRef.id);
        if (url.isNotEmpty) {
          await docRef.update({'logoUrl': url});
        }
      }

      print("✅ Cliente guardado con éxito!");
    } catch (e) {
      print("❌ Error al guardar: $e");
      rethrow;
    }
  }

  // Agregar en ClientService, después de getClients()
  Future<Client?> getClientByName(String name) async {
    if (name.trim().isEmpty) return null;
    
    final nameTrimmed = name.trim();

    // 1. Buscar por nombre comercial exacto
    var query = await _clientsRef
        .where('name', isEqualTo: nameTrimmed)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Client.fromMap(
        query.docs.first.data() as Map<String, dynamic>,
        query.docs.first.id,
      );
    }

    // 2. Fallback: buscar por razón social
    query = await _clientsRef
        .where('businessName', isEqualTo: nameTrimmed)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Client.fromMap(
        query.docs.first.data() as Map<String, dynamic>,
        query.docs.first.id,
      );
    }

    return null;
  }

  // --- 3. ACTUALIZAR CLIENTE (CON CASCADA) ---
  Future<void> updateClient(
      Client updatedClient, {
      Uint8List? newLogoBytes,
      bool removeLogo = false,
    }) async {
    try {
      print("⏳ Actualizando: ${updatedClient.name}...");

      final DocumentReference clientDocRef = _clientsRef.doc(updatedClient.id);

      final DocumentSnapshot oldSnapshot = await clientDocRef.get();
      if (!oldSnapshot.exists) throw Exception("Cliente no existe");

      final Map<String, dynamic> oldData = oldSnapshot.data() as Map<String, dynamic>;
      final String oldName = oldData['name'] ?? '';
      final String oldBilling = oldData['billingAddress'] ?? '';

      // Si hay nuevo logo, subirlo
      String logoUrl = updatedClient.logoUrl;
      if (removeLogo) {
        await _deleteLogo(updatedClient.id); // borra de Storage
        logoUrl = '';
      } else if (newLogoBytes != null) {
        logoUrl = await _uploadLogo(newLogoBytes, updatedClient.id);
      }

      WriteBatch batch = _db.batch();

      batch.update(clientDocRef, {
        'name': updatedClient.name,
        'businessName': updatedClient.businessName,
        'contactName': updatedClient.contactName,
        'phone': updatedClient.phone,
        'email': updatedClient.email,
        'logoUrl': logoUrl,
        'billingAddress': updatedClient.billingAddress,
        'branchAddresses': updatedClient.branchAddresses,
      });

      // Cascada a proyectos
      bool nameChanged = oldName != updatedClient.name;
      bool addressChanged = oldBilling != updatedClient.billingAddress;

      if (nameChanged || addressChanged) {
        print("⚠ Cambio crítico detectado. Sincronizando proyectos...");

        final QuerySnapshot projectsQuery = await _db
            .collection('projects')
            .where('client', isEqualTo: oldName)
            .get();

        for (var doc in projectsQuery.docs) {
          Map<String, dynamic> projectUpdates = {};
          if (nameChanged) projectUpdates['client'] = updatedClient.name;
          if (addressChanged) projectUpdates['billingAddress'] = updatedClient.billingAddress;
          if (projectUpdates.isNotEmpty) {
            batch.update(doc.reference, projectUpdates);
          }
        }
      }

      await batch.commit();
      print("✅ Actualización completa.");
    } catch (e) {
      print("❌ Error al actualizar: $e");
      rethrow;
    }
  }

  // --- 4. ELIMINAR CLIENTE ---
  Future<void> deleteClient(String id) async {
    try {
      await _deleteLogo(id); // Eliminar logo de Storage
      await _clientsRef.doc(id).delete();
      print("✅ Cliente eliminado: $id");
    } catch (e) {
      print("❌ Error al eliminar: $e");
      rethrow;
    }
  }
}