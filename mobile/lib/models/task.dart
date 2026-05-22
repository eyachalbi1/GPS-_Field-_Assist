import 'package:html/parser.dart' show parse;

class Task {
  final String id;
  final String reference;
  final String name;
  final String description;
  final String partnerName;
  final String startTime;
  final String endTime;
  final TaskStatus status;

  Task({
    required this.id,
    required this.reference,
    required this.name,
    required this.description,
    required this.partnerName,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Titre : subject (Odoo) ou name (local)
    final rawName = (json['subject'] ?? json['name'] ?? '') as String;

    // Description : nettoyer le HTML
    final rawDesc = (json['description'] ?? '') as String;
    String cleanDesc = '';
    if (rawDesc.isNotEmpty) {
      try {
        cleanDesc = parse(rawDesc).body?.text?.trim() ?? rawDesc;
      } catch (_) {
        cleanDesc = rawDesc;
      }
      if (cleanDesc.length > 200) cleanDesc = '${cleanDesc.substring(0, 200)}...';
    }

    // Statut : stage (Odoo/local) ou status (ancien)
    final stageRaw = (json['stage'] ?? json['status'] ?? '') as String;

    // Dates
    final createdAt  = (json['created_at'] ?? '') as String;
    final startRaw   = (json['start_time']  ?? '') as String;
    final endRaw     = (json['end_time']    ?? '') as String;
    // start_time : utiliser le champ direct, sinon extraire de created_at
    String startTime = startRaw.isNotEmpty ? startRaw
        : (createdAt.contains(' ') ? createdAt.split(' ')[1].substring(0, 5) : '');
    String endTime   = endRaw;

    // partnerName : partner_name (local) ou assigned_to (Odoo) ou date
    final partnerName = (json['partner_name'] ?? json['assigned_to'] ??
        (createdAt.isNotEmpty ? createdAt.split(' ')[0] : '')) as String;

    return Task(
      id:          json['id'].toString(),
      reference:   '#${json['id']}',
      name:        rawName,
      description: cleanDesc,
      partnerName: partnerName,
      startTime:   startTime,
      endTime:     endTime,
      status:      _parseStatus(stageRaw),
    );
  }

  static TaskStatus _parseStatus(String? stage) {
    switch (stage?.toLowerCase()) {
      case 'done':        return TaskStatus.completed;
      case 'planifié':
      case 'planifie':
      case 'in progress':
      case 'en cours':    return TaskStatus.inProgress;
      case 'cancelled':
      case 'cancel':
      case 'annulé':
      case 'annule':      return TaskStatus.cancelled;
      default:            return TaskStatus.todo;
    }
  }
}

enum TaskStatus {
  todo,
  inProgress,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case TaskStatus.todo:       return 'NOUVEAU';
      case TaskStatus.inProgress: return 'PLANIFIÉ';
      case TaskStatus.completed:  return 'TERMINÉ';
      case TaskStatus.cancelled:  return 'ANNULÉ';
    }
  }
}
