import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_gateway.dart';

/// Where the 2nd gen functions of the project live (same as the top-up).
const accountFunctionsBaseUrl =
    'https://asia-southeast1-tiem-hoa-som-mai.cloudfunctions.net';

/// Calls the `deleteAccount` callable function (`functions/delete_account.js`).
///
/// A callable is a plain HTTPS POST: the body is `{"data": ...}`, the player's
/// Firebase ID token goes in the Authorization header, and the answer is
/// `{"result": ...}` or `{"error": {"status", "message"}}`. Doing it by hand
/// keeps the app free of the `cloud_functions` package, like the top-up calls.
/// The server decides everything: it only ever deletes the token's own account.
class AccountDeletionClient {
  AccountDeletionClient({
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  /// Returns when the server says the account is deleted. Throws
  /// [DeleteAccountException]: [DeleteFailure.blocked] for a top-up order that
  /// is still on its way, [DeleteFailure.partial] when the server stopped half
  /// way (safe to call again), [DeleteFailure.network] when nothing came back.
  Future<void> delete(String idToken) async {
    final http.Response r;
    try {
      r = await _client
          .post(
            Uri.parse('$baseUrl/deleteAccount'),
            headers: {
              'authorization': 'Bearer $idToken',
              'content-type': 'application/json',
            },
            body: jsonEncode({'data': <String, Object?>{}}),
          )
          .timeout(timeout);
    } catch (_) {
      throw const DeleteAccountException(DeleteFailure.network);
    }
    if (r.statusCode == 200) return;
    throw DeleteAccountException(failureOf(r.statusCode, r.bodyBytes));
  }

  /// The failure a non-200 answer means. Public for tests.
  static DeleteFailure failureOf(int status, List<int> body) {
    String? message;
    try {
      final j = jsonDecode(utf8.decode(body));
      final e = j is Map ? j['error'] : null;
      if (e is Map && e['message'] is String) message = e['message'] as String;
    } catch (_) {}
    if (message == 'order-pending') return DeleteFailure.blocked;
    if (message == 'partial') return DeleteFailure.partial;
    // A gateway answer with no body (502, 503, 504) is the network's fault.
    if (message == null && status >= 502) return DeleteFailure.network;
    return DeleteFailure.generic;
  }
}
