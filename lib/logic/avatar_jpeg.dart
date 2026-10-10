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

/// Storage limit for every uploaded picture (see storage.rules).
const maxPhotoBytes = 512 * 1024;

/// A notice, mail or góp ý picture: keeps the aspect ratio, longest side
/// at most [maxSide], JPEG. Lowers the quality, then the size, until the
/// file is under [maxPhotoBytes]. Null when it cannot be decoded.
Uint8List? photoJpeg(Uint8List bytes, {int maxSide = 1280}) {
  im.Image? src;
  try {
    src = im.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (src == null || src.width <= 0 || src.height <= 0) return null;
  var side = maxSide;
  while (side >= 320) {
    final longest = src.width > src.height ? src.width : src.height;
    final sized = longest <= side
        ? src
        : src.width >= src.height
        ? im.copyResize(src, width: side)
        : im.copyResize(src, height: side);
    for (final quality in const [85, 75, 65, 55]) {
      final out = im.encodeJpg(sized, quality: quality);
      if (out.length < maxPhotoBytes) return Uint8List.fromList(out);
    }
    side = (side * 0.75).round();
  }
  return null;
}
