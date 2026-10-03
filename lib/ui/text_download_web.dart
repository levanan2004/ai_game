// dart:html is the smallest way to save a file without another package.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadText(
  String text,
  String filename, {
  String mime = 'text/csv',
}) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  final blob = html.Blob([bytes], '$mime;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
