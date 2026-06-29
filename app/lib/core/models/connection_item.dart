class ConnectionItem {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String folder;
  final bool enabled;
  final String? createdAt;
  final String? lastSyncAt;
  final String? lastSyncStatus;
  final String? lastSyncMessage;
  final int indexedCount;

  ConnectionItem({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.folder,
    required this.enabled,
    this.createdAt,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.lastSyncMessage,
    required this.indexedCount,
  });

  factory ConnectionItem.fromJson(Map<String, dynamic> json) {
    return ConnectionItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Email',
      host: json['host']?.toString() ?? '',
      port: _parseInt(json['port']),
      username: json['username']?.toString() ?? '',
      folder: json['folder']?.toString() ?? 'INBOX',
      enabled: json['enabled'] == true || json['enabled'] == 1,
      createdAt: json['created_at']?.toString(),
      lastSyncAt: json['last_sync_at']?.toString(),
      lastSyncStatus: json['last_sync_status']?.toString(),
      lastSyncMessage: json['last_sync_message']?.toString(),
      indexedCount: _parseInt(json['indexed_count']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class EmailConnectionRequest {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String folder;

  EmailConnectionRequest({
    required this.name,
    required this.host,
    this.port = 993,
    required this.username,
    required this.password,
    this.folder = 'INBOX',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'folder': folder,
      };
}

class SyncResult {
  final int indexed;
  final int skipped;
  final String message;

  SyncResult({
    required this.indexed,
    required this.skipped,
    required this.message,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      indexed: ConnectionItem._parseInt(json['indexed']),
      skipped: ConnectionItem._parseInt(json['skipped']),
      message: json['message']?.toString() ?? '',
    );
  }
}
