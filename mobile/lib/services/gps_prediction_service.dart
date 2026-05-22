import 'package:flutter/material.dart';
import 'gps_device_service.dart';
import 'sms_history_service.dart';
import '../models/sms_history.dart';

/// Statut prédit pour un module GPS
enum GpsPredictedStatus {
  ok, // 2 — Opérationnel
  fwCheck, // 0 — Vérification firmware
  configNeeded, // 1 — Configuration requise
  diagnostic, // 3 — Diagnostic requis (anomalie)
  manualNeeded, // 4 — Intervention manuelle
}

class GpsPrediction {
  final String imei;
  final String equipmentType;
  final GpsPredictedStatus status;
  final String label;
  final String description;
  final String recommendation;
  final int rawStatus;

  GpsPrediction({
    required this.imei,
    required this.equipmentType,
    required this.status,
    required this.label,
    required this.description,
    required this.recommendation,
    required this.rawStatus,
  });

  Color get color {
    switch (status) {
      case GpsPredictedStatus.ok:
        return const Color(0xFF26C6A6); // vert
      case GpsPredictedStatus.fwCheck:
        return const Color(0xFF5DA5B3); // bleu
      case GpsPredictedStatus.configNeeded:
        return const Color(0xFFFFB347); // orange
      case GpsPredictedStatus.diagnostic:
        return const Color(0xFFFF4444); // rouge
      case GpsPredictedStatus.manualNeeded:
        return const Color(0xFF9C27B0); // violet
    }
  }

  IconData get icon {
    switch (status) {
      case GpsPredictedStatus.ok:
        return Icons.check_circle_rounded;
      case GpsPredictedStatus.fwCheck:
        return Icons.system_update_alt;
      case GpsPredictedStatus.configNeeded:
        return Icons.settings_outlined;
      case GpsPredictedStatus.diagnostic:
        return Icons.warning_amber_rounded;
      case GpsPredictedStatus.manualNeeded:
        return Icons.build_outlined;
    }
  }

  bool get needsAlert => status != GpsPredictedStatus.ok;

  // Conclusions dynamiques enrichies par l'historique SMS
  String dynamicDescription = '';
  String dynamicConclusion = '';
  List<String> smsResponses = [];
}

class GpsPredictionService {
  /// Analyse la liste de modules et retourne une prédiction par module
  static List<GpsPrediction> predict(List<GpsDevice> devices) {
    return devices.map((d) => _predictOne(d)).toList();
  }

  static GpsPrediction _predictOne(GpsDevice d) {
    final s = d.equipmentStatus;
    final imei = d.serialNumber;
    final type = d.equipmentType;

    switch (s) {
      case 0:
        return GpsPrediction(
          imei: imei,
          equipmentType: type,
          rawStatus: s,
          status: GpsPredictedStatus.fwCheck,
          label: 'Vérification Firmware',
          description:
              'Le module nécessite une vérification de la version firmware.',
          recommendation: 'Envoyer la commande de vérification FW via SMS.',
        );
      case 1:
        return GpsPrediction(
          imei: imei,
          equipmentType: type,
          rawStatus: s,
          status: GpsPredictedStatus.configNeeded,
          label: 'Configuration Requise',
          description:
              'Firmware validé. Les paramètres APN/IP/Port doivent être configurés.',
          recommendation:
              'Envoyer les SMS de configuration (APN, IP serveur, Port).',
        );
      case 2:
        return GpsPrediction(
          imei: imei,
          equipmentType: type,
          rawStatus: s,
          status: GpsPredictedStatus.ok,
          label: 'Opérationnel',
          description: 'Module fonctionnel — aucune anomalie détectée.',
          recommendation: 'Aucune action requise.',
        );
      case 3:
        return GpsPrediction(
          imei: imei,
          equipmentType: type,
          rawStatus: s,
          status: GpsPredictedStatus.diagnostic,
          label: 'Panne Détectée',
          description: 'Anomalie détectée. Un auto-diagnostic est nécessaire.',
          recommendation:
              'Lancer le diagnostic automatique depuis la section Diagnostic.',
        );
      case 4:
        return GpsPrediction(
          imei: imei,
          equipmentType: type,
          rawStatus: s,
          status: GpsPredictedStatus.manualNeeded,
          label: 'Intervention Manuelle',
          description:
              'Le diagnostic automatique a échoué. Une intervention humaine est requise.',
          recommendation: 'Contacter un technicien pour intervention sur site.',
        );
      default:
        return GpsPrediction(
          imei: imei,
          equipmentType: type,
          rawStatus: s,
          status: GpsPredictedStatus.ok,
          label: 'Inconnu',
          description: 'Statut non reconnu ($s).',
          recommendation: 'Vérifier manuellement.',
        );
    }
  }

  /// Nombre de modules en alerte (status != ok)
  static int alertCount(List<GpsPrediction> predictions) =>
      predictions.where((p) => p.needsAlert).length;

  /// Enrichit les prédictions avec l'analyse réelle des SMS reçus
  static Future<List<GpsPrediction>> predictWithSms(
      List<GpsDevice> devices) async {
    final preds = predict(devices);
    final history = await SmsHistoryService.getHistory();
    for (final p in preds) {
      final moduleSms = history.where((s) {
        final mn = (s.moduleName ?? '').toLowerCase();
        final imei = p.imei.toLowerCase();
        return mn.contains(imei) || imei.contains(mn);
      }).toList();
      _enrichFromSms(p, moduleSms);
    }
    return preds;
  }

  static void _enrichFromSms(GpsPrediction p, List<SmsHistoryItem> sms) {
    if (sms.isEmpty) {
      p.dynamicDescription = p.description;
      p.dynamicConclusion = 'Aucun SMS échangé avec ce module.';
      return;
    }

    final responses = sms
        .where(
            (s) => s.status == SmsHistoryStatus.received && s.response != null)
        .map((s) => s.response!)
        .toList();
    p.smsResponses = responses;

    final lastSent = sms.first;
    final sentCount = sms
        .where((s) =>
            s.status == SmsHistoryStatus.sent ||
            s.status == SmsHistoryStatus.delivered)
        .length;
    final failCount =
        sms.where((s) => s.status == SmsHistoryStatus.failed).length;
    final receivedCount = responses.length;

    // Analyse des réponses SMS pour conclusions
    final conclusions = <String>[];

    for (final r in responses) {
      final body = r.toLowerCase();
      if (body.contains('timeout') || body.contains('no response')) {
        conclusions.add('⚠ Timeout détecté — module ne répond pas');
      }
      if (body.contains('imei') && body.contains('000000000000000')) {
        conclusions.add('🔴 IMEI corrompu détecté dans la réponse');
      }
      if (body.contains('utc') && !body.contains('utc:0')) {
        conclusions.add('⏱ Décalage UTC non corrigé');
      }
      if (body.contains('protocol') &&
          !RegExp(r'protocol\s*:\s*3\s*,\s*1').hasMatch(body)) {
        conclusions.add('📡 Protocole GPRS incorrect');
      }
      if (body.contains('hc') && !RegExp(r'hc\s*:\s*60').hasMatch(body)) {
        conclusions.add('💓 Heartbeat mal configuré');
      }
      if (body.contains('corner') &&
          !RegExp(r'corner\s*:\s*20').hasMatch(body)) {
        conclusions.add('📐 Angle virage incorrect');
      }
      if (body.contains('failed')) {
        conclusions.add('❌ Échec signalé dans la réponse du module');
      }
      if (body.contains('ok') || body.contains('gtupd')) {
        conclusions.add('✅ Commande acceptée par le module');
      }
    }

    final ago = DateTime.now().difference(lastSent.timestamp);
    final agoStr = ago.inHours > 0
        ? 'il y a ${ago.inHours}h'
        : 'il y a ${ago.inMinutes}min';

    p.dynamicDescription = 'Dernier SMS: ${lastSent.command} ($agoStr) — '
        '$sentCount envoyé(s), $receivedCount réponse(s)'
        '${failCount > 0 ? ', $failCount échec(s)' : ''}';

    if (conclusions.isEmpty) {
      p.dynamicConclusion = receivedCount == 0
          ? '⚠ Aucune réponse reçue du module — vérifier la SIM ou la portée réseau'
          : '✅ Réponses reçues mais statut API indique une anomalie — relancer le diagnostic';
    } else {
      p.dynamicConclusion = conclusions.toSet().join('\n');
    }
  }
}
