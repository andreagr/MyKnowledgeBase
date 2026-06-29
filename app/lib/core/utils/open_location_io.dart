import 'dart:io';

Future<String?> openFolder(String folderPath) async {
  final normalized = _normalizePath(folderPath);

  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [normalized]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [normalized]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [normalized]);
    } else {
      return 'Opening folders is not supported on this platform.';
    }
    return null;
  } catch (error) {
    return 'Could not open folder: $error';
  }
}

Future<String?> openFileInFolder(String filePath) async {
  final normalized = _normalizePath(filePath);

  try {
    if (Platform.isWindows) {
      if (File(normalized).existsSync()) {
        await Process.run('explorer.exe', ['/select,', normalized]);
      } else {
        await Process.run('explorer.exe', [File(normalized).parent.path]);
      }
    } else if (Platform.isMacOS) {
      if (File(normalized).existsSync()) {
        await Process.run('open', ['-R', normalized]);
      } else {
        await Process.run('open', [File(normalized).parent.path]);
      }
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [File(normalized).parent.path]);
    } else {
      return 'Opening files is not supported on this platform.';
    }
    return null;
  } catch (error) {
    return 'Could not open file location: $error';
  }
}

String _normalizePath(String path) {
  return path.replaceAll('/', Platform.pathSeparator);
}
