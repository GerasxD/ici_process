import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disabled_day_model.dart';

class DisabledDayService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('disabled_days');

  /// Stream de todos los días deshabilitados
  Stream<List<DisabledDay>> getDisabledDaysStream() {
    return _collection.orderBy('date').snapshots().map((snap) =>
        snap.docs.map((doc) => DisabledDay.fromFirestore(doc)).toList());
  }

  /// Deshabilitar un día
  Future<void> disableDay({
    required DateTime date,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    final id = DisabledDay.idFromDate(date);
    await _collection.doc(id).set(DisabledDay(
      id: id,
      date: DisabledDay.normalizeDate(date),
      reason: reason,
      disabledBy: userId,
      disabledByName: userName,
      createdAt: DateTime.now(),
    ).toMap());
  }

  /// Habilitar (eliminar) un día deshabilitado
  Future<void> enableDay(DateTime date) async {
    final id = DisabledDay.idFromDate(date);
    await _collection.doc(id).delete();
  }

  /// Verificar si un día está deshabilitado
  Future<bool> isDayDisabled(DateTime date) async {
    final id = DisabledDay.idFromDate(date);
    final doc = await _collection.doc(id).get();
    return doc.exists;
  }
}