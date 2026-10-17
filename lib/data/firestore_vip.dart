import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../logic/vip.dart';
import '../logic/wallet.dart' show VipStatus;
import 'account_deletion.dart' show accountFunctionsBaseUrl;
import 'firestore_world_chat.dart' show parseCallAnswer;

/// VIP over vip_hall/{uid} (server-written, signed-in read) and the
/// vipHallHide callable (functions/vip.js), done by hand like
/// FirestoreAvatarFrames.
class FirestoreVip implements VipSource {
  FirestoreVip({
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

  /// The snapshot of each row read, to start the next page after it.
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _snaps = {};

  @override
  Future<List<VipHallRow>> hallPage({
    VipHallRow? after,
    required int limit,
  }) async {
    // Earliest first; Firestore breaks a tie on the document id (the uid).
    Query<Map<String, dynamic>> q = _db
        .collection('vip_hall')
        .orderBy('at')
        .limit(limit);
    final from = after == null ? null : _snaps[after.uid];
    if (from != null) q = q.startAfterDocument(from);
    final snap = await q.get();
    final out = <VipHallRow>[];
    for (final d in snap.docs) {
      final row = readVipHallRow(d.id, d.data());
      if (row == null) continue;
      _snaps[d.id] = d;
      out.add(row);
    }
    return out;
  }

  @override
  Future<int> hallCount() async {
    final agg = await _db.collection('vip_hall').count().get();
    return agg.count ?? 0;
  }

  @override
  Future<VipStatus> setHallHidden(bool hidden) async {
    final token = await _idToken();
    if (token == null || token.isEmpty) throw StateError('server');
    final res = await _client
        .post(
          Uri.parse('$baseUrl/vipHallHide'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'data': {'hidden': hidden},
          }),
        )
        .timeout(const Duration(seconds: 20));
    final a = parseCallAnswer(res.statusCode, res.bodyBytes);
    if (a.error != null) throw StateError(a.error!);
    return VipStatus.fromJson(a.result);
  }
}

/// One vip_hall doc; null without a date. Exposed for tests.
VipHallRow? readVipHallRow(String uid, Map<String, Object?> d) {
  final at = d['at'];
  final DateTime? when = at is Timestamp
      ? at.toDate()
      : at is DateTime
      ? at
      : null;
  if (when == null) return null;
  final name = d['name'];
  final avatar = d['avatar'];
  return VipHallRow(
    uid: uid,
    at: when,
    name: name is String ? name : '',
    avatar: avatar is String ? avatar : '',
    hidden: d['hidden'] == true,
  );
}
