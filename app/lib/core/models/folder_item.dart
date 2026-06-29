class FolderItem {
  final String id;
  final String name;
  final String path;
  final bool recursive;
  final bool enabled;
  final String? createdAt;
  final String? lastScanAt;
  final String? lastScanStatus;
  final String? lastScanMessage;
  final int indexedCount;

  FolderItem({
    required this.id,
    required this.name,
    required this.path,
    required this.recursive,
    required this.enabled,
    this.createdAt,
    this.lastScanAt,
    this.lastScanStatus,
    this.lastScanMessage,
    required this.indexedCount,
  });

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Folder',
      path: json['path']?.toString() ?? '',
      recursive: json['recursive'] == true || json['recursive'] == 1,
      enabled: json['enabled'] == true || json['enabled'] == 1,
      createdAt: json['created_at']?.toString(),
      lastScanAt: json['last_scan_at']?.toString(),
      lastScanStatus: json['last_scan_status']?.toString(),
      lastScanMessage: json['last_scan_message']?.toString(),
      indexedCount: _parseInt(json['indexed_count']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class FolderCreateRequest {
  final String name;
  final String path;
  final bool recursive;

  FolderCreateRequest({
    required this.name,
    required this.path,
    this.recursive = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'recursive': recursive,
      };
}

class FolderScanResult {
  final int found;
  final int indexed;
  final int updated;
  final int skipped;
  final String message;

  FolderScanResult({
    required this.found,
    required this.indexed,
    required this.updated,
    required this.skipped,
    required this.message,
  });

  factory FolderScanResult.fromJson(Map<String, dynamic> json) {
    return FolderScanResult(
      found: FolderItem._parseInt(json['found']),
      indexed: FolderItem._parseInt(json['indexed']),
      updated: FolderItem._parseInt(json['updated']),
      skipped: FolderItem._parseInt(json['skipped']),
      message: json['message']?.toString() ?? '',
    );
  }
}
