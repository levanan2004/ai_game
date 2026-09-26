import 'dart:html' as html;
import 'dart:typed_data';

/// Reads a remote image so it can be re-encoded and stored in Storage.
/// A cross-origin block returns null; the caller keeps the original URL.
Future<Uint8List?> fetchPhotoBytes(String url) async {
  try {
    final req = await html.HttpRequest.request(
      url,
      responseType: 'arraybuffer',
    );
    final body = req.response;
    if (body is ByteBuffer) return body.asUint8List();
  } catch (_) {}
  return null;
}
