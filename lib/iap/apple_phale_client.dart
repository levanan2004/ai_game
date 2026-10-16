import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/account_deletion.dart';

/// Answer of `phaleApplePurchase`: the mail the server wrote.
class ApplePhaleCredit {
  const ApplePhaleCredit({
    required this.mailId,
    required this.phaLe,
    required this.transactionId,
    required this.packId,
  });

  final String mailId;
  final int phaLe;
  final String transactionId;
  final String packId;
}

/// Sends the App Store signed transaction to the server. The server checks
/// it with Apple and writes the Pha lê mail. A repeated call for the same
/// transaction returns the same mail and does not pay twice.
class ApplePhaleClient {
  ApplePhaleClient({
    this.baseUrl = accountFunctionsBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ApplePhaleCredit> credit({
    required String idToken,
    required String signedTransaction,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/phaleApplePurchase'),
            headers: {
              'authorization': 'Bearer $idToken',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'data': {'signedTransaction': signedTransaction},
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApplePhaleException('network');
    }
    if (response.statusCode != 200) {
      throw ApplePhaleException('server');
    }
    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! Map) throw ApplePhaleException('server');
    final mailId = result['mailId'];
    final phaLe = result['phaLe'];
    final transactionId = result['transactionId'];
    final packId = result['packId'];
    if (mailId is! String ||
        phaLe is! num ||
        transactionId is! String ||
        packId is! String) {
      throw ApplePhaleException('server');
    }
    return ApplePhaleCredit(
      mailId: mailId,
      phaLe: phaLe.toInt(),
      transactionId: transactionId,
      packId: packId,
    );
  }
}

class ApplePhaleException implements Exception {
  ApplePhaleException(this.code);
  final String code;
}
