import 'package:pocketbase/pocketbase.dart';

class System {
  final String id;
  final String name;
  final String host;
  final String status;
  final double cpuPercent;
  final double memoryPercent;
  final double diskPercent;
  final String updated;

  System({
    required this.id,
    required this.name,
    required this.host,
    required this.status,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercent,
    required this.updated,
  });

  factory System.fromRecord(RecordModel record) {
    // Helper to safely parse double
    double toDouble(dynamic val) {
      if (val is int) return val.toDouble();
      if (val is double) return val;
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final info = record.data['info'] is Map ? record.data['info'] as Map<String, dynamic> : <String, dynamic>{};

    return System(
      id: record.id,
      name: record.getStringValue('name'),
      host: record.getStringValue('host'),
      status: record.getStringValue('status'),
      cpuPercent: toDouble(info['cpu']),
      memoryPercent: toDouble(info['mp']),
      diskPercent: toDouble(info['dp']),
      updated: record.updated,
    );
  }
}
