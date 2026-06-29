import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/folder_item.dart';

/// State for watched folder management and scanning.
class FoldersState extends ChangeNotifier {
  final ApiClient apiClient;

  List<FolderItem> folders = [];
  bool isLoading = false;
  bool isSaving = false;
  bool isScanningAll = false;
  String? scanningFolderId;
  String? errorMessage;

  FoldersState(this.apiClient);

  Future<void> refreshFolders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      folders = await apiClient.listFolders();
    } catch (error) {
      errorMessage = error.toString();
      folders = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> addFolder(FolderCreateRequest request) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final created = await apiClient.createFolder(request);
      folders = [created, ...folders];
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFolder(String folderId) async {
    try {
      await apiClient.deleteFolder(folderId);
      folders = folders.where((f) => f.id != folderId).toList();
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<FolderScanResult?> scanFolder(String folderId) async {
    scanningFolderId = folderId;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await apiClient.scanFolder(folderId);
      await refreshFolders();
      return result;
    } catch (error) {
      errorMessage = error.toString();
      await refreshFolders();
      return null;
    } finally {
      scanningFolderId = null;
      notifyListeners();
    }
  }

  Future<FolderScanResult?> scanAllFolders() async {
    isScanningAll = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await apiClient.scanAllFolders();
      await refreshFolders();
      return result;
    } catch (error) {
      errorMessage = error.toString();
      await refreshFolders();
      return null;
    } finally {
      isScanningAll = false;
      notifyListeners();
    }
  }
}
