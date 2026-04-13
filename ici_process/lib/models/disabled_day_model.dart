import 'package:cloud_firestore/cloud_firestore.dart';

class DisabledDay {
  final String id;
  final DateTime date;
  final String reason;
  final String disabledBy; // uid del admin
  final String disabledByName;
  final DateTime createdAt;

  DisabledDay({
    required this.id,
    required this.date,
    required this.reason,
    required this.disabledBy,
    required this.disabledByName,
    required this.createdAt,
  });

  /// Normaliza la fecha a solo año-mes-día (sin hora)
  static DateTime normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Genera un ID determinista basado en la fecha: "2026-04-13"
  static String idFromDate(DateTime d) {
    final n = normalizeDate(d);
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  factory DisabledDay.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DisabledDay(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      reason: data['reason'] ?? '',
      disabledBy: data['disabledBy'] ?? '',
      disabledByName: data['disabledByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(normalizeDate(date)),
        'reason': reason,
        'disabledBy': disabledBy,
        'disabledByName': disabledByName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  bool coversDay(DateTime day) {
    final nd = normalizeDate(day);
    final nSelf = normalizeDate(date);
    return nd == nSelf;
  }
}