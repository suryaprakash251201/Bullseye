import 'dart:convert';

enum MonitorType { http, ping, port }
enum MonitorStatus { up, down, unknown, checking }

class WebsiteMonitor {
  final String id;
  final String name;
  final String url;
  final MonitorType type;
  final int checkIntervalSeconds;
  final bool isActive;
  final int? expectedStatusCode;
  final int? port;
  final DateTime createdAt;
  final List<MonitorCheckResult> history;

  WebsiteMonitor({
    required this.id,
    required this.name,
    required this.url,
    this.type = MonitorType.http,
    this.checkIntervalSeconds = 60,
    this.isActive = true,
    this.expectedStatusCode = 200,
    this.port,
    DateTime? createdAt,
    List<MonitorCheckResult>? history,
  })  : createdAt = createdAt ?? DateTime.now(),
        history = history ?? [];

  MonitorStatus get currentStatus {
    if (history.isEmpty) return MonitorStatus.unknown;
    return history.last.isUp ? MonitorStatus.up : MonitorStatus.down;
  }

  double get uptimePercentage {
    if (history.isEmpty) return 0;
    final upCount = history.where((h) => h.isUp).length;
    return upCount / history.length;
  }

  Duration? get averageResponseTime {
    final validTimes = history
        .where((h) => h.responseTime != null)
        .map((h) => h.responseTime!.inMilliseconds)
        .toList();
    if (validTimes.isEmpty) return null;
    final avg = validTimes.reduce((a, b) => a + b) / validTimes.length;
    return Duration(milliseconds: avg.round());
  }

  MonitorCheckResult? get lastCheck {
    return history.isNotEmpty ? history.last : null;
  }

  WebsiteMonitor copyWith({
    String? name,
    String? url,
    MonitorType? type,
    int? checkIntervalSeconds,
    bool? isActive,
    int? expectedStatusCode,
    int? port,
    List<MonitorCheckResult>? history,
  }) {
    return WebsiteMonitor(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      checkIntervalSeconds: checkIntervalSeconds ?? this.checkIntervalSeconds,
      isActive: isActive ?? this.isActive,
      expectedStatusCode: expectedStatusCode ?? this.expectedStatusCode,
      port: port ?? this.port,
      createdAt: createdAt,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'type': type.name,
    'checkIntervalSeconds': checkIntervalSeconds,
    'isActive': isActive,
    'expectedStatusCode': expectedStatusCode,
    'port': port,
    'createdAt': createdAt.toIso8601String(),
    'history': history.map((h) => h.toJson()).toList(),
  };

  factory WebsiteMonitor.fromJson(Map<String, dynamic> json) {
    return WebsiteMonitor(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      type: MonitorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MonitorType.http,
      ),
      checkIntervalSeconds: json['checkIntervalSeconds'] as int? ?? 60,
      isActive: json['isActive'] as bool? ?? true,
      expectedStatusCode: json['expectedStatusCode'] as int?,
      port: json['port'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      history: (json['history'] as List<dynamic>?)
          ?.map((h) => MonitorCheckResult.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory WebsiteMonitor.fromJsonString(String s) =>
      WebsiteMonitor.fromJson(jsonDecode(s));
}

class MonitorCheckResult {
  final DateTime timestamp;
  final bool isUp;
  final int? statusCode;
  final Duration? responseTime;
  final String? error;

  MonitorCheckResult({
    required this.timestamp,
    required this.isUp,
    this.statusCode,
    this.responseTime,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'isUp': isUp,
    'statusCode': statusCode,
    'responseTimeMs': responseTime?.inMilliseconds,
    'error': error,
  };

  factory MonitorCheckResult.fromJson(Map<String, dynamic> json) {
    return MonitorCheckResult(
      timestamp: DateTime.parse(json['timestamp'] as String),
      isUp: json['isUp'] as bool,
      statusCode: json['statusCode'] as int?,
      responseTime: json['responseTimeMs'] != null
          ? Duration(milliseconds: json['responseTimeMs'] as int)
          : null,
      error: json['error'] as String?,
    );
  }
}
