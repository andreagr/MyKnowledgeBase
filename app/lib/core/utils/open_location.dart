import 'open_location_io.dart' if (dart.library.html) 'open_location_web.dart' as impl;

/// Opens a folder or highlights a file in the system file explorer.
class LocationOpener {
  static Future<String?> openFolder(String folderPath) {
    return impl.openFolder(folderPath);
  }

  static Future<String?> openFileInFolder(String filePath) {
    return impl.openFileInFolder(filePath);
  }
}
