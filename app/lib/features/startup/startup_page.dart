import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/branding.dart';
import '../../core/backend/backend_launcher.dart';
import '../../design_system/design_system.dart';

/// Root widget: boots the backend, then swaps to the main app.
class StartupApp extends StatefulWidget {
  const StartupApp({super.key, required this.launcher});

  final BackendLauncher launcher;

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  String _message = 'Starting ${AppBranding.name}...';
  bool _failed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      if (widget.launcher.backendDirectory != null) {
        setState(() => _message = 'Starting document services...');
        final started = await widget.launcher.start();
        if (!mounted) {
          return;
        }
        if (!started) {
          setState(() {
            _failed = true;
            _message = widget.launcher.lastStartupError ??
                'Could not start the bundled document services.';
          });
          return;
        }
      } else {
        setState(() => _message = 'Connecting to backend...');
      }

      final healthy = await widget.launcher.waitUntilHealthy();
      if (!mounted) {
        return;
      }

      if (!healthy) {
        setState(() {
          _failed = true;
          _message = widget.launcher.managesBackend
              ? widget.launcher.lastStartupError ??
                  'Document services started but did not become ready. '
                      'Try restarting the app.'
              : 'Could not reach the backend at http://127.0.0.1:8000. '
                  'Start it with: uvicorn app:app --host 127.0.0.1 --port 8000';
        });
        return;
      }

      setState(() => _ready = true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failed = true;
        _message = 'Startup failed: $error';
      });
    }
  }

  void _retry() {
    setState(() {
      _failed = false;
      _message = 'Retrying...';
    });
    _boot();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return App(launcher: widget.launcher);
    }

    final theme = buildAppTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(AppBranding.iconAsset, width: 72, height: 72),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(AppBranding.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppBranding.tagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!_failed) const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_failed) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
