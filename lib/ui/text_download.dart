import 'text_download_stub.dart'
    if (dart.library.html) 'text_download_web.dart'
    as impl;

/// Saves [text] as [filename] (UTF-8). No-op off the web.
Future<void> downloadText(
  String text,
  String filename, {
  String mime = 'text/csv',
}) => impl.downloadText(text, filename, mime: mime);
