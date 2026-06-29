import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import '../app/branding.dart';
import '../app/config.dart';
import '../core/backend/backend_launcher.dart';

import '../core/api/api_client.dart';

import '../core/widgets/status_badge.dart';

import '../design_system/design_system.dart';

import '../features/chat/chat_panel.dart';

import '../features/chat/chat_state.dart';

import '../features/connections/connections_state.dart';

import '../features/documents/documents_state.dart';

import '../features/folders/folders_state.dart';

import '../features/intelligence/intelligence_page.dart';

import '../features/intelligence/intelligence_state.dart';

import '../features/pdf_viewer/pdf_viewer_panel.dart';

import '../features/sources/sources_page.dart';



/// Root application widget that wires state providers and global app shell.

class App extends StatefulWidget {

  const App({super.key, this.launcher});



  final BackendLauncher? launcher;



  @override

  State<App> createState() => _AppState();

}



class _AppState extends State<App> with WidgetsBindingObserver {

  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    widget.launcher?.stop();

    super.dispose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.detached) {

      widget.launcher?.stop();

    }

  }



  @override

  Widget build(BuildContext context) {

    return MultiProvider(

      providers: [

        Provider<ApiClient>(create: (_) => ApiClient(baseUrl: effectiveBackendBaseUrl)),

        ChangeNotifierProvider<DocumentsState>(

          create: (context) => DocumentsState(context.read<ApiClient>())..initialize(),

        ),

        ChangeNotifierProvider<ChatState>(

          create: (context) => ChatState(context.read<ApiClient>()),

        ),

        ChangeNotifierProvider<ConnectionsState>(

          create: (context) => ConnectionsState(context.read<ApiClient>()),

        ),

        ChangeNotifierProvider<FoldersState>(

          create: (context) => FoldersState(context.read<ApiClient>()),

        ),

        ChangeNotifierProvider<IntelligenceState>(

          create: (context) => IntelligenceState(context.read<ApiClient>())..initialize(),

        ),

      ],

      child: MaterialApp(

        title: AppBranding.name,

        debugShowCheckedModeBanner: false,

        theme: buildAppTheme(),

        home: const AppShell(),

      ),

    );

  }

}



class AppShell extends StatefulWidget {

  const AppShell({super.key});



  @override

  State<AppShell> createState() => _AppShellState();

}



class _AppShellState extends State<AppShell> {
  Future<void> _refreshStatus() async {
    final documentsState = context.read<DocumentsState>();
    final intelligenceState = context.read<IntelligenceState>();
    await documentsState.refreshHealthStatus();
    if (!mounted) return;
    if (documentsState.hasConnection) {
      await intelligenceState.refreshAll();
    }
  }

  void _openSources() {

    Navigator.of(context).push(

      MaterialPageRoute<void>(builder: (_) => const SourcesPage()),

    );

  }



  void _openIntelligence() {

    Navigator.of(context).push(

      MaterialPageRoute<void>(builder: (_) => const IntelligencePage()),

    );

  }



  @override

  Widget build(BuildContext context) {

    final documentsState = context.watch<DocumentsState>();
    final intelligenceState = context.watch<IntelligenceState>();

    final healthStatus = documentsState.healthStatus;

    final isOffline = !healthStatus.healthy;
    final isLlmReady = !isOffline && intelligenceState.isLlmReady;

    final theme = Theme.of(context);



    return Scaffold(

      body: Column(

        children: [

          AppFrostedBar(

            child: SizedBox(

              height: 52,

              child: Row(

                children: [

                  Image.asset(AppBranding.iconAsset, width: 28, height: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Text(AppBranding.name, style: theme.textTheme.titleLarge),

                  const Spacer(),

                  TextButton.icon(

                    onPressed: _openSources,

                    icon: const Icon(Icons.folder_copy_outlined, size: 18),

                    label: const Text('Sources'),

                  ),

                  const SizedBox(width: AppSpacing.xs),

                  TextButton.icon(

                    onPressed: _openIntelligence,

                    icon: const Icon(Icons.psychology_outlined, size: 18),

                    label: const Text('Intelligence'),

                  ),

                  const SizedBox(width: AppSpacing.xs),

                  if (documentsState.isCheckingHealth || intelligenceState.isLoading)

                    const SizedBox(

                      width: 32,

                      height: 32,

                      child: Padding(

                        padding: EdgeInsets.all(6),

                        child: CircularProgressIndicator(strokeWidth: 2),

                      ),

                    )

                  else

                    IconButton(

                      icon: const Icon(Icons.refresh_rounded, size: 20),

                      tooltip: 'Refresh connection status',

                      onPressed: _refreshStatus,

                    ),

                  const SizedBox(width: AppSpacing.sm),

                  StatusBadge(

                    healthy: !isOffline,

                    label: healthStatus.message,

                  ),

                  const SizedBox(width: AppSpacing.sm),

                  StatusBadge(

                    healthy: isLlmReady,

                    label: isOffline
                        ? 'LLM offline'
                        : intelligenceState.statusLabel,

                  ),

                ],

              ),

            ),

          ),

          Expanded(

            child: LayoutBuilder(

              builder: (context, constraints) {

                final useVerticalLayout = constraints.maxWidth < 720;



                final chat = const Expanded(flex: 2, child: ChatPanel());

                final preview = const Expanded(flex: 1, child: PdfViewerPanel());

                final gap = useVerticalLayout

                    ? const SizedBox(height: AppSpacing.md)

                    : const SizedBox(width: AppSpacing.md);



                return Padding(

                  padding: const EdgeInsets.fromLTRB(

                    AppSpacing.lg,

                    AppSpacing.md,

                    AppSpacing.lg,

                    AppSpacing.lg,

                  ),

                  child: useVerticalLayout

                      ? Column(children: [chat, gap, preview])

                      : Row(children: [chat, gap, preview]),

                );

              },

            ),

          ),

        ],

      ),

    );

  }

}

