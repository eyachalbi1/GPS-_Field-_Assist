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
    return Task(
      id: json['id'].toString(),
      reference: json['reference'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      partnerName: json['partner_name'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: _parseStatus(json['status']),
    );
  }

  static TaskStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'en_cours':
        return TaskStatus.inProgress;
      case 'termine':
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
        return 'À FAIRE';
      case TaskStatus.inProgress:
        return 'EN COURS';
      case TaskStatus.completed:
        return 'TERMINÉE';
    }
  }
}
