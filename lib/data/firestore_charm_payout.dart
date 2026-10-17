import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../logic/charm_payout.dart';
import '../logic/rewards.dart';
import 'account_deletion.dart' show accountFunctionsBaseUrl;
import 'firestore_world_chat.dart' show parseCallAnswer;

/// Firestore side of the payout view: `charm_board/{period}` (meta + payout
/// summary), `charm_board/{period}/review/{uid}` and `config/charmPayout`;
/// a Bảng Đánh giá period ("rating-N", functions/rating_payout.js) reads
/// the same docs under `rating_board/`. Admin only (firestore.rules).
class FirestoreCharmPayout implements CharmPayoutStore {
  FirestoreCharmPayout({
    FirebaseFirestore? firestore,
    Future<String?> Function()? idToken,
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _idToken =
           idToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken()),
       _client = client ?? http.Client();

  final FirebaseFirestore _db;
  final Future<String?> Function() _idToken;
  final String baseUrl;
  final http.Client _client;

  /// `rating_board` for a rating period, else `charm_board`.
  CollectionReference<Map<String, dynamic>> _board(String period) =>
      _db.collection(isRatingPeriod(period) ? 'rating_board' : 'charm_board');

  static DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : null;
  static int _int(Object? v) => v is num ? v.toInt() : 0;

  @override
  Future<PayoutMeta> meta(String period) async {
    final snap = await _board(period).doc(period).get();
    final data = snap.data();
    if (data == null) return const PayoutMeta();
    final p = data['payout'];
    final map = p is Map ? p : const {};
    return PayoutMeta(
      status: map['status'] is String ? map['status'] as String : null,
      endsAt: _time(data['endsAt']),
      at: _time(map['at']),
      sent: _int(map['sent']),
      held: _int(map['held']),
      skipped: _int(map['skipped']),
      failed: _int(map['failed']),
    );
  }

  @override
  Future<List<PayoutLine>> lines(String period) async {
    final snap = await _board(period).doc(period).collection('review').get();
    final out = <PayoutLine>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final status = PayoutStatus.fromKey(d['status']);
      if (status == null) continue;
      final flags = d['flags'];
      out.add(
        PayoutLine(
          uid: doc.id,
          status: status,
          displayName: d['displayName'] is String
              ? d['displayName'] as String
              : '',
          rank: _int(d['rank']),
          stored: _int(d['stored']),
          recomputed: _int(d['recomputed']),
          flags: flags is List ? [for (final f in flags) '$f'] : const [],
          reason: d['reason'] is String ? d['reason'] as String : null,
          petId: d['petId'] is String ? d['petId'] as String : '',
          stage: _int(d['stage']),
          mailId: d['mailId'] is String ? d['mailId'] as String : null,
          items: d['items'] is List ? RewardBundle.fromJson(d['items']) : null,
        ),
      );
    }
    return out;
  }

  @override
  Future<bool> autoPayout() async {
    final snap = await _db.collection('config').doc('charmPayout').get();
    return snap.data()?['autoPayout'] != false;
  }

  @override
  Future<void> setAutoPayout(bool on) => _db
      .collection('config')
      .doc('charmPayout')
      .set({'autoPayout': on, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> markChampion(String period, String uid) =>
      _db.collection('rating_board').doc(period).update({'champion': uid});

  /// Admin callable titleRelease (functions/titles.js), by hand like
  /// FirestoreAvatarFrames.
  @override
  Future<bool> releaseTitle(String period) async {
    final token = await _idToken();
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/titleRelease'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'data': {'period': period},
            }),
          )
          .timeout(const Duration(seconds: 20));
      return parseCallAnswer(res.statusCode, res.bodyBytes).error == null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markReleased(String period, String uid) =>
      _board(period).doc(period).collection('review').doc(uid).set({
        'status': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
