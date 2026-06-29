import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';



import '../../core/api/api_client.dart';

import '../../core/models/chat_models.dart';

import '../../core/utils/open_location.dart';

import '../../design_system/design_system.dart';

import '../../features/chat/chat_state.dart';

import '../../features/documents/documents_state.dart';



class ChatPanel extends StatefulWidget {

  const ChatPanel({super.key});



  @override

  State<ChatPanel> createState() => _ChatPanelState();

}



class _ChatPanelState extends State<ChatPanel> {

  final TextEditingController _controller = TextEditingController();

  late final FocusNode _composerFocusNode = FocusNode(onKeyEvent: _handleComposerKeyEvent);



  @override

  void dispose() {

    _controller.dispose();

    _composerFocusNode.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final chatState = context.watch<ChatState>();

    final documentsState = context.watch<DocumentsState>();

    final errorMessage = chatState.errorMessage;



    return AppSurface(

      elevated: true,

      padding: const EdgeInsets.all(AppSpacing.xl),

      child: Column(

        children: [

          AppPanelHeader(

            title: 'Chat',

            subtitle: 'Global knowledge base',

          ),

          const SizedBox(height: AppSpacing.lg),

          Expanded(child: _buildChatBody(context, chatState, documentsState)),

          const SizedBox(height: AppSpacing.md),

          _buildComposer(context, chatState),

          if (errorMessage != null) ...[

            const SizedBox(height: AppSpacing.md),

            Text(

              errorMessage,

              style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                    color: AppColors.error,

                  ),

            ),

          ],

        ],

      ),

    );

  }



  Widget _buildChatBody(BuildContext context, ChatState chatState, DocumentsState documentsState) {

    if (!documentsState.hasConnection) {

      return const AppEmptyState(

        icon: Icons.cloud_off_outlined,

        title: 'Backend unavailable',

        subtitle: 'Chat requires a running service. Check your connection and refresh.',

      );

    }



    if (chatState.messages.isEmpty) {

      return const AppEmptyState(

        icon: Icons.chat_bubble_outline_rounded,

        title: 'Start a conversation',

        subtitle: 'Ask a question about your uploaded company documents.',

      );

    }



    return ListView.separated(

      itemCount: chatState.messages.length,

      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),

      itemBuilder: (context, index) {

        final message = chatState.messages[index];

        return _ChatMessageTile(

          message: message,

          selectedSource: chatState.selectedSource,

          onSourceTap: (source) {

            chatState.selectSource(source);

            documentsState.selectDocument(source.documentId);

          },

          onOpenLocation: (location) => _openLocation(context, location),

        );

      },

    );

  }



  Widget _buildComposer(BuildContext context, ChatState chatState) {

    return Container(

      decoration: BoxDecoration(

        color: AppColors.surfaceMuted,

        borderRadius: AppRadii.lgAll,

        border: Border.all(color: AppColors.separatorLight),

      ),

      padding: const EdgeInsets.fromLTRB(

        AppSpacing.lg,

        AppSpacing.sm,

        AppSpacing.sm,

        AppSpacing.sm,

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.end,

        children: [

          Expanded(

            child: TextField(

              controller: _controller,

              focusNode: _composerFocusNode,

              minLines: 1,

              maxLines: 4,

              decoration: const InputDecoration(

                hintText: 'Ask a question…',

                border: InputBorder.none,

                enabledBorder: InputBorder.none,

                focusedBorder: InputBorder.none,

                filled: false,

                contentPadding: EdgeInsets.symmetric(

                  horizontal: AppSpacing.xs,

                  vertical: AppSpacing.sm,

                ),

              ),

              style: Theme.of(context).textTheme.bodyLarge,

              enabled: !chatState.isSending,

            ),

          ),

          const SizedBox(width: AppSpacing.sm),

          FilledButton(

            onPressed: chatState.isSending ? null : () => _submitQuestion(chatState),

            style: FilledButton.styleFrom(

              minimumSize: const Size(44, 44),

              padding: EdgeInsets.zero,

              shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),

            ),

            child: chatState.isSending

                ? const SizedBox(

                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(

                      strokeWidth: 2,

                      color: AppColors.textOnAccent,

                    ),

                  )

                : const Icon(Icons.arrow_upward_rounded, size: 20),

          ),

        ],

      ),

    );

  }



  KeyEventResult _handleComposerKeyEvent(FocusNode node, KeyEvent event) {

    if (event is! KeyDownEvent) return KeyEventResult.ignored;



    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||

        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (!isEnter || HardwareKeyboard.instance.isShiftPressed) {

      return KeyEventResult.ignored;

    }



    if (!mounted) return KeyEventResult.handled;



    final chatState = context.read<ChatState>();

    if (!chatState.isSending) {

      _submitQuestion(chatState);

    }

    return KeyEventResult.handled;

  }



  Future<void> _submitQuestion(ChatState chatState) async {

    final question = _controller.text.trim();

    if (question.isEmpty) return;



    final success = await chatState.askQuestion(question);

    if (!mounted) return;

    if (success) {

      _controller.clear();

      FocusScope.of(context).unfocus();

    }

  }



  Future<void> _openLocation(BuildContext context, FileLocation location) async {

    final apiClient = context.read<ApiClient>();



    try {

      final resolved = await apiClient.getDocumentLocation(location.documentId);



      if (resolved.canOpenFolder && resolved.folderPath != null) {

        final error = await LocationOpener.openFolder(resolved.folderPath!);

        if (!context.mounted) return;

        if (error != null) {

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));

        }

        return;

      }



      if (resolved.filePath != null) {

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

}



class _ChatMessageTile extends StatelessWidget {

  final ChatMessage message;

  final SourceChunk? selectedSource;

  final ValueChanged<SourceChunk> onSourceTap;

  final ValueChanged<FileLocation> onOpenLocation;



  const _ChatMessageTile({

    required this.message,

    required this.selectedSource,

    required this.onSourceTap,

    required this.onOpenLocation,

  });



  @override

  Widget build(BuildContext context) {

    final isUser = message.role == ChatRole.user;

    final theme = Theme.of(context);



    return Align(

      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,

      child: ConstrainedBox(

        constraints: const BoxConstraints(maxWidth: 760),

        child: Column(

          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,

          children: [

            Container(

              decoration: BoxDecoration(

                color: isUser ? AppColors.userBubble : AppColors.assistantBubble,

                borderRadius: BorderRadius.only(

                  topLeft: const Radius.circular(AppRadii.lg),

                  topRight: const Radius.circular(AppRadii.lg),

                  bottomLeft: Radius.circular(isUser ? AppRadii.lg : AppRadii.xs),

                  bottomRight: Radius.circular(isUser ? AppRadii.xs : AppRadii.lg),

                ),

              ),

              padding: const EdgeInsets.symmetric(

                horizontal: AppSpacing.lg,

                vertical: AppSpacing.md,

              ),

              child: Text(

                message.text,

                style: theme.textTheme.bodyLarge?.copyWith(

                  color: isUser ? AppColors.textOnAccent : AppColors.textPrimary,

                  height: 1.5,

                ),

              ),

            ),

            if (message.fileLocations.isNotEmpty) ...[

              const SizedBox(height: AppSpacing.md),

              _FileLocationsSection(

                locations: message.fileLocations,

                onOpenLocation: onOpenLocation,

              ),

            ],

            if (message.sources.isNotEmpty) ...[

              const SizedBox(height: AppSpacing.md),

              ...message.sources.map((source) {

                final highlighted = selectedSource == source;

                return GestureDetector(

                  onTap: () => onSourceTap(source),

                  child: AnimatedContainer(

                    duration: const Duration(milliseconds: 200),

                    curve: Curves.easeOutCubic,

                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),

                    padding: const EdgeInsets.all(AppSpacing.lg),

                    decoration: BoxDecoration(

                      color: highlighted ? AppColors.sourceHighlight : AppColors.surface,

                      borderRadius: AppRadii.lgAll,

                      border: Border.all(

                        color: highlighted ? AppColors.accent : AppColors.separatorLight,

                        width: highlighted ? 1.5 : 1,

                      ),

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Row(

                          children: [

                            Expanded(

                              child: Text(source.filename, style: theme.textTheme.titleSmall),

                            ),

                            AppChip(label: 'p. ${source.page}'),

                          ],

                        ),

                        const SizedBox(height: AppSpacing.sm),

                        Text(

                          source.text,

                          style: theme.textTheme.bodyMedium?.copyWith(

                            color: AppColors.textSecondary,

                          ),

                          maxLines: 3,

                          overflow: TextOverflow.ellipsis,

                        ),

                        const SizedBox(height: AppSpacing.md),

                        Row(

                          children: [

                            AppChip(

                              label: 'Score ${source.score.toStringAsFixed(2)}',

                              highlighted: highlighted,

                            ),

                            const SizedBox(width: AppSpacing.sm),

                            if (source.sourceType != 'email')

                              TextButton.icon(

                                onPressed: () => onOpenLocation(

                                  FileLocation(

                                    documentId: source.documentId,

                                    filename: source.filename,

                                    sourceType: source.sourceType,

                                    filePath: source.filePath,

                                    folderPath: source.folderPath,

                                    canOpenFolder: source.canOpenFolder,

                                  ),

                                ),

                                icon: const Icon(Icons.folder_open_rounded, size: 16),

                                label: const Text('Open folder'),

                              )

                            else

                              Text(

                                'Tap to select document',

                                style: theme.textTheme.bodySmall,

                              ),

                          ],

                        ),

                      ],

                    ),

                  ),

                );

              }),

            ],

          ],

        ),

      ),

    );

  }

}



class _FileLocationsSection extends StatelessWidget {

  final List<FileLocation> locations;

  final ValueChanged<FileLocation> onOpenLocation;



  const _FileLocationsSection({

    required this.locations,

    required this.onOpenLocation,

  });



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);



    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(AppSpacing.lg),

      decoration: BoxDecoration(

        color: AppColors.surfaceMuted,

        borderRadius: AppRadii.lgAll,

        border: Border.all(color: AppColors.separatorLight),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(Icons.folder_outlined, size: 16, color: AppColors.textSecondary),

              const SizedBox(width: AppSpacing.sm),

              Text('Related files', style: theme.textTheme.titleSmall),

            ],

          ),

          const SizedBox(height: AppSpacing.md),

          ...locations.map((location) {

            final isEmail = location.sourceType == 'email';

            final pathLabel = location.folderPath ?? location.filePath ?? location.filename;

            return Padding(

              padding: const EdgeInsets.only(bottom: AppSpacing.sm),

              child: InkWell(

                onTap: isEmail ? null : () => onOpenLocation(location),

                borderRadius: AppRadii.smAll,

                child: Padding(

                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),

                  child: Row(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Icon(

                        isEmail ? Icons.mail_outline_rounded : Icons.folder_open_rounded,

                        size: 16,

                        color: isEmail ? AppColors.textTertiary : AppColors.accent,

                      ),

                      const SizedBox(width: AppSpacing.sm),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              isEmail ? location.filename : 'Open folder: ${location.filename}',

                              style: theme.textTheme.bodyMedium?.copyWith(

                                color: isEmail ? AppColors.textSecondary : AppColors.accent,

                                decoration: isEmail ? null : TextDecoration.underline,

                                decorationColor: AppColors.accent,

                              ),

                            ),

                            if (pathLabel.isNotEmpty) ...[

                              const SizedBox(height: 2),

                              Text(

                                pathLabel,

                                style: theme.textTheme.bodySmall,

                              ),

                            ],

                          ],

                        ),

                      ),

                    ],

                  ),

                ),

              ),

            );

          }),

        ],

      ),

    );

  }

}

