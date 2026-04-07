class SmsHistoryItem {
  final String id;
  final String phone;
  final String command;
  final String? response;
  final DateTime timestamp;
  final SmsHistoryStatus status;
  final String? moduleName;

  SmsHistoryItem({
    required this.id,
    required this.phone,
    required this.command,
    this.response,
    required this.timestamp,
    required this.status,
    this.moduleName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'command': command,
      'response': response,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'moduleName': moduleName,
    };
  }

  factory SmsHistoryItem.fromJson(Map<String, dynamic> json) {
    return SmsHistoryItem(
      id: json['id'],
      phone: json['phone'],
      command: json['command'],
      response: json['response'],
      timestamp: DateTime.parse(json['timestamp']),
      status: SmsHistoryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SmsHistoryStatus.pending,
      ),
      moduleName: json['moduleName'],
    );
  }
}

enum SmsHistoryStatus {
  sent,      // Envoyé
  pending,   // En attente
  failed,    // Non envoyé
  delivered, // Livré
  received,  // Reçu (réponse)
}

extension SmsHistoryStatusExtension on SmsHistoryStatus {
  String get label {
    switch (this) {
      case SmsHistoryStatus.sent:
        return 'Envoyé';
      case SmsHistoryStatus.pending:
        return 'En attente...';
      case SmsHistoryStatus.failed:
        return 'Non envoyé';
      case SmsHistoryStatus.delivered:
        return 'Livré';
      case SmsHistoryStatus.received:
        return 'Reçu';
    }
  }
}
