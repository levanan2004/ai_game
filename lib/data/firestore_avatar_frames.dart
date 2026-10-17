import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../logic/avatar_frames.dart';
import 'account_deletion.dart' show accountFunctionsBaseUrl;
import 'charm_board.dart';
import 'titles.dart';
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
    if (token == null || token.isEmpty) {
      return (error: 'server', result: const <String, Object?>{});
    }
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
  Future<Map<String, PlayerLook>> looksOf(List<String> uids) async {
    final out = <String, PlayerLook>{};
    for (var i = 0; i < uids.length; i += _chunk) {
      final part = uids.sublist(
        i,
        i + _chunk > uids.length ? uids.length : i + _chunk,
      );
      final snap = await _db
          .collection('player_avatars')
          .where(FieldPath.documentId, whereIn: part)
          .get();
      for (final d in snap.docs) {
        out[d.id] = readPlayerLook(d.data());
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
    // Who holds each champion title (2 docs, functions/titles.js).
    final holders = <String, TitleHolder>{};
    try {
      final t = await _db.collection('titles').get();
      for (final d in t.docs) {
        final h = TitleHolder.fromMap(
          d.id,
          d.data(),
          time: (v) => v is Timestamp ? v.toDate() : null,
        );
        if (h != null) holders[d.id] = h;
      }
    } catch (_) {}
    // Your own counter notes ("not counted today"), milestones.js; the
    // rules let only the owner read milestone_state.
    var note = MilestoneNote.none;
    if (uid == FirebaseAuth.instance.currentUser?.uid) {
      try {
        final st = await _db.doc('milestone_state/$uid').get();
        note = MilestoneNote.fromState(st.data(), vnDateKey(DateTime.now()));
      } catch (_) {}
    }
    return PublicProfile(
      day: day is num ? day.toInt() : null,
      entry: entry,
      titles: PlayerTitles.fromMaps(uid, pub.data(), holders, note: note),
    );
  }

  @override
  Future<TitlePinResult> pinTitle(String titleId) async {
    final r = await _call('titlePin', {'id': titleId});
    return switch (r.error) {
      null => TitlePinResult.done,
      'not-held' || 'bad-id' => TitlePinResult.notHeld,
      _ => TitlePinResult.failed,
    };
  }
}

/// player_avatars/{uid}: `frame` (avatar_frames.js) and `vip` (vip.js).
/// Exposed for tests.
PlayerLook readPlayerLook(Map<String, Object?> d) {
  final f = d['frame'];
  final v = d['vip'];
  final vip = v is num ? v.toInt() : 0;
  return PlayerLook(
    frame: f is String ? f : '',
    vip: vip >= 1 && vip <= 10 ? vip : 0,
  );
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
