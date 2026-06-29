import 'package:flutter/material.dart';



import '../../design_system/design_system.dart';

import '../connections/connections_panel.dart';

import '../documents/document_list_panel.dart';

import '../folders/folders_panel.dart';



enum SourceCategory { pdfs, folders, chats }



/// Page for managing knowledge-base sources: uploaded PDFs and email connections.

class SourcesPage extends StatefulWidget {

  const SourcesPage({super.key});



  @override

  State<SourcesPage> createState() => _SourcesPageState();

}



class _SourcesPageState extends State<SourcesPage> {

  SourceCategory _category = SourceCategory.pdfs;



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);



    return Scaffold(

      body: Column(

        children: [

          AppFrostedBar(

            child: SizedBox(

              height: 52,

              child: Row(

                children: [

                  IconButton(

                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),

                    onPressed: () => Navigator.of(context).pop(),

                    tooltip: 'Back',

                  ),

                  const SizedBox(width: AppSpacing.xs),

                  Text('Sources', style: theme.textTheme.titleLarge),

                ],

              ),

            ),

          ),

          Padding(

            padding: const EdgeInsets.fromLTRB(

              AppSpacing.lg,

              AppSpacing.lg,

              AppSpacing.lg,

              0,

            ),

            child: AppSegmentedControl<SourceCategory>(

              segments: const [

                ButtonSegment(

                  value: SourceCategory.pdfs,

                  icon: Icon(Icons.picture_as_pdf_outlined, size: 18),

                  label: Text('PDFs'),

                ),

                ButtonSegment(

                  value: SourceCategory.folders,

                  icon: Icon(Icons.folder_outlined, size: 18),

                  label: Text('Folders'),

                ),

                ButtonSegment(

                  value: SourceCategory.chats,

                  icon: Icon(Icons.mail_outline, size: 18),

                  label: Text('Email'),

                ),

              ],

              selected: {_category},

              onSelectionChanged: (selection) {

                setState(() => _category = selection.first);

              },

            ),

          ),

          const SizedBox(height: AppSpacing.md),

          Expanded(

            child: AnimatedSwitcher(

              duration: const Duration(milliseconds: 250),

              switchInCurve: Curves.easeOutCubic,

              switchOutCurve: Curves.easeInCubic,

              child: switch (_category) {

                SourceCategory.pdfs => const DocumentListPanel(key: ValueKey('pdfs')),

                SourceCategory.folders => const FoldersPanel(key: ValueKey('folders')),

                SourceCategory.chats => const ConnectionsPanel(key: ValueKey('chats')),

              },

            ),

          ),

        ],

      ),

    );

  }

}

