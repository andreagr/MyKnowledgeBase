import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/intelligence_config.dart';
import '../../design_system/design_system.dart';
import '../documents/documents_state.dart';
import 'intelligence_api_tab.dart';
import 'intelligence_privacy_dialog.dart';
import 'intelligence_state.dart';
import 'local_model_section.dart';

enum IntelligenceTab { local, api }

/// Page for configuring the LLM brain: local model or cloud API.
class IntelligencePage extends StatefulWidget {
  const IntelligencePage({super.key});

  @override
  State<IntelligencePage> createState() => _IntelligencePageState();
}

class _IntelligencePageState extends State<IntelligencePage> {
  final _apiKeyController = TextEditingController();
  String _provider = 'deepseek';
  String _model = 'deepseek-chat';
  bool _obscureApiKey = true;
  bool _initialized = false;
  IntelligenceTab _selectedTab = IntelligenceTab.local;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntelligenceState>().refreshAll();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _applyConfig(IntelligenceConfig config) {
    if (_initialized) return;
    _provider = config.provider;
    _model = config.model;
    _initialized = true;
  }

  LlmProviderInfo? _providerInfo(IntelligenceConfig config) {
    for (final info in config.availableProviders) {
      if (info.id == _provider) return info;
    }
    return config.currentProviderInfo;
  }

  List<String> _modelsForProvider(IntelligenceConfig config) {
    return _providerInfo(config)?.models ?? config.availableModels;
  }

  void _onProviderChanged(IntelligenceConfig config, String? providerId) {
    if (providerId == null || providerId == _provider) return;
    final info = config.availableProviders
        .where((p) => p.id == providerId)
        .firstOrNull;
    setState(() {
      _provider = providerId;
      _model = info?.defaultModel ?? _modelsForProvider(config).first;
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<IntelligenceState>();
    final documentsState = context.watch<DocumentsState>();

    if (state.config != null) {
      _applyConfig(state.config!);
    }

    final models = state.config != null ? _modelsForProvider(state.config!) : null;
    if (models != null && !models.contains(_model)) {
      _model = models.first;
    }

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
                  Text('Intelligence', style: theme.textTheme.titleLarge),
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
            child: AppSegmentedControl<IntelligenceTab>(
              segments: const [
                ButtonSegment(
                  value: IntelligenceTab.local,
                  icon: Icon(Icons.memory_outlined, size: 18),
                  label: Text('Local'),
                ),
                ButtonSegment(
                  value: IntelligenceTab.api,
                  icon: Icon(Icons.cloud_outlined, size: 18),
                  label: Text('API'),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (selection) {
                setState(() => _selectedTab = selection.first);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (_selectedTab) {
                IntelligenceTab.local => _LocalPanel(
                    key: const ValueKey('local'),
                    state: state,
                    documentsState: documentsState,
                    onRescan: state.isLoadingLocalLlm
                        ? () {}
                        : () => state.refreshLocalLlmCompatibility(),
                  ),
                IntelligenceTab.api => _ApiPanel(
                    key: const ValueKey('api'),
                    state: state,
                    documentsState: documentsState,
                    provider: _provider,
                    model: _model,
                    obscureApiKey: _obscureApiKey,
                    apiKeyController: _apiKeyController,
                    onProviderChanged: (value) {
                      final config = state.config;
                      if (config != null) {
                        _onProviderChanged(config, value);
                      }
                    },
                    onModelChanged: (value) {
                      if (value != null) setState(() => _model = value);
                    },
                    onToggleApiKeyVisibility: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                    onSave: () => _save(context),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final state = context.read<IntelligenceState>();

    final update = IntelligenceConfigUpdate(
      provider: _provider,
      model: _model,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
    );

    final success = await state.saveConfig(update);
    if (!context.mounted) return;

    if (success) {
      _apiKeyController.clear();
      _initialized = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intelligence settings saved')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Failed to save settings'),
        ),
      );
    }
  }
}

class _LocalPanel extends StatelessWidget {
  final IntelligenceState state;
  final DocumentsState documentsState;
  final VoidCallback onRescan;

  const _LocalPanel({
    super.key,
    required this.state,
    required this.documentsState,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppSurface(
        elevated: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPanelHeader(
              title: 'Local model',
              subtitle:
                  'On-device model — scanned and managed automatically.',
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: !documentsState.hasConnection
                  ? const AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Backend unavailable',
                      subtitle:
                          'Check your backend service and tap refresh in the app bar.',
                    )
                  : SingleChildScrollView(
                      child: LocalModelSection(
                        showTitle: false,
                        compatibility: state.localLlmCompatibility,
                        isLoading: state.isLoadingLocalLlm,
                        errorMessage: state.localLlmErrorMessage,
                        onRescan: onRescan,
                      ),
                    ),
            ),
            const IntelligencePrivacyFooter(),
          ],
        ),
      ),
    );
  }
}

class _ApiPanel extends StatelessWidget {
  final IntelligenceState state;
  final DocumentsState documentsState;
  final String provider;
  final String model;
  final bool obscureApiKey;
  final TextEditingController apiKeyController;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String?> onModelChanged;
  final VoidCallback onToggleApiKeyVisibility;
  final VoidCallback onSave;

  const _ApiPanel({
    super.key,
    required this.state,
    required this.documentsState,
    required this.provider,
    required this.model,
    required this.obscureApiKey,
    required this.apiKeyController,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onToggleApiKeyVisibility,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final config = state.config;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppSurface(
        elevated: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPanelHeader(
              title: 'Cloud API',
              subtitle: 'Connect a cloud provider with your API key.',
              trailing: FilledButton.icon(
                onPressed: !documentsState.hasConnection ||
                        state.isSaving ||
                        state.isLoading
                    ? null
                    : onSave,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(state.isSaving ? 'Saving…' : 'Save'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: !documentsState.hasConnection
                  ? const AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Backend unavailable',
                      subtitle:
                          'Check your backend service and tap refresh in the app bar.',
                    )
                  : state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : config == null
                          ? AppEmptyState(
                              icon: Icons.psychology_outlined,
                              title: 'Unable to load settings',
                              subtitle: state.errorMessage ?? 'Try again later.',
                              action: FilledButton.icon(
                                onPressed: state.isLoading
                                    ? null
                                    : () => state.refreshAll(),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                              ),
                            )
                          : IntelligenceApiTab(
                              config: config,
                              provider: provider,
                              model: model,
                              obscureApiKey: obscureApiKey,
                              apiKeyController: apiKeyController,
                              onProviderChanged: onProviderChanged,
                              onModelChanged: onModelChanged,
                              onToggleApiKeyVisibility: onToggleApiKeyVisibility,
                            ),
            ),
            const IntelligencePrivacyFooter(),
          ],
        ),
      ),
    );
  }
}
