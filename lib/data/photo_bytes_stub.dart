import 'dart:typed_data';

/// VM and tests have no browser fetch.
Future<Uint8List?> fetchPhotoBytes(String url) async => null;
