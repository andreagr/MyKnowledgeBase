import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import '../../core/models/connection_item.dart';

import '../../design_system/design_system.dart';

import '../documents/documents_state.dart';

import 'connections_state.dart';



class ConnectionsPanel extends StatefulWidget {

  const ConnectionsPanel({super.key});



  @override

  State<ConnectionsPanel> createState() => _ConnectionsPanelState();

}



class _ConnectionsPanelState extends State<ConnectionsPanel> {

  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      context.read<ConnectionsState>().refreshConnections();

    });

  }



  @override

  Widget build(BuildContext context) {

    final state = context.watch<ConnectionsState>();

    final documentsState = context.watch<DocumentsState>();



    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),

      child: AppSurface(

        elevated: true,

        padding: const EdgeInsets.all(AppSpacing.xl),

        child: Column(

          children: [

            AppPanelHeader(

              title: 'Email',

              subtitle: 'Connect an IMAP mailbox and sync messages into the knowledge base.',

              trailing: FilledButton.icon(

                icon: const Icon(Icons.add_rounded, size: 18),

                label: Text(state.isSaving ? 'Saving…' : 'Add connection'),

                onPressed: !documentsState.hasConnection || state.isSaving

                    ? null

                    : () => _showAddDialog(context),

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

    ConnectionsState state,

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



    if (state.connections.isEmpty) {

      return const AppEmptyState(

        icon: Icons.mail_outline_rounded,

        title: 'No email connections',

        subtitle: 'Add an IMAP account (Gmail, Outlook, etc.) to index your emails.',

      );

    }



    return ListView.separated(

      itemCount: state.connections.length,

      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),

      itemBuilder: (context, index) {

        final connection = state.connections[index];

        final isSyncing = state.syncingConnectionId == connection.id;

        return _ConnectionTile(

          connection: connection,

          isSyncing: isSyncing,

          onSync: () => _syncConnection(context, connection),

          onTest: () => _testConnection(context, connection),

          onDelete: () => _deleteConnection(context, connection),

        );

      },

    );

  }



  Future<void> _showAddDialog(BuildContext context) async {

    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController();

    final hostController = TextEditingController(text: 'imap.gmail.com');

    final portController = TextEditingController(text: '993');

    final usernameController = TextEditingController();

    final passwordController = TextEditingController();

    final folderController = TextEditingController(text: 'INBOX');



    final result = await showDialog<bool>(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          title: const Text('Add email connection'),

          content: SizedBox(

            width: 420,

            child: Form(

              key: formKey,

              child: SingleChildScrollView(

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    TextFormField(

                      controller: nameController,

                      decoration: const InputDecoration(labelText: 'Connection name'),

                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,

                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextFormField(

                      controller: hostController,

                      decoration: const InputDecoration(

                        labelText: 'IMAP host',

                        hintText: 'imap.gmail.com',

                      ),

                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,

                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextFormField(

                      controller: portController,

                      decoration: const InputDecoration(labelText: 'Port'),

                      keyboardType: TextInputType.number,

                      validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid port' : null,

                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextFormField(

                      controller: usernameController,

                      decoration: const InputDecoration(

                        labelText: 'Email / username',

                      ),

                      keyboardType: TextInputType.emailAddress,

                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,

                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextFormField(

                      controller: passwordController,

                      decoration: const InputDecoration(

                        labelText: 'Password / app password',

                      ),

                      obscureText: true,

                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,

                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextFormField(

                      controller: folderController,

                      decoration: const InputDecoration(labelText: 'Folder'),

                    ),

                  ],

                ),

              ),

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(dialogContext, false),

              child: const Text('Cancel'),

            ),

            FilledButton(

              onPressed: () {

                if (formKey.currentState?.validate() ?? false) {

                  Navigator.pop(dialogContext, true);

                }

              },

              child: const Text('Save'),

            ),

          ],

        );

      },

    );



    if (result != true || !context.mounted) return;



    final connectionsState = context.read<ConnectionsState>();

    final success = await connectionsState.addConnection(

      EmailConnectionRequest(

        name: nameController.text.trim(),

        host: hostController.text.trim(),

        port: int.parse(portController.text.trim()),

        username: usernameController.text.trim(),

        password: passwordController.text,

        folder: folderController.text.trim().isEmpty

            ? 'INBOX'

            : folderController.text.trim(),

      ),

    );



    if (!context.mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          success

              ? 'Email connection added.'

              : connectionsState.errorMessage ?? 'Failed to add connection.',

        ),

      ),

    );

  }



  Future<void> _syncConnection(BuildContext context, ConnectionItem connection) async {

    final connectionsState = context.read<ConnectionsState>();

    final documentsState = context.read<DocumentsState>();



    final result = await connectionsState.syncConnection(connection.id);

    if (!context.mounted) return;



    if (result != null) {

      await documentsState.refreshDocuments();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(result.message)),

      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(connectionsState.errorMessage ?? 'Sync failed.'),

        ),

      );

    }

  }



  Future<void> _testConnection(BuildContext context, ConnectionItem connection) async {

    final connectionsState = context.read<ConnectionsState>();

    final success = await connectionsState.testConnection(connection.id);

    if (!context.mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          success

              ? 'Connection to ${connection.name} is working.'

              : connectionsState.errorMessage ?? 'Connection test failed.',

        ),

      ),

    );

  }



  Future<void> _deleteConnection(BuildContext context, ConnectionItem connection) async {

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (dialogContext) => AlertDialog(

        title: const Text('Delete connection'),

        content: Text('Remove "${connection.name}"? Indexed emails will remain in the knowledge base.'),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(dialogContext, false),

            child: const Text('Cancel'),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(dialogContext, true),

            child: const Text('Delete'),

          ),

        ],

      ),

    );



    if (confirmed != true || !context.mounted) return;



    final connectionsState = context.read<ConnectionsState>();

    final success = await connectionsState.deleteConnection(connection.id);

    if (!context.mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          success ? 'Connection deleted.' : connectionsState.errorMessage ?? 'Delete failed.',

        ),

      ),

    );

  }

}



class _ConnectionTile extends StatelessWidget {

  final ConnectionItem connection;

  final bool isSyncing;

  final VoidCallback onSync;

  final VoidCallback onTest;

  final VoidCallback onDelete;



  const _ConnectionTile({

    required this.connection,

    required this.isSyncing,

    required this.onSync,

    required this.onTest,

    required this.onDelete,

  });



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final statusColor = connection.lastSyncStatus == 'ok'

        ? AppColors.success

        : connection.lastSyncStatus == 'error'

            ? AppColors.error

            : AppColors.textTertiary;



    return Container(

      decoration: BoxDecoration(

        color: AppColors.surfaceElevated,

        borderRadius: AppRadii.lgAll,

        border: Border.all(color: AppColors.separatorLight),

      ),

      padding: const EdgeInsets.all(AppSpacing.lg),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 40,

                height: 40,

                decoration: BoxDecoration(

                  color: AppColors.accentMuted,

                  borderRadius: AppRadii.mdAll,

                ),

                child: const Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.accent),

              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(connection.name, style: theme.textTheme.titleMedium),

                    const SizedBox(height: AppSpacing.xs),

                    Text(

                      '${connection.username} · ${connection.host}:${connection.port}',

                      style: theme.textTheme.bodySmall,

                    ),

                  ],

                ),

              ),

              IconButton(

                onPressed: onTest,

                icon: const Icon(Icons.wifi_tethering_rounded, size: 20),

                tooltip: 'Test connection',

              ),

              IconButton(

                onPressed: isSyncing ? null : onSync,

                icon: isSyncing

                    ? const SizedBox(

                        width: 20,

                        height: 20,

                        child: CircularProgressIndicator(strokeWidth: 2),

                      )

                    : const Icon(Icons.sync_rounded, size: 20),

                tooltip: 'Sync emails',

              ),

              IconButton(

                onPressed: onDelete,

                icon: const Icon(Icons.delete_outline_rounded, size: 20),

                tooltip: 'Delete',

              ),

            ],

          ),

          const SizedBox(height: AppSpacing.md),

          Wrap(

            spacing: AppSpacing.sm,

            runSpacing: AppSpacing.xs,

            children: [

              AppChip(label: connection.folder),

              AppChip(label: '${connection.indexedCount} indexed'),

              if (connection.lastSyncAt != null)

                AppChip(

                  label: 'Last sync: ${_formatDate(connection.lastSyncAt!)}',

                  color: statusColor,

                ),

            ],

          ),

          if (connection.lastSyncMessage != null && connection.lastSyncMessage!.isNotEmpty) ...[

            const SizedBox(height: AppSpacing.sm),

            Text(

              connection.lastSyncMessage!,

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

