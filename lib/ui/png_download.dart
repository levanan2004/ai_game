import 'png_download_stub.dart'
    if (dart.library.html) 'png_download_web.dart'
    as impl;

/// Saves PNG bytes as [filename]. No-op off the web.
Future<void> downloadPng(List<int> bytes, String filename) =>
    impl.downloadPng(bytes, filename);
