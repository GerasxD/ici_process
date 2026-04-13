import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
 
class ProcessModel {
  final String id;
  final String title;
  final String client;
  final String requestedBy;
  final DateTime requestDate;
  final ProcessStage stage;
  final String description;
  final String priority;
  final double amount;
  final double estimatedCost;
  final String? poNumber;
  final String? poDate;
  final bool skipClientPO;
  final String logisticsStatus;
  final List<HistoryEntry> history;
  final List<CommentModel> comments;
  final DateTime updatedAt;
  final Map<String, dynamic>? quotationData;
  final Map<String, dynamic>? logisticsData;
  final Map<String, dynamic>? reportBillingData;
  final List<Map<String, dynamic>> attachments; 

  ProcessModel({
    required this.id,
    required this.title,
    required this.client,
    required this.requestedBy,
    required this.requestDate,
    required this.stage,
    required this.description,
    required this.priority,
    this.amount = 0.0,
    this.estimatedCost = 0.0,
    this.poNumber,
    this.poDate,
    this.skipClientPO = false,
    this.logisticsStatus = 'ToBuy',
    required this.history,
    required this.comments,
    required this.updatedAt,
    this.quotationData,
    this.logisticsData,
    this.reportBillingData,
    this.attachments = const [], 
  });
 
  factory ProcessModel.fromMap(Map<String, dynamic> data, String docId) {
    return ProcessModel(
      id: docId,
      title: data['title'] ?? '',
      client: data['client'] ?? '',
      requestedBy: data['requestedBy'] ?? '',
      requestDate: (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stage: ProcessStage.values.firstWhere(
        (e) => e.toString().split('.').last == data['stage'],
        orElse: () => ProcessStage.E1,
      ),
      description: data['description'] ?? '',
      priority: data['priority'] ?? 'Media',
      amount: (data['amount'] ?? 0).toDouble(),
      estimatedCost: (data['estimatedCost'] ?? 0).toDouble(),
      poNumber: data['poNumber'],
      poDate: data['poDate'],
      skipClientPO: data['skipClientPO'] ?? false,
      logisticsStatus: data['logisticsStatus'] ?? 'ToBuy',
      history: (data['history'] as List? ?? [])
          .map((e) => HistoryEntry.fromMap(e))
          .toList(),
      comments: (data['comments'] as List? ?? [])
          .map((e) => CommentModel.fromMap(e))
          .toList(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      quotationData: data['quotationData'] != null
          ? Map<String, dynamic>.from(data['quotationData'])
          : null,
      logisticsData: data['logisticsData'] != null
          ? Map<String, dynamic>.from(data['logisticsData'])
          : null,
      reportBillingData: data['reportBillingData'] != null
          ? Map<String, dynamic>.from(data['reportBillingData'])
          : null,
      // ── NUEVO: Leer attachments ─────────────────────────
      attachments: (data['attachments'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
 
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'client': client,
      'requestedBy': requestedBy,
      'requestDate': Timestamp.fromDate(requestDate),
      'stage': stage.toString().split('.').last,
      'description': description,
      'priority': priority,
      'amount': amount,
      'estimatedCost': estimatedCost,
      'poNumber': poNumber,
      'poDate': poDate,
      'skipClientPO': skipClientPO,
      'logisticsStatus': logisticsStatus,
      'history': history.map((e) => e.toMap()).toList(),
      'comments': comments.map((e) => e.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'quotationData': quotationData,
      'logisticsData': logisticsData,
      'reportBillingData': reportBillingData,
    };
  }
}
 
// ── Los modelos CommentModel y HistoryEntry no cambian ──────
class CommentModel {
  final String id;
  final String text;
  final String userName;
  final String userId;
  final DateTime date;
  final List<String> mentionedUserIds;
  final String? stageAtCreation;
  final bool isEdited;
 
  CommentModel({
    required this.id,
    required this.text,
    required this.userName,
    this.userId = '',
    required this.date,
    this.mentionedUserIds = const [],
    this.stageAtCreation,
    this.isEdited = false,
  });
 
  factory CommentModel.fromMap(Map<String, dynamic> data) {
    return CommentModel(
      id: data['id'] ?? '',
      text: data['text'] ?? '',
      userName: data['userName'] ?? '',
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      stageAtCreation: data['stageAtCreation'],
      isEdited: data['isEdited'] ?? false,
    );
  }
 
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'userName': userName,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'mentionedUserIds': mentionedUserIds,
      'stageAtCreation': stageAtCreation,
      'isEdited': isEdited,
    };
  }
}
 
class HistoryEntry {
  final String action;
  final String userName;
  final DateTime date;
  final String? details;
 
  HistoryEntry({
    required this.action,
    required this.userName,
    required this.date,
    this.details,
  });
 
  factory HistoryEntry.fromMap(Map<String, dynamic> data) {
    return HistoryEntry(
      action: data['action'] ?? '',
      userName: data['userName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      details: data['details'],
    );
  }
 
  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'userName': userName,
      'date': Timestamp.fromDate(date),
      'details': details,
    };
  }
}