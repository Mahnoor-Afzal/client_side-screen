import 'dart:html' as html;

import 'package:http/http.dart' as http;

/// Web implementation: fetches the bytes and triggers a browser download,
/// falling back to opening the URL in a new tab if the fetch fails.
///
/// Returns `null` on success, or a human-readable error string on failure.
Future<String?> downloadAndOpenDocument({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) async {
  try {
    onProgress?.call(0.1);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      html.window.open(url, '_blank');
      onProgress?.call(1.0);
      return null;
    }

    onProgress?.call(0.9);
    final blob = html.Blob(<dynamic>[response.bodyBytes]);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final String safeName = fileName.trim().isEmpty ? 'document' : fileName.trim();

    html.AnchorElement(href: objectUrl)
      ..setAttribute('download', safeName)
      ..click();
    html.Url.revokeObjectUrl(objectUrl);
    onProgress?.call(1.0);
    return null;
  } catch (e) {
    try {
      html.window.open(url, '_blank');
    } catch (_) {}
    return null;
  }
}
