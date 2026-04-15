import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum EventType {
  reunionCliente,
  levantamiento,
  garantia,
  trabajoExtendido,
  capacitacion,
  reunionInterna,
}

extension EventTypeExt on EventType {
  String get label {
    switch (this) {
      case EventType.reunionCliente:
        return 'Reunión con Cliente';
      case EventType.levantamiento:
        return 'Levantamiento';
      case EventType.garantia:
        return 'Garantía';
      case EventType.trabajoExtendido:
        return 'Trabajo Extendido';
      case EventType.capacitacion:
        return 'Capacitación';
      case EventType.reunionInterna:
        return 'Reunión Interna';
    }
  }

  String get key {
    switch (this) {
      case EventType.reunionCliente:
        return 'reunionCliente';
      case EventType.levantamiento:
        return 'levantamiento';
      case EventType.garantia:
        return 'garantia';
      case EventType.trabajoExtendido:
        return 'trabajoExtendido';
      case EventType.capacitacion:
        return 'capacitacion';
      case EventType.reunionInterna:
        return 'reunionInterna';
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.reunionCliente:
        return Icons.handshake_outlined;
      case EventType.levantamiento:
        return Icons.camera_alt_outlined;
      case EventType.garantia:
        return Icons.verified_outlined;
      case EventType.trabajoExtendido:
        return Icons.access_time_outlined;
      case EventType.capacitacion:
        return Icons.school_outlined;
      case EventType.reunionInterna:
        return Icons.group_outlined;
    }
  }

  Color get color {
    switch (this) {
      case EventType.reunionCliente:
        return const Color(0xFF2563EB);
      case EventType.levantamiento:
        return const Color(0xFF7C3AED);
      case EventType.garantia:
        return const Color(0xFF059669);
      case EventType.trabajoExtendido:
        return const Color(0xFFEA580C);
      case EventType.capacitacion:
        return const Color(0xFF0891B2);
      case EventType.reunionInterna:
        return const Color(0xFF64748B);
    }
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final EventType type;
  final String clientName;
  final String contactName;
  final String contactPhone;
  final bool isCustomClient; // cliente fuera del catálogo
  final DateTime startDate;
  final DateTime endDate;
  final int colorValue; // color.value
  final String? vehicleId;
  final String? vehicleModel;
  final List<String> vehicleIds;
  final List<String> vehicleModels;
  final List<String> technicianIds;
  final List<String> technicianNames;
  final String createdBy;
  final DateTime createdAt;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.clientName,
    this.contactName = '',
    this.contactPhone = '',
    this.isCustomClient = false,
    required this.startDate,
    required this.endDate,
    required this.colorValue,
    this.vehicleId,
    this.vehicleModel,
    this.vehicleIds = const [],
    this.vehicleModels = const [],
    this.technicianIds = const [],
    this.technicianNames = const [],
    required this.createdBy,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  factory CalendarEvent.fromMap(Map<String, dynamic> data, String docId) {
    return CalendarEvent(
      id: docId,
      title: data['title'] ?? '',
      type: EventType.values.firstWhere(
        (e) => e.key == data['type'],
        orElse: () => EventType.reunionCliente,
      ),
      clientName: data['clientName'] ?? '',
      contactName: data['contactName'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      isCustomClient: data['isCustomClient'] ?? false,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      colorValue: data['colorValue'] ?? 0xFF2563EB,
      vehicleId: data['vehicleId'],
      vehicleModel: data['vehicleModel'],
      vehicleIds: List<String>.from(data['vehicleIds'] ?? []),
      vehicleModels: List<String>.from(data['vehicleModels'] ?? []),
      technicianIds: List<String>.from(data['technicianIds'] ?? []),
      technicianNames: List<String>.from(data['technicianNames'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.key,
        'clientName': clientName,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'isCustomClient': isCustomClient,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'colorValue': colorValue,
        'vehicleId': vehicleId,
        'vehicleModel': vehicleModel,
        'vehicleIds': vehicleIds,
        'vehicleModels': vehicleModels,
        'technicianIds': technicianIds,
        'technicianNames': technicianNames,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// True si el evento cubre el día dado
  bool coversDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }
}