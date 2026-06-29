import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import '../models/connection_item.dart';
import '../models/document_item.dart';
import '../models/folder_item.dart';
import '../models/health_status.dart';
import '../models/intelligence_config.dart';
import '../models/local_llm_compatibility.dart';

/// Reusable backend client for health checks, document upload, and chat queries.
class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  Uri _buildUri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Future<HealthStatus> getHealth() async {
    final uri = _buildUri('/health');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException('Health check failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return HealthStatus.fromJson(body);
  }

  Future<List<DocumentItem>> listDocuments() async {
    final uri = _buildUri('/documents');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException('Unable to load documents: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw ApiException('Invalid document list response');
    }

    return body
        .cast<Map<String, dynamic>>()
        .map(DocumentItem.fromJson)
        .toList();
  }

  Future<DocumentItem> uploadDocument(PlatformFile file) async {
    final uri = _buildUri('/documents/upload');
    final request = http.MultipartRequest('POST', uri);

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    } else {
      throw ApiException('No PDF file data available to upload.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(_formatApiError(
        'Upload failed',
        response.statusCode,
        response.body,
      ));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DocumentItem.fromJson(body);
  }

  Future<void> deleteDocument(String documentId) async {
    final uri = _buildUri('/documents/$documentId');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Failed to remove document: $detail');
    }
  }

  Future<ChatResponse> askQuestion(String question, {int topK = 5}) async {
    final uri = _buildUri('/chat/query');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question, 'top_k': topK}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Chat query failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatResponse.fromJson(body);
  }

  String getDownloadUrl(String documentId) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$normalizedBase/documents/$documentId/download';
  }

  Future<List<ConnectionItem>> listConnections() async {
    final uri = _buildUri('/connections');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException('Unable to load connections: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw ApiException('Invalid connections response');
    }

    return body
        .cast<Map<String, dynamic>>()
        .map(ConnectionItem.fromJson)
        .toList();
  }

  Future<ConnectionItem> createEmailConnection(EmailConnectionRequest request) async {
    final uri = _buildUri('/connections/email');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Failed to create connection: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ConnectionItem.fromJson(body);
  }

  Future<void> deleteConnection(String connectionId) async {
    final uri = _buildUri('/connections/$connectionId');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete connection: ${response.statusCode}');
    }
  }

  Future<SyncResult> syncConnection(String connectionId) async {
    final uri = _buildUri('/connections/$connectionId/sync');
    final response = await http.post(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Sync failed: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SyncResult.fromJson(body);
  }

  Future<void> testConnection(String connectionId) async {
    final uri = _buildUri('/connections/$connectionId/test');
    final response = await http.post(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Connection test failed: $detail');
    }
  }

  Future<FileLocation> getDocumentLocation(String documentId) async {
    final uri = _buildUri('/documents/$documentId/location');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Unable to get file location: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FileLocation.fromJson(body);
  }

  Future<List<FolderItem>> listFolders() async {
    final uri = _buildUri('/folders');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw ApiException('Unable to load folders: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw ApiException('Invalid folders response');
    }

    return body.cast<Map<String, dynamic>>().map(FolderItem.fromJson).toList();
  }

  Future<FolderItem> createFolder(FolderCreateRequest request) async {
    final uri = _buildUri('/folders');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Failed to add folder: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FolderItem.fromJson(body);
  }

  Future<void> deleteFolder(String folderId) async {
    final uri = _buildUri('/folders/$folderId');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw ApiException('Failed to remove folder: ${response.statusCode}');
    }
  }

  Future<FolderScanResult> scanFolder(String folderId) async {
    final uri = _buildUri('/folders/$folderId/scan');
    final response = await http.post(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Scan failed: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FolderScanResult.fromJson(body);
  }

  Future<LocalLlmCompatibility> getLocalLlmCompatibility() async {
    final uri = _buildUri('/local-llm/compatibility');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      final detail =
          response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Unable to scan this PC for local models: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return LocalLlmCompatibility.fromJson(body);
  }

  Future<IntelligenceConfig> getIntelligenceConfig() async {
    final uri = _buildUri('/config/intelligence');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      if (response.statusCode == 404) {
        throw ApiException(
          'Intelligence settings endpoint not found. Restart the backend to load the latest server code.',
        );
      }
      throw ApiException('Unable to load intelligence settings: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return IntelligenceConfig.fromJson(body);
  }

  Future<IntelligenceConfig> updateIntelligenceConfig(
    IntelligenceConfigUpdate update,
  ) async {
    final uri = _buildUri('/config/intelligence');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(update.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_formatApiError(
        'Failed to save intelligence settings',
        response.statusCode,
        response.body,
      ));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return IntelligenceConfig.fromJson(body);
  }

  Future<FolderScanResult> scanAllFolders() async {
    final uri = _buildUri('/folders/scan-all');
    final response = await http.post(uri);

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : '${response.statusCode}';
      throw ApiException('Scan failed: $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FolderScanResult.fromJson(body);
  }
}

String _formatApiError(String prefix, int statusCode, String body) {
  if (body.isEmpty) return '$prefix: $statusCode';
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final messages = detail
            .whereType<Map<String, dynamic>>()
            .map((item) => item['msg'] as String?)
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
    }
  } catch (_) {
    // Fall back to raw body below.
  }
  return '$prefix: $body';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
