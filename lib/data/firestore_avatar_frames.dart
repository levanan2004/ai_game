import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../logic/avatar_frames.dart';
import 'account_deletion.dart' show accountFunctionsBaseUrl;
import 'charm_board.dart';
import 'firestore_world_chat.dart' show parseCallAnswer;

/// Khung avatar over the callables avatarFrameList / avatarFrameEquip
/// (functions/avatar_frames.js) and the public docs player_avatars/{uid}
/// (its `frame` is server-written) and public_profiles/{uid}. The callable
/// protocol is done by hand like FirestoreWorldChat.
class FirestoreAvatarFrames implements AvatarFrameSource {
  FirestoreAvatarFrames({
    FirebaseFirestore? firestore,
    Future<String?> Function()? idToken,
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
  }) : _firestore = firestore,
       _idToken =
           idToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken()),
       _client = client ?? http.Client();

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  final Future<String?> Function() _idToken;
  final String baseUrl;
  final http.Client _client;

  /// Firestore `whereIn` takes at most 30 values.
  static const _chunk = 30;

  Future<({String? error, Map<String, Object?> result})> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final token = await _idToken();
    if (token == null || token.isEmpty) return (error: 'server', result: const <String, Object?>{});
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/$name'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 20));
      final a = parseCallAnswer(res.statusCode, res.bodyBytes);
      return (error: a.error, result: a.result);
    } catch (_) {
      return (error: 'network', result: const <String, Object?>{});
    }
  }

  @override
  Future<OwnedFrames> owned() async {
    final r = await _call('avatarFrameList', const {});
    if (r.error != null) throw StateError(r.error!);
    return readOwnedFrames(r.result);
  }

  @override
  Future<FrameEquipResult> equip(String frameId) async {
    final r = await _call('avatarFrameEquip', {'frameId': frameId});
    return switch (r.error) {
      null => FrameEquipResult.done,
      'not_owned' || 'unknown' => FrameEquipResult.notOwned,
      _ => FrameEquipResult.failed,
    };
  }

  @override
  Future<Map<String, String>> framesOf(List<String> uids) async {
    final out = <String, String>{};
    for (var i = 0; i < uids.length; i += _chunk) {
      final part = uids.sublist(i, i + _chunk > uids.length ? uids.length : i + _chunk);
      final snap = await _db
          .collection('player_avatars')
          .where(FieldPath.documentId, whereIn: part)
          .get();
      for (final d in snap.docs) {
        final f = d.data()['frame'];
        out[d.id] = f is String ? f : '';
      }
    }
    return out;
  }

  @override
  Future<PublicProfile> profile(String uid, {required String period}) async {
    final pub = await _db.doc('public_profiles/$uid').get();
    CharmBoardEntry? entry;
    try {
      final row = await _db.doc('charm_board/$period/entries/$uid').get();
      final data = row.data();
      if (data != null) entry = CharmBoardEntry.fromMap(uid, data);
    } catch (_) {}
    final day = pub.data()?['day'];
    return PublicProfile(day: day is num ? day.toInt() : null, entry: entry);
  }
}

/// avatarFrameList's answer {owned, equipped, vipLevel}. Exposed for tests.
OwnedFrames readOwnedFrames(Map<String, Object?> r) {
  final owned = r['owned'];
  final equipped = r['equipped'];
  final vip = r['vipLevel'];
  return OwnedFrames(
    owned: {
      if (owned is List)
        for (final o in owned)
          if (o is String) o,
    },
    equipped: equipped is String ? equipped : '',
    vipLevel: vip is num ? vip.toInt() : 0,
  );
}
