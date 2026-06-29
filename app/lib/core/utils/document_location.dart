import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'open_location.dart';

Future<void> openDocumentInFolder(
  BuildContext context,
  ApiClient apiClient,
  String documentId,
) async {
  try {
    final resolved = await apiClient.getDocumentLocation(documentId);

    if (resolved.folderPath != null && resolved.folderPath!.isNotEmpty) {
      final error = await LocationOpener.openFolder(resolved.folderPath!);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    if (resolved.filePath != null && resolved.filePath!.isNotEmpty) {
      final error = await LocationOpener.openFileInFolder(resolved.filePath!);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No local folder is available for this document.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open folder: $error')),
    );
  }
}
