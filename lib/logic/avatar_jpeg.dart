import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// Center-crops to a square and encodes a 256×256 JPEG under 512 KB,
/// which is the Storage rule for `users/{uid}/avatar.jpg`.
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
  final sized = im.copyResize(cropped, width: 256, height: 256);
  var quality = 80;
  var out = im.encodeJpg(sized, quality: quality);
  while (out.length > 512 * 1024 && quality > 40) {
    quality -= 10;
    out = im.encodeJpg(sized, quality: quality);
  }
  if (out.length > 512 * 1024) return null;
  return Uint8List.fromList(out);
}
