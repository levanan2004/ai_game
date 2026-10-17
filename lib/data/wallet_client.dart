import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/wallet.dart';
import 'account_deletion.dart' show accountFunctionsBaseUrl;

/// [WalletApi] over plain HTTPS, the callable protocol by hand like
/// [AccountDeletionClient]: POST `{"data": ...}` with the player's Firebase
/// ID token; the answer is `{"result": ...}` or `{"error": {...}}`. The
/// server takes the uid from the token only.
class WalletClient implements WalletApi {
  WalletClient({
    required this.idToken,
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Future<String?> Function() idToken;
  final String baseUrl;
  final http.Client _client;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const WalletException('sign-in-required');
    }
    final http.Response r;
    try {
      r = await _client
          .post(
            Uri.parse('$baseUrl/$name'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const WalletException('network');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode != 200) {
      final e = decoded is Map ? decoded['error'] : null;
      final message = e is Map ? e['message'] : null;
      if (message is String && message.isNotEmpty) {
        throw WalletException(message);
      }
      throw WalletException(r.statusCode >= 502 ? 'network' : 'server');
    }
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! Map) throw const WalletException('server');
    return result.cast<String, Object?>();
  }
}
