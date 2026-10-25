import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart';

/// Turns the solid black backdrop of the ad portraits into transparency.
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: knockout_ad_art.dart <src.png> <dst.webp>');
    exit(64);
  }
  final src = decodeImage(File(args[0]).readAsBytesSync());
  if (src == null) {
    stderr.writeln('cannot decode ${args[0]}');
    exit(1);
  }
  final img = src.convert(numChannels: 4);
  final w = img.width;
  final h = img.height;
  final seen = List<bool>.filled(w * h, false);
  final q = Queue<int>();
  void consider(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (seen[i]) return;
    final p = img.getPixel(x, y);
    if (p.r > 28 || p.g > 28 || p.b > 28) return;
    seen[i] = true;
    q.add(i);
  }

  for (var x = 0; x < w; x++) {
    consider(x, 0);
    consider(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    consider(0, y);
    consider(w - 1, y);
  }
  while (q.isNotEmpty) {
    final i = q.removeFirst();
    final x = i % w;
    final y = i ~/ w;
    img.setPixelRgba(x, y, 0, 0, 0, 0);
    consider(x - 1, y);
    consider(x + 1, y);
    consider(x, y - 1);
    consider(x, y + 1);
  }
  File(args[1]).writeAsBytesSync(encodeWebP(img, quality: 90));
}
