import 'dart:convert';

enum ConnectionType { ssh, ftp, sftp }

enum AuthType { password, key }

class ConnectionProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final ConnectionType type;
  final AuthType authType;
  final String? group;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;
  final Map<String, dynamic>? extraConfig;

  ConnectionProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.type,
    this.authType = AuthType.password,
    this.group,
    this.notes,
    DateTime? createdAt,
    this.lastConnectedAt,
    this.extraConfig,
  }) : createdAt = createdAt ?? DateTime.now();

  ConnectionProfile copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    ConnectionType? type,
    AuthType? authType,
    String? group,
    String? notes,
    DateTime? lastConnectedAt,
    Map<String, dynamic>? extraConfig,
  }) {
    return ConnectionProfile(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      type: type ?? this.type,
      authType: authType ?? this.authType,
      group: group ?? this.group,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      extraConfig: extraConfig ?? this.extraConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'type': type.name,
    'authType': authType.name,
    'group': group,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    'extraConfig': extraConfig,
  };

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      type: ConnectionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConnectionType.ssh,
      ),
      authType: AuthType.values.firstWhere(
        (e) => e.name == json['authType'],
        orElse: () => AuthType.password,
      ),
      group: json['group'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
      extraConfig: json['extraConfig'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ConnectionProfile.fromJsonString(String jsonString) {
    return ConnectionProfile.fromJson(jsonDecode(jsonString));
  }

  String get displayPort {
    switch (type) {
      case ConnectionType.ssh:
        return port == 22 ? '' : ':$port';
      case ConnectionType.ftp:
        return port == 21 ? '' : ':$port';
      case ConnectionType.sftp:
        return port == 22 ? '' : ':$port';
    }
  }

  String get connectionString => '$username@$host$displayPort';

  IconLabel get typeIcon {
    switch (type) {
      case ConnectionType.ssh:
        return IconLabel('terminal', 'SSH');
      case ConnectionType.ftp:
        return IconLabel('folder', 'FTP');
      case ConnectionType.sftp:
        return IconLabel('folder_special', 'SFTP');
    }
  }
}

class IconLabel {
  final String icon;
  final String label;

  IconLabel(this.icon, this.label);
}
