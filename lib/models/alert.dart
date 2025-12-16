class Alert {
  final String id;
  final String title;
  final String message;
  final String type; // 'info', 'warning', 'error'
  final int timestamp;
  final String systemName;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.systemName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp,
      'systemName': systemName,
    };
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      timestamp: json['timestamp'] ?? 0,
      systemName: json['systemName'] ?? '',
    );
  }
}
