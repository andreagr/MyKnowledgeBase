import 'package:flutter/material.dart';

import 'core/backend/backend_launcher.dart';
import 'features/startup/startup_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final launcher = BackendLauncher();
  runApp(StartupApp(launcher: launcher));
}
