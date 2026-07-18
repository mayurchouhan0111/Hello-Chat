import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AppPersistentCache {
  static Directory? _cacheDir;

  /// Retrieves a file from the local cache. If the file is not cached,
  /// it downloads it from the provided [url] and stores it permanently.
  static Future<File> getFile(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      throw ArgumentError("URL cannot be empty");
    }

    if (_cacheDir == null) {
      final appSupportDir = await getApplicationSupportDirectory();
      _cacheDir = Directory('${appSupportDir.path}/app_persistent_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    }

    // Sanitize the URL to create a safe, human-readable file name
    final fileName = cleanUrl
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    
    final cacheFile = File('${_cacheDir!.path}/$fileName');

    if (await cacheFile.exists()) {
      final length = await cacheFile.length();
      if (length > 0) {
        // Return the cached file immediately!
        return cacheFile;
      } else {
        // Delete empty or corrupted files
        try {
          await cacheFile.delete();
        } catch (_) {}
      }
    }

    // If not cached, download the file
    print("🌐 AppPersistentCache: Downloading remote asset: $cleanUrl");
    final response = await http.get(Uri.parse(cleanUrl));
    if (response.statusCode == 200) {
      await cacheFile.writeAsBytes(response.bodyBytes);
      print("💾 AppPersistentCache: Saved to cache: $fileName");
      return cacheFile;
    } else {
      throw Exception("Failed to download remote asset. Status code: ${response.statusCode}");
    }
  }
}
