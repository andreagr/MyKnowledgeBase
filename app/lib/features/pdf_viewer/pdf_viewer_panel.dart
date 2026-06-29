import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:url_launcher/url_launcher_string.dart';



import '../../core/api/api_client.dart';

import '../../core/models/document_item.dart';

import '../../core/utils/document_location.dart';

import '../../design_system/design_system.dart';

import '../../features/documents/documents_state.dart';



class PdfViewerPanel extends StatelessWidget {

  const PdfViewerPanel({super.key});



  @override

  Widget build(BuildContext context) {

    final documentsState = context.watch<DocumentsState>();

    final selectedDocument = documentsState.selectedDocument;

    final apiClient = context.read<ApiClient>();



    return AppSurface(

      elevated: true,

      padding: const EdgeInsets.all(AppSpacing.xl),

      child: Column(

        children: [

          AppPanelHeader(

            title: 'Preview',

            trailing: selectedDocument == null

                ? null

                : Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      if (!selectedDocument.isEmail)

                        IconButton(

                          icon: const Icon(Icons.folder_open_outlined, size: 20),

                          tooltip: 'Show in folder',

                          onPressed: () => openDocumentInFolder(

                            context,

                            apiClient,

                            selectedDocument.id,

                          ),

                        ),

                      IconButton(

                        icon: const Icon(Icons.open_in_new_rounded, size: 20),

                        tooltip: 'Open externally',

                        onPressed: () =>

                            _openExternal(context, apiClient, selectedDocument.id),

                      ),

                    ],

                  ),

          ),

          const SizedBox(height: AppSpacing.md),

          Expanded(child: _buildViewer(context, selectedDocument, apiClient)),

        ],

      ),

    );

  }



  Widget _buildViewer(BuildContext context, DocumentItem? selectedDocument, ApiClient apiClient) {

    if (selectedDocument == null) {

      return const AppEmptyState(

        icon: Icons.picture_as_pdf_outlined,

        title: 'No document selected',

        subtitle: 'Ask a question in chat, then select a source to preview it here.',

      );

    }



    final url = apiClient.getDownloadUrl(selectedDocument.id);

    return ClipRRect(

      borderRadius: AppRadii.lgAll,

      child: DecoratedBox(

        decoration: BoxDecoration(

          border: Border.all(color: AppColors.separatorLight),

          borderRadius: AppRadii.lgAll,

        ),

        child: SfPdfViewer.network(

          url,

          canShowScrollHead: false,

          canShowScrollStatus: true,

        ),

      ),

    );

  }



  Future<void> _openExternal(BuildContext context, ApiClient apiClient, String documentId) async {

    final url = apiClient.getDownloadUrl(documentId);

    await launchUrlString(url, mode: LaunchMode.externalApplication);

  }

}

