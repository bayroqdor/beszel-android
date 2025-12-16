import 'dart:convert';
import 'package:beszel_pro/models/alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AlertManager {
  static final AlertManager _instance = AlertManager._internal();

  factory AlertManager() {
    return _instance;
  }

  AlertManager._internal();

  List<Alert> _alerts = [];
  
  List<Alert> get alerts => List.unmodifiable(_alerts);

  Future<void> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? alertsJson = prefs.getStringList('local_alerts');

    if (alertsJson != null) {
      _alerts = alertsJson
          .map((str) => Alert.fromJson(jsonDecode(str)))
          .toList();
      // Sort specific if needed, but adding to top is better
      _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
  }

  Future<void> addAlert(String title, String message, String type, String systemName) async {
    final alert = Alert(
      id: const Uuid().v4(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      systemName: systemName,
    );

    _alerts.insert(0, alert);
    await _saveAlerts();
  }

  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> alertsJson = _alerts
        .map((alert) => jsonEncode(alert.toJson()))
        .toList();
    await prefs.setStringList('local_alerts', alertsJson);
  }

  Future<void> clearAlerts() async {
    _alerts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_alerts');
  }
}
