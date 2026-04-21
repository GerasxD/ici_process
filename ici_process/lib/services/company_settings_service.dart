import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_settings_model.dart';

class CompanySettingsService {
  final DocumentReference _docRef =
      FirebaseFirestore.instance.collection('settings').doc('company_profile');

  /// Obtener configuración una sola vez (Future)
  Future<CompanySettingsModel> getSettings() async {
    final doc = await _docRef.get();
    if (doc.exists && doc.data() != null) {
      return CompanySettingsModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return CompanySettingsModel();
  }

  /// Obtener configuración en tiempo real (Stream)
  /// Útil si quieres reflejar cambios al instante en otras pantallas
  Stream<CompanySettingsModel> getSettingsStream() {
    return _docRef.snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CompanySettingsModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return CompanySettingsModel();
    });
  }

  /// Guardar configuración (con merge para no sobreescribir campos futuros)
  Future<void> saveSettings(CompanySettingsModel settings) async {
    await _docRef.set(settings.toMap(), SetOptions(merge: true));
  }

  /// Eliminar solo el logo (por si quieres agregar esa opción luego)
  Future<void> removeLogo() async {
    await _docRef.update({'logoUrl': ''});
  }
}