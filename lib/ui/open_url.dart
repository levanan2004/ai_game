import 'open_url_stub.dart'
    if (dart.library.html) 'open_url_web.dart'
    if (dart.library.io) 'open_url_native.dart'
    as impl;

/// Opens [url]: a new tab on the web, the system browser / mail app on
/// Android and iOS (url_launcher). Nothing happens in plain VM runs.
void openUrl(String url) => impl.openUrl(url);
