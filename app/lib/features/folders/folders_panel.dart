import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/folder_item.dart';
import '../../core/utils/open_location.dart';
import '../../design_system/design_system.dart';
import '../documents/documents_state.dart';
import 'folders_state.dart';

class FoldersPanel extends StatefulWidget {
  const FoldersPanel({super.key});

  @override
  State<FoldersPanel> createState() => _FoldersPanelState();
}

class _FoldersPanelState extends State<FoldersPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FoldersState>().refreshFolders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FoldersState>();
    final documentsState = context.watch<DocumentsState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppSurface(
        elevated: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            AppPanelHeader(
              title: 'Folders',
              subtitle: 'Watch folders on your PC. PDFs are indexed in place — no copying needed.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.folders.isNotEmpty)
                    TextButton.icon(
                      onPressed: !documentsState.hasConnection || state.isScanningAll
                          ? null
                          : () => _scanAll(context),
                      icon: state.isScanningAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Scan all'),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(state.isSaving ? 'Adding…' : 'Add folder'),
                    onPressed: !documentsState.hasConnection || state.isSaving
                        ? null
                        : () => _addFolder(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildContent(context, state, documentsState)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FoldersState state,
    DocumentsState documentsState,
  ) {
    if (!documentsState.hasConnection) {
      return const AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Backend unavailable',
        subtitle: 'Check your backend service and tap refresh in the app bar.',
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.folders.isEmpty) {
      return const AppEmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No folders watched',
        subtitle: 'Add one or more folders and scan them to index PDFs where they already live.',
      );
    }

    return ListView.separated(
      itemCount: state.folders.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final folder = state.folders[index];
        final isScanning = state.scanningFolderId == folder.id;
        return _FolderTile(
          folder: folder,
          isScanning: isScanning,
          onScan: () => _scanFolder(context, folder),
          onOpen: () => LocationOpener.openFolder(folder.path),
          onDelete: () => _deleteFolder(context, folder),
        );
      },
    );
  }

  Future<void> _addFolder(BuildContext context) async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a folder to watch',
    );
    if (picked == null || !context.mounted) return;

    final name = picked.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).lastOrNull ?? picked;
    final foldersState = context.read<FoldersState>();
    final success = await foldersState.addFolder(
      FolderCreateRequest(name: name, path: picked, recursive: true),
    );

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder added. Tap Scan to index PDFs.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(foldersState.errorMessage ?? 'Failed to add folder.')),
      );
    }
  }

  Future<void> _scanFolder(BuildContext context, FolderItem folder) async {
    final foldersState = context.read<FoldersState>();
    final documentsState = context.read<DocumentsState>();

    final result = await foldersState.scanFolder(folder.id);
    if (!context.mounted) return;

    if (result != null) {
      await documentsState.refreshDocuments();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(foldersState.errorMessage ?? 'Scan failed.')),
      );
    }
  }

  Future<void> _scanAll(BuildContext context) async {
    final foldersState = context.read<FoldersState>();
    final documentsState = context.read<DocumentsState>();

    final result = await foldersState.scanAllFolders();
    if (!context.mounted) return;

    if (result != null) {
      await documentsState.refreshDocuments();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(foldersState.errorMessage ?? 'Scan failed.')),
      );
    }
  }

  Future<void> _deleteFolder(BuildContext context, FolderItem folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove folder'),
        content: Text(
          'Stop watching "${folder.name}"? Already indexed PDFs stay in the knowledge base.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final foldersState = context.read<FoldersState>();
    final success = await foldersState.deleteFolder(folder.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Folder removed.' : foldersState.errorMessage ?? 'Remove failed.'),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final FolderItem folder;
  final bool isScanning;
  final VoidCallback onScan;
  final Future<String?> Function() onOpen;
  final VoidCallback onDelete;

  const _FolderTile({
    required this.folder,
    required this.isScanning,
    required this.onScan,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = folder.lastScanStatus == 'ok'
        ? Colors.green.shade700
        : folder.lastScanStatus == 'error'
            ? Colors.red.shade700
            : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      folder.path,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final error = await onOpen();
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded),
                tooltip: 'Open folder',
              ),
              IconButton(
                onPressed: isScanning ? null : onScan,
                icon: isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                tooltip: 'Scan folder',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Chip(label: folder.recursive ? 'Recursive' : 'Top level only'),
              _Chip(label: '${folder.indexedCount} indexed'),
              if (folder.lastScanAt != null)
                _Chip(
                  label: 'Last scan: ${_formatDate(folder.lastScanAt!)}',
                  color: statusColor,
                ),
            ],
          ),
          if (folder.lastScanMessage != null && folder.lastScanMessage!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              folder.lastScanMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;

  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
