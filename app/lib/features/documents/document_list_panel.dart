import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher_string.dart';



import '../../core/api/api_client.dart';

import '../../core/models/document_item.dart';

import '../../core/utils/document_location.dart';

import '../../design_system/design_system.dart';

import '../../features/documents/documents_state.dart';



class DocumentListPanel extends StatelessWidget {

  const DocumentListPanel({super.key});



  @override

  Widget build(BuildContext context) {

    final state = context.watch<DocumentsState>();

    final apiClient = context.read<ApiClient>();



    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),

      child: AppSurface(

        elevated: true,

        padding: const EdgeInsets.all(AppSpacing.xl),

        child: Column(

          children: [

            AppPanelHeader(

              title: 'Documents',

              subtitle: 'Upload PDFs or sync emails and browse indexed content.',

              trailing: FilledButton.icon(

                icon: const Icon(Icons.upload_file_rounded, size: 18),

                label: Text(state.isUploading ? 'Uploading…' : 'Upload PDF'),

                onPressed: state.isUploading ? null : () => _pickDocument(context, state),

              ),

            ),

            if (state.documents.isNotEmpty) ...[

              const SizedBox(height: AppSpacing.md),

              AppSegmentedControl<DocumentSortOrder>(

                segments: const [

                  ButtonSegment(

                    value: DocumentSortOrder.newestFirst,

                    icon: Icon(Icons.arrow_downward_rounded, size: 16),

                    label: Text('Newest'),

                  ),

                  ButtonSegment(

                    value: DocumentSortOrder.oldestFirst,

                    icon: Icon(Icons.arrow_upward_rounded, size: 16),

                    label: Text('Oldest'),

                  ),

                ],

                selected: {state.sortOrder},

                onSelectionChanged: (selection) {

                  state.setSortOrder(selection.first);

                },

              ),

            ],

            const SizedBox(height: AppSpacing.lg),

            Expanded(child: _buildContent(context, state, apiClient)),

          ],

        ),

      ),

    );

  }



  Widget _buildContent(BuildContext context, DocumentsState state, ApiClient apiClient) {

    if (!state.hasConnection) {

      return const AppEmptyState(

        icon: Icons.cloud_off_outlined,

        title: 'Backend unavailable',

        subtitle: 'Check your backend service and tap refresh in the app bar.',

      );

    }



    if (state.isLoading) {

      return const Center(child: CircularProgressIndicator());

    }



    if (state.documents.isEmpty) {

      return const AppEmptyState(

        icon: Icons.insert_drive_file_outlined,

        title: 'No documents yet',

        subtitle: 'Use the upload button above to add company PDFs.',

      );

    }



    final documents = state.paginatedDocuments;



    return Column(

      children: [

        Expanded(

          child: ListView.separated(

            itemCount: documents.length,

            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),

            itemBuilder: (context, index) {

              final document = documents[index];

              return _DocumentTile(

                document: document,

                selected: state.selectedDocument?.id == document.id,

                onTap: () => state.selectDocument(document.id),

                onOpen: document.isEmail ? null : () => _openDocument(context, apiClient, document),

                onShowInFolder: document.isEmail
                    ? null
                    : () => openDocumentInFolder(context, apiClient, document.id),

                onDelete: () => _removeDocument(context, state, document),

              );

            },

          ),

        ),

        if (state.hasMultiplePages) ...[

          const SizedBox(height: AppSpacing.md),

          _DocumentPaginationBar(state: state),

        ],

      ],

    );

  }



  Future<void> _pickDocument(BuildContext context, DocumentsState state) async {

    final result = await FilePicker.platform.pickFiles(

      type: FileType.custom,

      allowedExtensions: ['pdf'],

      allowMultiple: false,

      withData: true,

    );



    if (result == null || result.files.isEmpty) {

      return;

    }



    final file = result.files.first;

    final success = await state.uploadPdf(file);

    if (!context.mounted) return;



    if (success) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('PDF uploaded successfully.')),

      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(state.errorMessage ?? 'Upload failed.')),

      );

    }

  }



  Future<void> _openDocument(BuildContext context, ApiClient apiClient, DocumentItem document) async {

    final url = apiClient.getDownloadUrl(document.id);

    await launchUrlString(url, mode: LaunchMode.externalApplication);

  }



  Future<void> _removeDocument(

    BuildContext context,

    DocumentsState state,

    DocumentItem document,

  ) async {

    final keepOriginal = document.isFolder || document.isEmail;

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (dialogContext) => AlertDialog(

        title: const Text('Remove from index'),

        content: Text(

          keepOriginal

              ? '"${document.filename}" will be removed from the knowledge base. '

                  'The original file on your PC is not deleted.'

              : '"${document.filename}" will be removed from the knowledge base '

                  'and its uploaded copy will be deleted.',

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



    final success = await state.removeDocument(document.id);

    if (!context.mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          success

              ? 'Document removed from index.'

              : state.errorMessage ?? 'Remove failed.',

        ),

      ),

    );

  }

}



class _DocumentPaginationBar extends StatelessWidget {

  final DocumentsState state;



  const _DocumentPaginationBar({required this.state});



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final page = state.currentPage + 1;

    final total = state.totalPages;



    return Row(

      children: [

        IconButton(

          onPressed: state.currentPage > 0 ? () => state.setPage(state.currentPage - 1) : null,

          icon: const Icon(Icons.chevron_left_rounded),

          tooltip: 'Previous page',

        ),

        Expanded(

          child: Text(

            'Page $page of $total',

            textAlign: TextAlign.center,

            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),

          ),

        ),

        IconButton(

          onPressed: state.currentPage < total - 1

              ? () => state.setPage(state.currentPage + 1)

              : null,

          icon: const Icon(Icons.chevron_right_rounded),

          tooltip: 'Next page',

        ),

      ],

    );

  }

}



class _DocumentTile extends StatelessWidget {

  final DocumentItem document;

  final bool selected;

  final VoidCallback onTap;

  final VoidCallback? onOpen;

  final VoidCallback? onShowInFolder;

  final VoidCallback? onDelete;



  const _DocumentTile({

    required this.document,

    required this.selected,

    required this.onTap,

    this.onOpen,

    this.onShowInFolder,

    this.onDelete,

  });



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);



    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: AppRadii.lgAll,

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 200),

          curve: Curves.easeOutCubic,

          decoration: BoxDecoration(

            color: selected ? AppColors.sourceHighlight : AppColors.surfaceElevated,

            borderRadius: AppRadii.lgAll,

            border: Border.all(

              color: selected ? AppColors.accent : AppColors.separatorLight,

              width: selected ? 1.5 : 1,

            ),

          ),

          padding: const EdgeInsets.symmetric(

            vertical: AppSpacing.lg,

            horizontal: AppSpacing.lg,

          ),

          child: Row(

            children: [

              Container(

                width: 40,

                height: 40,

                decoration: BoxDecoration(

                  color: document.isEmail

                      ? AppColors.accentMuted

                      : AppColors.surfaceMuted,

                  borderRadius: AppRadii.mdAll,

                ),

                child: Icon(

                  document.isEmail

                      ? Icons.mail_outline_rounded

                      : Icons.picture_as_pdf_outlined,

                  size: 20,

                  color: document.isEmail ? AppColors.accent : AppColors.textSecondary,

                ),

              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(document.filename, style: theme.textTheme.titleMedium),

                    if (document.indexedAt != null) ...[

                      const SizedBox(height: AppSpacing.xs),

                      Text(

                        'Added ${_formatDate(document.indexedAt!)}',

                        style: theme.textTheme.bodySmall?.copyWith(

                          color: AppColors.textSecondary,

                        ),

                      ),

                    ],

                    const SizedBox(height: AppSpacing.sm),

                    Wrap(

                      spacing: AppSpacing.sm,

                      runSpacing: AppSpacing.xs,

                      children: [

                        if (document.isEmail)

                          const AppChip(label: 'Email', highlighted: true)

                        else if (document.isFolder)

                          const AppChip(label: 'Folder', highlighted: true)

                        else

                          AppChip(label: '${document.pages} pages'),

                        AppChip(label: '${document.chunks} chunks'),

                        if (document.broken)

                          const AppChip(label: 'Broken', highlighted: true),

                      ],

                    ),

                  ],

                ),

              ),

              if (onShowInFolder != null)

                IconButton(

                  onPressed: onShowInFolder,

                  icon: const Icon(Icons.folder_open_rounded, size: 20),

                  tooltip: 'Show in folder',

                ),

              if (onOpen != null)

                IconButton(

                  onPressed: onOpen,

                  icon: const Icon(Icons.open_in_new_rounded, size: 20),

                  tooltip: 'Open PDF',

                ),

              if (onDelete != null)

                IconButton(

                  onPressed: onDelete,

                  icon: const Icon(Icons.delete_outline_rounded, size: 20),

                  tooltip: 'Remove from index',

                ),

            ],

          ),

        ),

      ),

    );

  }



  String _formatDate(DateTime date) {

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'

        '${local.month.toString().padLeft(2, '0')}/'

        '${local.year} '

        '${local.hour.toString().padLeft(2, '0')}:'

        '${local.minute.toString().padLeft(2, '0')}';

  }

}

