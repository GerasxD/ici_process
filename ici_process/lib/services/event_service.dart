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

  // ── CREAR ───────────────────────────────────────────────
  Future<void> createEvent(CalendarEvent event) async {
    await _ref.add(event.toMap());
  }

  // ── ACTUALIZAR ──────────────────────────────────────────
  Future<void> updateEvent(CalendarEvent event) async {
    await _ref.doc(event.id).update(event.toMap());
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

}