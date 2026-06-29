import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/intelligence_config.dart';
import '../../core/models/local_llm_compatibility.dart';

/// State for LLM / intelligence configuration.
class IntelligenceState extends ChangeNotifier {
  final ApiClient apiClient;

  IntelligenceConfig? config;
  LocalLlmCompatibility? localLlmCompatibility;
  bool isLoading = false;
  bool isLoadingLocalLlm = false;
  bool isSaving = false;
  String? errorMessage;
  String? localLlmErrorMessage;

  IntelligenceState(this.apiClient);

  bool get isLlmReady => config?.isKeyConfigured ?? false;

  String get statusLabel {
    if (isLoading) return 'Checking LLM…';
    if (config == null) {
      return errorMessage != null ? 'LLM unavailable' : 'Checking LLM…';
    }
    if (!config!.isKeyConfigured) return 'No API key';
    return '${config!.providerName} ready';
  }

  Future<void> initialize() => refreshAll();

  Future<void> refreshAll() async {
    await Future.wait([refreshConfig(), refreshLocalLlmCompatibility()]);
  }

  Future<void> refreshConfig() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      config = await apiClient.getIntelligenceConfig();
    } catch (error) {
      errorMessage = error.toString();
      config = null;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshLocalLlmCompatibility() async {
    isLoadingLocalLlm = true;
    localLlmErrorMessage = null;
    notifyListeners();

    try {
      localLlmCompatibility = await apiClient.getLocalLlmCompatibility();
    } catch (error) {
      localLlmErrorMessage = error.toString();
      localLlmCompatibility = null;
    }

    isLoadingLocalLlm = false;
    notifyListeners();
  }

  Future<bool> saveConfig(IntelligenceConfigUpdate update) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      config = await apiClient.updateIntelligenceConfig(update);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
