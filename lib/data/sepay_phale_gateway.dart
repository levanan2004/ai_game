import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'phale_shop.dart';

/// The real payment server: three HTTPS functions of the project (see
/// `functions/README.md`, "Pha lê top-up"). Every call carries the player's
/// Firebase ID token; the server finds the pack by id in its own price table
/// and decides everything about money. This class only asks and shows: it
/// never adds Pha lê (the credit arrives as a mail the app claims).
class SepayPhaleGateway implements PhaleGateway {
  SepayPhaleGateway({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// `https://asia-southeast1-tiem-hoa-som-mai.cloudfunctions.net`
  final String baseUrl;

  /// The signed-in player's ID token; null when signed out.
  final Future<String?> Function() idToken;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String fn, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/$fn').replace(queryParameters: query);

  Future<Map<String, String>> _headers() async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const PhaleException(PhaleFailure.network);
    }
    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
  }

  /// 200 -> the JSON object; 503 `closed` -> [PhaleFailure.closed]; any other
  /// answer, a bad body or a lost connection -> [PhaleFailure.network].
  Map<String, dynamic> _json(http.Response r) {
    if (r.statusCode == 503) {
      throw const PhaleException(PhaleFailure.closed);
    }
    if (r.statusCode != 200) {
      throw const PhaleException(PhaleFailure.network);
    }
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const PhaleException(PhaleFailure.network);
    }
    return body;
  }

  @override
  Future<PhaleOrder> createOrder(String packId) => phaleGuard(() async {
    final r = await _client
        .post(
          _uri('phaleCreateOrder'),
          headers: await _headers(),
          body: jsonEncode({'packId': packId}),
        )
        .timeout(timeout);
    return parsePhaleOrder(_json(r));
  });

  @override
  Future<PhaleOrder> orderStatus(String orderId) => phaleGuard(() async {
    final r = await _client
        .get(
          _uri('phaleOrderStatus', {'orderId': orderId}),
          headers: await _headers(),
        )
        .timeout(timeout);
    return parsePhaleOrder(_json(r));
  });

  @override
  Future<void> cancelOrder(String orderId) => phaleGuard(() async {
    final r = await _client
        .post(
          _uri('phaleCancelOrder'),
          headers: await _headers(),
          body: jsonEncode({'orderId': orderId}),
        )
        .timeout(timeout);
    _json(r);
  });
}

/// The server's order JSON (`orderView` in `functions/topup.js`) as a
/// [PhaleOrder]. A body missing a field the screens need is a failure.
PhaleOrder parsePhaleOrder(Map<String, dynamic> j) {
  String str(String k) {
    final v = j[k];
    if (v is! String || v.isEmpty) {
      throw const PhaleException(PhaleFailure.network);
    }
    return v;
  }

  int whole(String k) {
    final v = j[k];
    if (v is! num) throw const PhaleException(PhaleFailure.network);
    return v.toInt();
  }

  DateTime time(String k) {
    final v = DateTime.tryParse(str(k));
    if (v == null) throw const PhaleException(PhaleFailure.network);
    return v;
  }

  int? maybe(String k) => j[k] is num ? (j[k] as num).toInt() : null;
  String? maybeStr(String k) => j[k] is String ? j[k] as String : null;

  return PhaleOrder(
    orderId: str('orderId'),
    packId: str('packId'),
    amount: whole('amount'),
    crystals: whole('crystals'),
    bonusPercent: maybe('bonusPercent') ?? 0,
    bank: str('bank'),
    accountNo: str('accountNo'),
    accountName: str('accountName'),
    transferContent: str('transferContent'),
    qrImageUrl: maybeStr('qrImageUrl'),
    expiresAt: time('expiresAt'),
    serverTime: j['serverTime'] is String
        ? DateTime.tryParse(j['serverTime'] as String)
        : null,
    status: PhaleOrderStatus.parse(j['status']),
    crystalsGranted: maybe('crystalsGranted'),
    newBalance: maybe('newBalance'),
    mailId: maybeStr('mailId'),
  );
}