// dart:html is the smallest way to save a PNG without another package.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadPng(List<int> bytes, String filename) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
