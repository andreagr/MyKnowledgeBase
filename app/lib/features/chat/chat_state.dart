import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/chat_models.dart';

/// State for chat conversation and citation selection.
class ChatState extends ChangeNotifier {
  final ApiClient apiClient;

  bool isSending = false;
  String? errorMessage;
  List<ChatMessage> messages = [];
  SourceChunk? selectedSource;

  ChatState(this.apiClient);

  Future<bool> askQuestion(String question) async {
    isSending = true;
    errorMessage = null;
    notifyListeners();

    final userMessage = ChatMessage(role: ChatRole.user, text: question);
    messages.add(userMessage);
    notifyListeners();

    try {
      final response = await apiClient.askQuestion(question);
      final assistantMessage = ChatMessage(
        role: ChatRole.assistant,
        text: response.answer,
        sources: response.sources,
        fileLocations: response.fileLocations,
      );
      messages.add(assistantMessage);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      messages.add(ChatMessage(
        role: ChatRole.assistant,
        text: 'Could not get an answer. ${errorMessage ?? ''}',
        sources: const [],
      ));
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void selectSource(SourceChunk source) {
    selectedSource = source;
    notifyListeners();
  }
}
