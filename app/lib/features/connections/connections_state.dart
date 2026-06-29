import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/connection_item.dart';

/// State for email connection management and sync.
class ConnectionsState extends ChangeNotifier {
  final ApiClient apiClient;

  List<ConnectionItem> connections = [];
  bool isLoading = false;
  bool isSaving = false;
  String? syncingConnectionId;
  String? errorMessage;

  ConnectionsState(this.apiClient);

  Future<void> refreshConnections() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      connections = await apiClient.listConnections();
    } catch (error) {
      errorMessage = error.toString();
      connections = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> addConnection(EmailConnectionRequest request) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final created = await apiClient.createEmailConnection(request);
      connections = [created, ...connections];
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteConnection(String connectionId) async {
    try {
      await apiClient.deleteConnection(connectionId);
      connections = connections.where((c) => c.id != connectionId).toList();
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<SyncResult?> syncConnection(String connectionId) async {
    syncingConnectionId = connectionId;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await apiClient.syncConnection(connectionId);
      await refreshConnections();
      return result;
    } catch (error) {
      errorMessage = error.toString();
      await refreshConnections();
      return null;
    } finally {
      syncingConnectionId = null;
      notifyListeners();
    }
  }

  Future<bool> testConnection(String connectionId) async {
    try {
      await apiClient.testConnection(connectionId);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }
}
