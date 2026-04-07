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
    // Nettoyer le HTML de la description
    final rawDesc = json['description'] as String? ?? '';
    final cleanDesc = rawDesc.isNotEmpty
        ? parse(rawDesc).body?.text?.trim() ?? rawDesc
        : '';

    // Extraire date/heure depuis created_at
    final createdAt = json['created_at'] as String? ?? '';
    String startTime = '';
    String endTime = '';
    if (createdAt.isNotEmpty) {
      final parts = createdAt.split(' ');
      startTime = parts.length > 1 ? parts[1].substring(0, 5) : parts[0];
      endTime = '';
    }

    return Task(
      id: json['id'].toString(),
      reference: '#${json['id']}',
      name: json['subject'] as String? ?? '',
      description: cleanDesc.length > 200
          ? '${cleanDesc.substring(0, 200)}...'
          : cleanDesc,
      partnerName: createdAt.isNotEmpty ? createdAt.split(' ')[0] : '',
      startTime: startTime,
      endTime: endTime,
      status: _parseStatus(json['stage'] as String?),
    );
  }

  static TaskStatus _parseStatus(String? stage) {
    switch (stage?.toLowerCase()) {
      case 'done':
        return TaskStatus.completed;
      case 'planifié':
      case 'planifie':
      case 'in progress':
      case 'en cours':
        return TaskStatus.inProgress;
      case 'cancelled':
      case 'cancel':
        return TaskStatus.completed;
      default:
        return TaskStatus.todo;
    }
  }
}

enum TaskStatus {
  todo,
  inProgress,
  completed;

  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'NOUVEAU';
      case TaskStatus.inProgress:
        return 'PLANIFIÉ';
      case TaskStatus.completed:
        return 'TERMINÉ';
    }
  }
}
