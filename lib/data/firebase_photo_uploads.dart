import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../logic/avatar_jpeg.dart';
import '../logic/photo_uploads.dart';
import '../logic/supporters.dart';

/// Storage paths allowed by `storage.rules`:
/// `board_images/{file}` (admins, public read) and
/// `reply_photos/{uid}/{file}` (the player; read by the player and admins).
class FirebasePhotoUploads implements PhotoUploads {
  FirebasePhotoUploads({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static final _jpeg = SettableMetadata(contentType: 'image/jpeg');

  @override
  Future<Uint8List?> pickPhotoJpeg() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return photoJpeg(await file.readAsBytes());
  }

  @override
  Future<String> uploadBoardImage(Uint8List jpeg) async {
    _checkSize(jpeg);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'board_images/img_$stamp.jpg';
    await _storage.ref(path).putData(jpeg, _jpeg);
    return storageAvatarUrl(path)!;
  }

  @override
  Future<String> uploadReplyPhoto({
    required String uid,
    required String noticeId,
    required Uint8List jpeg,
  }) async {
    _checkSize(jpeg);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('reply_photos/$uid/${noticeId}_$stamp.jpg');
    await ref.putData(jpeg, _jpeg);
    return ref.getDownloadURL();
  }

  void _checkSize(Uint8List jpeg) {
    if (jpeg.isEmpty || jpeg.length >= maxPhotoBytes) {
      throw StateError('photo too large');
    }
  }
}
