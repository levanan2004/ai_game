import 'dart:typed_data';

/// Picks and uploads pictures for the notice board, the mailbox and the
/// góp ý form. Every file goes through `photoJpeg` first, so it stays
/// under the 512 KB Storage rule.
abstract class PhotoUploads {
  /// Null when the picker is cancelled or the photo cannot be encoded.
  Future<Uint8List?> pickPhotoJpeg();

  /// Admin picture for a notice or a mail. Returns a public https URL.
  Future<String> uploadBoardImage(Uint8List jpeg);

  /// Admin picture for a "Bạn biết?" slide (`welfare_slides/`). Returns a
  /// public https URL.
  Future<String> uploadSlideImage(Uint8List jpeg);

  /// A player's picture on one góp ý answer. Returns the download URL.
  Future<String> uploadReplyPhoto({
    required String uid,
    required String noticeId,
    required Uint8List jpeg,
  });
}
