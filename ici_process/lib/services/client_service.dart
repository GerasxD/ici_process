import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ici_process/models/client_model.dart';

class ClientService {
  // Instancia principal de Firestore (necesaria para Batch y otras colecciones)
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Referencia rápida a la colección 'clientes'
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

  // --- 2. AGREGAR CLIENTE ---
  Future<void> addClient(
    String name, 
    String billingAddress, 
    List<String> branchAddresses
  ) async {
    try {
      print("⏳ Intentando guardar cliente '$name' en Firestore...");
      
      await _clientsRef.add({
        'name': name,
        'billingAddress': billingAddress,
        'branchAddresses': branchAddresses,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print("✅ ¡Cliente y sucursales guardados con éxito!");
    } catch (e) {
      print("❌ Error al guardar en la nube: $e");
      rethrow;
    }
  }

  // --- 3. ACTUALIZAR CLIENTE (CON CASCADA A PROYECTOS) ---
  // Esta función actualiza el cliente y, si cambia el nombre o dirección,
  // actualiza automáticamente todos los proyectos asociados.
  Future<void> updateClient(Client updatedClient) async {
    try {
      print("⏳ Iniciando actualización en cascada para: ${updatedClient.name}...");

      // A. Referencia al documento del cliente
      final DocumentReference clientDocRef = _clientsRef.doc(updatedClient.id);

      // B. Obtenemos los datos VIEJOS antes de sobrescribir
      final DocumentSnapshot oldSnapshot = await clientDocRef.get();
      if (!oldSnapshot.exists) throw Exception("El cliente no existe en la BD");

      final Map<String, dynamic> oldData = oldSnapshot.data() as Map<String, dynamic>;
      final String oldName = oldData['name'] ?? '';
      final String oldBilling = oldData['billingAddress'] ?? '';

      // C. Iniciamos un LOTE (Batch) para hacer todas las escrituras juntas
      WriteBatch batch = _db.batch();

      // D. Agregamos la actualización del Cliente al lote
      batch.update(clientDocRef, {
        'name': updatedClient.name,
        'billingAddress': updatedClient.billingAddress,
        'branchAddresses': updatedClient.branchAddresses,
      });

      // E. Verificamos si hubo cambios críticos (Nombre o Dirección)
      bool nameChanged = oldName != updatedClient.name;
      bool addressChanged = oldBilling != updatedClient.billingAddress;

      if (nameChanged || addressChanged) {
        print("⚠ Detectado cambio crítico. Buscando proyectos de '$oldName'...");

        // F. Buscamos TODOS los proyectos que tengan el nombre VIEJO
        // Asegúrate de que tu colección de proyectos se llame 'projects' en Firestore
        final QuerySnapshot projectsQuery = await _db
            .collection('projects')
            .where('client', isEqualTo: oldName) 
            .get();

        print("found ${projectsQuery.docs.length} proyectos para actualizar.");

        // G. Recorremos esos proyectos y los añadimos al lote
        for (var doc in projectsQuery.docs) {
          Map<String, dynamic> projectUpdates = {};
          
          // Si cambió el nombre, actualizamos el campo 'client' del proyecto
          if (nameChanged) {
            projectUpdates['client'] = updatedClient.name;
          }
          
          // Si cambió la dirección, actualizamos el campo 'billingAddress' del proyecto
          // (Asumiendo que guardas la dirección en el proyecto también)
          if (addressChanged) {
             projectUpdates['billingAddress'] = updatedClient.billingAddress;
          }

          if (projectUpdates.isNotEmpty) {
            batch.update(doc.reference, projectUpdates);
          }
        }
      }

      // H. Ejecutamos todo el lote (Commit)
      await batch.commit();
      
      print("✅ Actualización completa: Cliente y Proyectos sincronizados.");

    } catch (e) {
      print("❌ Error crítico al actualizar cliente: $e");
      rethrow;
    }
  }

  // --- 4. ELIMINAR CLIENTE ---
  Future<void> deleteClient(String id) async {
    try {
      await _clientsRef.doc(id).delete();
      print("✅ Cliente eliminado: $id");
    } catch (e) {
      print("❌ Error al eliminar cliente: $e");
      rethrow;
    }
  }
}