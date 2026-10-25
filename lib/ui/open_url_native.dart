import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import '../logic/safe_url.dart';

/// Android and iOS: hands the link to the browser / mail app. Never throws
/// (no browser, no mail app, bad link): nothing opens and the game goes on.
void openUrl(String url) {
  unawaited(_open(url));
}

Future<void> _open(String url) async {
  final uri = launchableUri(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
