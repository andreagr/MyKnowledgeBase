import 'dart:async';

import 'dart:io';



import 'package:http/http.dart' as http;

import 'package:path/path.dart' as p;



import '../../app/config.dart';



/// Starts and stops the bundled Python backend for packaged desktop installs.

class BackendLauncher {

  Process? _process;

  bool _managedBackend = false;

  String? _lastStartupError;



  bool get managesBackend => _managedBackend;



  /// Last error from [start], if startup failed.

  String? get lastStartupError => _lastStartupError;



  /// Locate the backend runtime folder next to the installed desktop executable.

  Directory? get backendDirectory {

    final executable = Platform.resolvedExecutable;

    final installDir = Directory(p.dirname(executable));

    final backendDir = Directory(p.join(installDir.path, 'backend'));

    if (!backendDir.existsSync()) {

      return null;

    }

    return backendDir;

  }



  String get _localAppDataBase {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return localAppData;
    }
    return p.join(Platform.environment['USERPROFILE'] ?? '', 'AppData', 'Local');
  }

  String get dataDirectory {

    final override = Platform.environment['RAG_DATA_DIR'];

    if (override != null && override.isNotEmpty) {

      return override;

    }



    final localAppData = Platform.environment['LOCALAPPDATA'];

    final base = (localAppData != null && localAppData.isNotEmpty)

        ? localAppData

        : p.join(Platform.environment['USERPROFILE'] ?? '', 'AppData', 'Local');

    return p.join(base, 'MyKB', 'data');

  }

  /// Writable copy of backend `.py` sources (install dir under Program Files is read-only).
  Directory _prepareRuntimeSources(Directory installBackend) {
    final runtimeDir = Directory(p.join(_localAppDataBase, 'MyKB', 'backend-run'));
    final overridesDir = Directory(p.join(_localAppDataBase, 'MyKB', 'backend-overrides'));
    runtimeDir.createSync(recursive: true);

    for (final entity in installBackend.listSync()) {
      if (entity is! File || !entity.path.endsWith('.py')) {
        continue;
      }
      final name = p.basename(entity.path);
      final dest = File(p.join(runtimeDir.path, name));
      final override = File(p.join(overridesDir.path, name));
      final source = override.existsSync() ? override : entity;
      final shouldCopy = !dest.existsSync() ||
          source.statSync().modified.isAfter(dest.statSync().modified);
      if (shouldCopy) {
        source.copySync(dest.path);
      }
    }

    final installLocalLlm = Directory(p.join(installBackend.path, 'local_llm'));
    if (installLocalLlm.existsSync()) {
      final runtimeLocalLlm = Directory(p.join(runtimeDir.path, 'local_llm'));
      runtimeLocalLlm.createSync(recursive: true);
      for (final entity in installLocalLlm.listSync(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relative = p.relative(entity.path, from: installLocalLlm.path);
        final dest = File(p.join(runtimeLocalLlm.path, relative));
        dest.parent.createSync(recursive: true);
        final override = File(p.join(overridesDir.path, 'local_llm', relative));
        final source = override.existsSync() ? override : entity;
        final shouldCopy = !dest.existsSync() ||
            source.statSync().modified.isAfter(dest.statSync().modified);
        if (shouldCopy) {
          source.copySync(dest.path);
        }
      }
    }

    return runtimeDir;
  }



  Future<bool> start() async {

    _lastStartupError = null;



    final backendDir = backendDirectory;

    if (backendDir == null) {

      return false;

    }



    final pythonExe = _resolvePythonExecutable(backendDir);

    Directory runtimeSources;
    try {
      runtimeSources = _prepareRuntimeSources(backendDir);
    } catch (error) {
      _lastStartupError = 'Failed to prepare backend sources: $error';
      return false;
    }

    final entryScript = File(p.join(runtimeSources.path, 'backend_main.py'));



    if (pythonExe == null) {

      _lastStartupError =

          'Bundled Python was not found in ${backendDir.path}. '

          'Reinstall MyKB from a fresh build — the runtime may be incomplete.';

      return false;

    }



    if (!entryScript.existsSync()) {

      _lastStartupError =

          'Backend entry script missing: ${entryScript.path}';

      return false;

    }



    final env = Map<String, String>.from(Platform.environment);

    env['RAG_DATA_DIR'] = dataDirectory;

    env['RAG_HOST'] = kBackendHost;

    env['RAG_PORT'] = '$kBackendPort';

    env['PYTHONNOUSERSITE'] = '1';

    env['PYTHONHOME'] = p.join(backendDir.path, 'python');

    env['PYTHONPATH'] = runtimeSources.path;



    try {

      _process = await Process.start(

        pythonExe,

        [entryScript.path],

        workingDirectory: runtimeSources.path,

        environment: env,

        mode: ProcessStartMode.detachedWithStdio,

      );

      _managedBackend = true;

      return true;

    } catch (error) {

      _lastStartupError =

          'Failed to start bundled Python at $pythonExe: $error';

      return false;

    }

  }



  String? _resolvePythonExecutable(Directory backendDir) {

    final pythonRoot = p.join(backendDir.path, 'python');

    final candidates = [

      p.join(pythonRoot, 'pythonw.exe'),

      p.join(pythonRoot, 'python.exe'),

      p.join(pythonRoot, 'Scripts', 'pythonw.exe'),

      p.join(pythonRoot, 'Scripts', 'python.exe'),

      p.join(backendDir.path, 'pythonw.exe'),

      p.join(backendDir.path, 'python.exe'),

    ];



    for (final candidate in candidates) {

      if (File(candidate).existsSync()) {

        return candidate;

      }

    }

    return null;

  }



  Future<bool> waitUntilHealthy({

    Duration timeout = const Duration(minutes: 3),

    Duration interval = const Duration(seconds: 2),

  }) async {

    final deadline = DateTime.now().add(timeout);



    while (DateTime.now().isBefore(deadline)) {

      if (await _isHealthy()) {

        return true;

      }

      await Future<void>.delayed(interval);

    }



    return false;

  }



  Future<bool> _isHealthy() async {

    try {

      final response = await http

          .get(Uri.parse('$effectiveBackendBaseUrl/health'))

          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;

    } catch (_) {

      return false;

    }

  }



  Future<void> stop() async {

    final process = _process;

    if (process == null) {

      return;

    }



    if (Platform.isWindows) {

      try {

        await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);

      } catch (_) {

        process.kill();

      }

    } else {

      process.kill(ProcessSignal.sigterm);

    }



    _process = null;

    _managedBackend = false;

  }

}

