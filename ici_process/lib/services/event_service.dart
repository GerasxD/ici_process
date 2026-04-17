import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference _ref;

  EventService() {
    _ref = _db.collection('calendar_events');
  }

  // ── LEER (stream en tiempo real) ────────────────────────
  Stream<List<CalendarEvent>> getEventsStream() {
    return _ref
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                CalendarEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // ── LEER FILTRADO POR USUARIO ───────────────────────────
  /// Devuelve eventos visibles para el usuario según su rol y privacidad.
  /// Admins/Superadmins ven todo. Otros usuarios ven eventos públicos
  /// y los privados donde están incluidos en visibleToUserIds.
  Stream<List<CalendarEvent>> getEventsStreamForUser({
    required String userId,
    required String userRole,
  }) {
    return getEventsStream().map((events) {
      return events.where((e) => e.isVisibleTo(userId, userRole)).toList();
    });
  }

  // ── CREAR ───────────────────────────────────────────────
  Future<String> createEvent(CalendarEvent event) async {
    // Al usar .add(), Firebase nos devuelve la referencia del nuevo documento
    final docRef = await _ref.add(event.toMap());
    
    // Retornamos el ID que Firebase generó automáticamente
    return docRef.id; 
  }

  // ── ACTUALIZAR ──────────────────────────────────────────
  Future<void> updateEvent(CalendarEvent event) async {
    await _ref.doc(event.id).set(event.toMap(), SetOptions(merge: true));
  }

  // ── ELIMINAR ────────────────────────────────────────────
  Future<void> deleteEvent(String id) async {
    await _ref.doc(id).delete();
  }

  Future<void> finalizeEvent(String id) async {
    await _ref.doc(id).update({
      'finalizedAt': FieldValue.serverTimestamp(),
      'isFinalized': true,
    });
  }

  // ── OBTENER DOCUMENTO RAW (para verificar finalización) ──
  Future<Map<String, dynamic>?> getEventDoc(String id) async {
    try {
      final doc = await _ref.doc(id).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

}