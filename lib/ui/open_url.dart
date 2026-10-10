import 'open_url_stub.dart' if (dart.library.html) 'open_url_web.dart' as impl;

/// Opens [url] in a new tab. No-op off the web.
void openUrl(String url) => impl.openUrl(url);
