import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/document_item.dart';
import '../../core/models/health_status.dart';

enum DocumentSortOrder { newestFirst, oldestFirst }

/// State for document list, upload flow, and backend health.
class DocumentsState extends ChangeNotifier {
  static const int pageSize = 10;

  final ApiClient apiClient;

  HealthStatus healthStatus = HealthStatus(healthy: false, message: 'Checking connection');
  List<DocumentItem> documents = [];
  DocumentItem? selectedDocument;
  DocumentSortOrder sortOrder = DocumentSortOrder.newestFirst;
  int currentPage = 0;
  bool isLoading = false;
  bool isUploading = false;
  bool isCheckingHealth = false;
  String? errorMessage;

  DocumentsState(this.apiClient);

  List<DocumentItem> get sortedDocuments {
    final sorted = List<DocumentItem>.from(documents);
    sorted.sort((a, b) {
      final aDate = a.indexedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.indexedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return sortOrder == DocumentSortOrder.newestFirst
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });
    return sorted;
  }

  int get totalPages {
    if (documents.isEmpty) return 1;
    return (documents.length + pageSize - 1) ~/ pageSize;
  }

  bool get hasMultiplePages => documents.length > pageSize;

  List<DocumentItem> get paginatedDocuments {
    final sorted = sortedDocuments;
    if (sorted.isEmpty) return sorted;

    final safePage = currentPage.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final end = (start + pageSize).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  void setSortOrder(DocumentSortOrder order) {
    if (sortOrder == order) return;
    sortOrder = order;
    currentPage = 0;
    notifyListeners();
  }

  void setPage(int page) {
    final clamped = page.clamp(0, totalPages - 1);
    if (currentPage == clamped) return;
    currentPage = clamped;
    notifyListeners();
  }

  void _clampCurrentPage() {
    if (documents.isEmpty) {
      currentPage = 0;
      return;
    }
    if (currentPage >= totalPages) {
      currentPage = totalPages - 1;
    }
  }

  Future<void> initialize() async {
    await loadHealth();
    await refreshDocuments();
  }

  bool get hasConnection => healthStatus.healthy;

  Future<void> loadHealth() async {
    isCheckingHealth = true;
    notifyListeners();

    try {
      final response = await apiClient.getHealth();
      healthStatus = response;
    } catch (error) {
      healthStatus = HealthStatus(
        healthy: false,
        message: 'Offline: ${error.toString()}',
      );
    } finally {
      isCheckingHealth = false;
      notifyListeners();
    }
  }

  Future<void> refreshHealthStatus() async {
    await loadHealth();
    if (healthStatus.healthy) {
      await refreshDocuments();
    }
  }

  Future<void> refreshDocuments() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      documents = await apiClient.listDocuments();
      documents = documents.where((doc) => doc.id.isNotEmpty).toList();
      if (selectedDocument != null) {
        final match = documents
            .where((doc) => doc.id == selectedDocument!.id)
            .firstOrNull;
        selectedDocument = match;
      }
    } catch (error) {
      errorMessage = error.toString();
      documents = [];
    }

    isLoading = false;
    _clampCurrentPage();
    notifyListeners();
  }

  Future<bool> uploadPdf(PlatformFile file) async {
    if (!hasConnection) {
      errorMessage = 'Cannot upload while backend is unavailable.';
      notifyListeners();
      return false;
    }

    isUploading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uploadedDocument = await apiClient.uploadDocument(file);
      await refreshDocuments();
      selectedDocument = documents.firstWhere(
        (item) => item.id == uploadedDocument.id,
        orElse: () => uploadedDocument,
      );
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  void selectDocument(String documentId) {
    final match = documents.where((item) => item.id == documentId).firstOrNull;
    if (match == null) {
      return;
    }
    selectedDocument = match;
    notifyListeners();
  }

  Future<bool> removeDocument(String documentId) async {
    try {
      await apiClient.deleteDocument(documentId);
      documents = documents.where((doc) => doc.id != documentId).toList();
      if (selectedDocument?.id == documentId) {
        selectedDocument = null;
      }
      errorMessage = null;
      _clampCurrentPage();
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }
}
