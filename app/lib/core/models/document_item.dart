class DocumentItem {
  final String id;
  final String filename;
  final int pages;
  final int chunks;
  final String sourceType;
  final DateTime? indexedAt;
  final bool broken;

  DocumentItem({
    required this.id,
    required this.filename,
    required this.pages,
    required this.chunks,
    this.sourceType = 'pdf',
    this.indexedAt,
    this.broken = false,
  });

  bool get isEmail => sourceType == 'email';
  bool get isFolder => sourceType == 'folder';

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'Unnamed.pdf',
      pages: _parseInt(json['pages']),
      chunks: _parseInt(json['chunks']),
      sourceType: json['source_type']?.toString() ?? 'pdf',
      indexedAt: _parseDate(json['indexed_at']),
      broken: json['broken'] == true,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
