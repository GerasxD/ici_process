import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tool_model.dart';

class ToolService {
  final CollectionReference _toolsRef = FirebaseFirestore.instance.collection('tools');

  // Obtener flujo de herramientas
  Stream<List<ToolItem>> getTools() {
    return _toolsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ToolItem.fromFirestore(doc)).toList();
    });
  }

  // Agregar
  Future<void> addTool(ToolItem tool) async {
    await _toolsRef.add(tool.toMap());
  }

  // Actualizar
  Future<void> updateTool(ToolItem tool) async {
    await _toolsRef.doc(tool.id).update(tool.toMap());
  }

  // Eliminar
  Future<void> deleteTool(String id) async {
    await _toolsRef.doc(id).delete();
  }
}