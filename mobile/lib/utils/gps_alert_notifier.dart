import 'package:flutter/foundation.dart';

/// Partagé entre DiagnosticScreen et HomeScreen
/// pour afficher l'icône d'alerte GPS dans la topbar principale.
final gpsAlertNotifier = ValueNotifier<int>(0);
