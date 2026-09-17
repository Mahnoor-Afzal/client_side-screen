import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile/desktop implementation: streams the file to app storage while
/// reporting progress, then opens it natively via the platform's default app.
///
/// Returns `null` on success, or a human-readable error string on failure so
/// the caller can fall back to launching the URL externally.
Future<String?> downloadAndOpenDocument({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) async {
  http.Client? client;
  try {
    client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      return 'Download failed (HTTP ${response.statusCode})';
    }

    final int total = response.contentLength ?? 0;
    final List<int> bytes = <int>[];
    int received = 0;

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }

    final Directory dir = await getApplicationDocumentsDirectory();
    final String safeName = _sanitizeFileName(fileName, url);
    final String filePath = '${dir.path}/$safeName';
    final File file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    onProgress?.call(1.0);

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      return result.message.isNotEmpty ? result.message : 'Unable to open file';
    }
    return null;
  } catch (e) {
    return e.toString();
  } finally {
    client?.close();
  }
}

String _sanitizeFileName(String fileName, String url) {
  String name = fileName.trim();
  if (name.isEmpty) {
    final segments = Uri.parse(url).pathSegments;
    name = segments.isNotEmpty
        ? segments.last
        : 'document_${DateTime.now().millisecondsSinceEpoch}';
  }
  name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  if (!name.contains('.')) {
    final String urlPath = Uri.parse(url).path.toLowerCase();
    String ext = 'pdf';
    for (final e in ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'webp', 'gif']) {
      if (urlPath.endsWith('.$e')) {
        ext = e;
        break;
      }
    }
    name = '$name.$ext';
  }
  return name;
}
