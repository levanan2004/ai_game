// dart:html is the smallest way to open a tab without another package.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void openUrl(String url) {
  if (url.startsWith('mailto:')) {
    html.window.location.href = url;
    return;
  }
  html.window.open(url, '_blank');
}
