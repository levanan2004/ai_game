import 'dart:async';

/// One Pha lê pack bought with real money (`economy.json` → `phaLeShop`).
class PhaPack {
  const PhaPack({
    required this.id,
    required this.priceVnd,
    required this.phaLe,
    required this.bonusPercent,
  });

  /// `pack_10k` … `pack_500k`; also the picture name (`assets/images/phale/`).
  final String id;
  final int priceVnd;

  /// The Pha lê the pack gives, bonus included.
  final int phaLe;
  final int bonusPercent;

  bool get hasBonus => bonusPercent > 0;
}

/// The Pha lê shop's data file block. Read from `economy.json`, never hard
/// coded in a widget.
class PhaleShopConfig {
  const PhaleShopConfig({
    this.packs = const [],
    this.open = false,
    this.bestPackId,
    this.pollSeconds = 5,
    this.checkGapSeconds = 4,
  });

  final List<PhaPack> packs;

  /// False until the server side (SePay) is connected: the shop shows the
  /// "Sắp mở" state and no order can be created.
  final bool open;

  /// The pack tagged "Đáng giá nhất" (Phú's proposal, An decides).
  final String? bestPackId;

  /// How often the order screen asks the server for the order status.
  final int pollSeconds;

  /// The shortest gap between two "Tôi đã chuyển" checks.
  final int checkGapSeconds;

  PhaPack? pack(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory PhaleShopConfig.fromJson(Object? json) {
    if (json is! Map) return const PhaleShopConfig();
    final packs = <PhaPack>[];
    final raw = json['packs'];
    if (raw is List) {
      for (final p in raw) {
        if (p is! Map) continue;
        final id = p['id'];
        final price = p['priceVnd'];
        final phaLe = p['phaLe'];
        if (id is! String || price is! num || phaLe is! num) continue;
        if (price <= 0 || phaLe <= 0) continue;
        final bonus = p['bonusPercent'];
        packs.add(
          PhaPack(
            id: id,
            priceVnd: price.toInt(),
            phaLe: phaLe.toInt(),
            bonusPercent: bonus is num ? bonus.toInt() : 0,
          ),
        );
      }
      packs.sort((a, b) => a.priceVnd.compareTo(b.priceVnd));
    }
    int posInt(Object? v, int fallback) =>
        v is num && v > 0 ? v.toInt() : fallback;
    final best = json['bestPackId'];
    return PhaleShopConfig(
      packs: packs,
      open: json['open'] == true,
      bestPackId: best is String ? best : null,
      pollSeconds: posInt(json['pollSeconds'], 5),
      checkGapSeconds: posInt(json['checkGapSeconds'], 4),
    );
  }
}

/// Where an order stands, as the SERVER reports it.
enum PhaleOrderStatus {
  /// Waiting for the transfer (S6a / S6b).
  pending,

  /// Money arrived and the server wrote the Pha lê (S2c).
  paid,

  /// The order ran out of time (S6c).
  expired,

  /// Money came, but the amount or the content did not match; no Pha lê was
  /// written (S6d).
  mismatch,

  /// The order was cancelled (S2e).
  cancelled;

  static PhaleOrderStatus parse(Object? v) => switch (v) {
    'paid' => paid,
    'expired' => expired,
    'mismatch' => mismatch,
    'cancelled' => cancelled,
    _ => pending,
  };
}

/// One order, with exactly the fields the screens show. The names are the ones
/// the server API should use (docs/PHALE_SHOP_API.md). The app only DISPLAYS
/// [crystalsGranted] and [newBalance]; it never adds Pha lê itself.
class PhaleOrder {
  const PhaleOrder({
    required this.orderId,
    required this.packId,
    required this.amount,
    required this.crystals,
    required this.bonusPercent,
    required this.bank,
    required this.accountNo,
    required this.accountName,
    required this.transferContent,
    required this.expiresAt,
    this.qrImageUrl,
    this.serverTime,
    this.status = PhaleOrderStatus.pending,
    this.crystalsGranted,
    this.newBalance,
    this.supportContact,
    this.mailId,
    this.demo = false,
  });

  /// Unique per order; also the support reference.
  final String orderId;
  final String packId;

  /// Dong, an integer (50000), shown "50.000đ" and copied as digits.
  final int amount;
  final int crystals;
  final int bonusPercent;
  final String bank;
  final String accountNo;
  final String accountName;

  /// The unique content the player must keep as is (the order code).
  final String transferContent;

  /// A VietQR picture URL made by the server; null shows the local fake QR.
  final String? qrImageUrl;

  /// When the order stops being valid, in SERVER time.
  final DateTime expiresAt;

  /// The server's clock when it answered; the countdown uses `expiresAt` minus
  /// this, never the device clock.
  final DateTime? serverTime;
  final PhaleOrderStatus status;

  /// Set with `paid`: what the server wrote, and the balance after it.
  final int? crystalsGranted;
  final int? newBalance;

  /// Where "Liên hệ hỗ trợ" leads (a mailto/URL), when the server has one.
  final String? supportContact;

  /// Set with `paid`: the id of the mail (`phale_{orderId}`) that holds the
  /// Pha lê. The app claims it like any reward; this is the only way Pha lê
  /// reaches the wallet.
  final String? mailId;

  /// True for the made-up data of [DemoPhaleGateway]: the screen labels it.
  final bool demo;

  PhaleOrder copyWith({
    PhaleOrderStatus? status,
    int? crystalsGranted,
    int? newBalance,
    DateTime? serverTime,
  }) => PhaleOrder(
    orderId: orderId,
    packId: packId,
    amount: amount,
    crystals: crystals,
    bonusPercent: bonusPercent,
    bank: bank,
    accountNo: accountNo,
    accountName: accountName,
    transferContent: transferContent,
    expiresAt: expiresAt,
    qrImageUrl: qrImageUrl,
    serverTime: serverTime ?? this.serverTime,
    status: status ?? this.status,
    crystalsGranted: crystalsGranted ?? this.crystalsGranted,
    newBalance: newBalance ?? this.newBalance,
    supportContact: supportContact,
    mailId: mailId,
    demo: demo,
  );
}

enum PhaleFailure {
  /// The shop is not open yet (flag off).
  closed,

  /// No connection or a server error.
  network,
}

class PhaleException implements Exception {
  const PhaleException(this.failure);

  final PhaleFailure failure;

  @override
  String toString() => 'PhaleException($failure)';
}

/// The ONLY door to the payment server (SePay behind it). Two calls drive the
/// UI; [cancelOrder] lets "Hủy đơn" kill the QR on the server too. None of
/// them changes the player's Pha lê: the server writes it when the money
/// arrives and reports it through [orderStatus].
abstract class PhaleGateway {
  /// Makes an order for [packId] and returns its transfer data.
  Future<PhaleOrder> createOrder(String packId);

  /// The current state of an order (`status`, and for `paid` the granted
  /// amount and the new balance).
  Future<PhaleOrder> orderStatus(String orderId);

  /// Cancels a pending order so its QR no longer works.
  Future<void> cancelOrder(String orderId);
}

/// The gateway while the flag `phaLeShop.open` is off: nothing can be ordered.
class ClosedPhaleGateway implements PhaleGateway {
  const ClosedPhaleGateway();

  @override
  Future<PhaleOrder> createOrder(String packId) =>
      Future.error(const PhaleException(PhaleFailure.closed));

  @override
  Future<PhaleOrder> orderStatus(String orderId) =>
      Future.error(const PhaleException(PhaleFailure.closed));

  @override
  Future<void> cancelOrder(String orderId) =>
      Future.error(const PhaleException(PhaleFailure.closed));
}

/// Made-up orders for the demo and the tests, clearly labelled: the bank is
/// "DEMO", the account number is zeros and the QR is the fake picture. An
/// order stays `pending` until [force] is called (a test or a demo switch);
/// it never pays by itself and never touches the player's balance.
class DemoPhaleGateway implements PhaleGateway {
  DemoPhaleGateway({
    this.config = const PhaleShopConfig(),
    this.lifetime = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PhaleShopConfig config;
  final Duration lifetime;
  final DateTime Function() _clock;

  final Map<String, PhaleOrder> orders = {};
  int _n = 0;

  /// Makes calls fail like a lost connection.
  bool offline = false;

  PhaleOrder _stamp(PhaleOrder o) => o.copyWith(serverTime: _clock());

  @override
  Future<PhaleOrder> createOrder(String packId) async {
    if (offline) throw const PhaleException(PhaleFailure.network);
    final pack = config.pack(packId);
    if (pack == null) throw const PhaleException(PhaleFailure.network);
    _n++;
    final id = 'PLDEMO${_n.toString().padLeft(4, '0')}';
    final order = PhaleOrder(
      orderId: id,
      packId: pack.id,
      amount: pack.priceVnd,
      crystals: pack.phaLe,
      bonusPercent: pack.bonusPercent,
      bank: 'Ngân hàng DEMO',
      accountNo: '0000000000',
      accountName: 'TAI KHOAN DEMO',
      transferContent: id,
      expiresAt: _clock().add(lifetime),
      demo: true,
    );
    orders[id] = order;
    return _stamp(order);
  }

  @override
  Future<PhaleOrder> orderStatus(String orderId) async {
    if (offline) throw const PhaleException(PhaleFailure.network);
    final o = orders[orderId];
    if (o == null) throw const PhaleException(PhaleFailure.network);
    return _stamp(o);
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    if (offline) throw const PhaleException(PhaleFailure.network);
    final o = orders[orderId];
    if (o != null) {
      orders[orderId] = o.copyWith(status: PhaleOrderStatus.cancelled);
    }
  }

  /// Demo/test switch: the "server" moves an order to [status]. For `paid` it
  /// reports [granted] and [balance] as the server's numbers.
  void force(
    String orderId,
    PhaleOrderStatus status, {
    int? granted,
    int? balance,
  }) {
    final o = orders[orderId];
    if (o == null) return;
    orders[orderId] = o.copyWith(
      status: status,
      crystalsGranted: granted,
      newBalance: balance,
    );
  }
}

/// Runs [fn] and turns every failure into a [PhaleException] network error.
Future<T> phaleGuard<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } on PhaleException {
    rethrow;
  } on TimeoutException {
    throw const PhaleException(PhaleFailure.network);
  } catch (_) {
    throw const PhaleException(PhaleFailure.network);
  }
}
