import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// Center-crops to a square and encodes a 128×128 JPEG at quality 85.
///
/// That file is about 10–20 KB, under the 512 KB Storage rule. The original
/// photo is not size-limited; only this resized image is uploaded.
Uint8List? squareAvatarJpeg(Uint8List bytes) {
  final src = im.decodeImage(bytes);
  if (src == null) return null;
  final side = src.width < src.height ? src.width : src.height;
  if (side <= 0) return null;
  final cropped = im.copyCrop(
    src,
    x: (src.width - side) ~/ 2,
    y: (src.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final sized = im.copyResize(cropped, width: 128, height: 128);
  final out = im.encodeJpg(sized, quality: 85);
  if (out.length > 512 * 1024) return null;
  return Uint8List.fromList(out);
}
