class ChatQueryRequest {
  final String question;
  final int topK;

  ChatQueryRequest({required this.question, this.topK = 5});

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'top_k': topK,
    };
  }
}

class SourceChunk {
  final String documentId;
  final String filename;
  final int page;
  final String text;
  final double score;
  final String sourceType;
  final String? filePath;
  final String? folderPath;
  final bool canOpenFolder;

  SourceChunk({
    required this.documentId,
    required this.filename,
    required this.page,
    required this.text,
    required this.score,
    this.sourceType = 'pdf',
    this.filePath,
    this.folderPath,
    this.canOpenFolder = false,
  });

  factory SourceChunk.fromJson(Map<String, dynamic> json) {
    return SourceChunk(
      documentId: json['document_id']?.toString() ?? json['documentId']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'Unknown',
      page: _parseInt(json['page']),
      text: json['text']?.toString() ?? '',
      score: _parseDouble(json['score']),
      sourceType: json['source_type']?.toString() ?? 'pdf',
      filePath: json['file_path']?.toString(),
      folderPath: json['folder_path']?.toString(),
      canOpenFolder: json['can_open_folder'] == true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SourceChunk &&
            documentId == other.documentId &&
            filename == other.filename &&
            page == other.page &&
            text == other.text &&
            score == other.score &&
            sourceType == other.sourceType &&
            filePath == other.filePath &&
            folderPath == other.folderPath &&
            canOpenFolder == other.canOpenFolder;
  }

  @override
  int get hashCode => Object.hash(
        documentId,
        filename,
        page,
        text,
        score,
        sourceType,
        filePath,
        folderPath,
        canOpenFolder,
      );
}

class FileLocation {
  final String documentId;
  final String filename;
  final String sourceType;
  final String? filePath;
  final String? folderPath;
  final bool canOpenFolder;

  FileLocation({
    required this.documentId,
    required this.filename,
    this.sourceType = 'pdf',
    this.filePath,
    this.folderPath,
    this.canOpenFolder = false,
  });

  factory FileLocation.fromJson(Map<String, dynamic> json) {
    return FileLocation(
      documentId: json['document_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'Unknown',
      sourceType: json['source_type']?.toString() ?? 'pdf',
      filePath: json['file_path']?.toString(),
      folderPath: json['folder_path']?.toString(),
      canOpenFolder: json['can_open_folder'] == true,
    );
  }
}

class ChatResponse {
  final String answer;
  final List<SourceChunk> sources;
  final List<FileLocation> fileLocations;

  ChatResponse({
    required this.answer,
    required this.sources,
    this.fileLocations = const [],
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final sourcesData = json['sources'];
    final sources = <SourceChunk>[];
    if (sourcesData is List) {
      for (final item in sourcesData.cast<Map<String, dynamic>>()) {
        sources.add(SourceChunk.fromJson(item));
      }
    }

    final locationsData = json['file_locations'];
    final fileLocations = <FileLocation>[];
    if (locationsData is List) {
      for (final item in locationsData.cast<Map<String, dynamic>>()) {
        fileLocations.add(FileLocation.fromJson(item));
      }
    }

    return ChatResponse(
      answer: json['answer']?.toString() ?? '',
      sources: sources,
      fileLocations: fileLocations,
    );
  }
}

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String text;
  final List<SourceChunk> sources;
  final List<FileLocation> fileLocations;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.fileLocations = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
