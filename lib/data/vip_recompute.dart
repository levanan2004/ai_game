import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'account_deletion.dart' show accountFunctionsBaseUrl;
import 'firestore_world_chat.dart' show parseCallAnswer;

/// What vipRecompute answered: players recomputed, players whose level moved.
typedef VipRecomputeResult = ({int count, int changed});

/// `/quan-tri` "Tính lại VIP": the admin-only vipRecompute callable
/// (functions/vip.js adminRecompute) with {all: true}. Tests pass a fake.
abstract class VipRecompute {
  Future<VipRecomputeResult> recomputeAll();
}

/// Reads a vipRecompute answer `{count, changed, results}`. Exposed for tests.
VipRecomputeResult readVipRecompute(Object? result) {
  int n(String k) =>
      result is Map && result[k] is num ? (result[k] as num).toInt() : 0;
  return (count: n('count'), changed: n('changed'));
}

/// The callable done by hand like FirestoreVip (Bearer id token).
class HttpVipRecompute implements VipRecompute {
  HttpVipRecompute({
    Future<String?> Function()? idToken,
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
  }) : _idToken =
           idToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken()),
       _client = client ?? http.Client();

  final Future<String?> Function() _idToken;
  final String baseUrl;
  final http.Client _client;

  @override
  Future<VipRecomputeResult> recomputeAll() async {
    final token = await _idToken();
    if (token == null || token.isEmpty) throw StateError('server');
    final res = await _client
        .post(
          Uri.parse('$baseUrl/vipRecompute'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'data': {'all': true},
          }),
        )
        // The function may run up to 540 s over every payer.
        .timeout(const Duration(seconds: 560));
    final a = parseCallAnswer(res.statusCode, res.bodyBytes);
    if (a.error != null) throw StateError(a.error!);
    return readVipRecompute(a.result);
  }
}
