import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/phale_shop.dart';

/// Which screen or popup of the Pha lê shop is up.
enum PhaleStep {
  /// S1 (also S3, S5, S6g by the controller's other flags).
  shop,

  /// S2a: "Mua {n} Pha lê?".
  confirm,

  /// S2b: the order is being made.
  creating,

  /// S2d: the order could not be made.
  createFailed,

  /// S6: the transfer screen (status: waiting, expired, mismatch).
  order,

  /// S6f: "Hủy đơn này?" over the transfer screen.
  cancelAsk,

  /// S2e: the order is cancelled.
  cancelled,

  /// S2c: the server confirmed the money and wrote the Pha lê.
  done,
}

/// Why a tap on "Mua" did nothing.
enum PhaleBlock { none, closed, guest }

/// The Pha lê a purchase is short of (the S4b popup).
class PhaleShort {
  const PhaleShort({
    required this.name,
    required this.price,
    required this.have,
  });

  /// What the player tried to buy.
  final String name;
  final int price;
  final int have;

  int get need => price - have;
}

/// What the shop was opened for ("Cần thêm {n} Pha lê để mua {tên}").
class PhaleContext {
  const PhaleContext({required this.need, required this.name});

  final int need;
  final String name;
}

/// State machine of the Pha lê shop (S1 to S6). It only talks to the
/// [PhaleGateway] and shows what the server says: it never adds Pha lê, not
/// even after `paid` (the balance arrives with the player's save).
class PhaleShopController extends ChangeNotifier {
  PhaleShopController({
    required this.config,
    required this.gateway,
    required this.signedIn,
    DateTime Function()? clock,
    this.autoPoll = true,
    this.onPaid,
  }) : _clock = clock ?? DateTime.now;

  final PhaleShopConfig config;
  PhaleGateway gateway;

  /// Guests cannot buy.
  final bool Function() signedIn;
  final DateTime Function() _clock;

  /// Poll the server every `config.pollSeconds` while the transfer screen is
  /// up. Tests turn it off and call [poll] themselves.
  final bool autoPoll;

  /// Called once when the server says an order is `paid`: the app claims the
  /// credit mail (`order.mailId`) there and returns the new Pha lê balance
  /// (null when it could not be claimed yet; the mail stays in the mailbox).
  /// This is the ONLY route for Pha lê into the wallet, and it is the same
  /// claim a mail gift uses, so it can land once.
  final Future<int?> Function(PhaleOrder order)? onPaid;
  String? _paidFor;

  PhaleStep step = PhaleStep.shop;
  PhaPack? pack;
  PhaleOrder? order;
  PhaleContext? context;

  /// A status request is in flight because of "Tôi đã chuyển" (S6b).
  bool checking = false;

  /// The last status request failed (S6e). The order is kept.
  bool offline = false;

  Timer? _timer;
  DateTime? _lastCheck;
  Duration _skew = Duration.zero;
  bool _disposed = false;

  bool get open => config.open;

  PhaleBlock get block {
    if (!open) return PhaleBlock.closed;
    if (!signedIn()) return PhaleBlock.guest;
    return PhaleBlock.none;
  }

  bool get canBuy => block == PhaleBlock.none;

  /// Server-time "now", from the device clock plus the skew the last answer
  /// showed. The countdown never trusts the device clock alone.
  DateTime get serverNow => _clock().add(_skew);

  /// Time left on the order; zero once it has run out.
  Duration get remaining {
    final o = order;
    if (o == null) return Duration.zero;
    final left = o.expiresAt.difference(serverNow);
    return left.isNegative ? Duration.zero : left;
  }

  /// The status to draw: a `pending` order whose time is up reads as expired
  /// even before the server says so.
  PhaleOrderStatus get shownStatus {
    final o = order;
    if (o == null) return PhaleOrderStatus.pending;
    if (o.status == PhaleOrderStatus.pending && remaining == Duration.zero) {
      return PhaleOrderStatus.expired;
    }
    return o.status;
  }

  /// An order that still waits for money (S6g strip on S1).
  bool get hasPending =>
      order != null && shownStatus == PhaleOrderStatus.pending;

  // --- opening and closing -------------------------------------------------

  /// Opens S1. [need]/[name] add the banner of the shortfall popup.
  void start({int? need, String? name}) {
    context = need != null && need > 0 && name != null
        ? PhaleContext(need: need, name: name)
        : null;
    // A finished or dead order is not shown again; a live one stays for S6g.
    if (order != null && !hasPending) order = null;
    step = PhaleStep.shop;
    pack = null;
    _stopTimer();
    notifyListeners();
  }

  /// Leaving the shop. A waiting order is NOT cancelled.
  void leave() {
    _stopTimer();
    step = PhaleStep.shop;
    pack = null;
    context = null;
    notifyListeners();
  }

  // --- buying ---------------------------------------------------------------

  /// A tap on "Mua" of [id]: S2a, unless the shop is closed or the player is a
  /// guest (the caller shows the toast for the returned reason).
  PhaleBlock pick(String id) {
    final b = block;
    if (b != PhaleBlock.none) return b;
    final p = config.pack(id);
    if (p == null) return PhaleBlock.closed;
    pack = p;
    step = PhaleStep.confirm;
    notifyListeners();
    return PhaleBlock.none;
  }

  /// S2a "Để sau" / S2d "Để sau".
  void later() {
    step = PhaleStep.shop;
    pack = null;
    notifyListeners();
  }

  /// S2a "Mua": S2b, then S6a, or S2d.
  Future<void> confirmBuy() async {
    final p = pack;
    if (p == null || step == PhaleStep.creating) return;
    if (block != PhaleBlock.none) return;
    step = PhaleStep.creating;
    notifyListeners();
    try {
      final o = await phaleGuard(() => gateway.createOrder(p.id));
      if (_disposed || step != PhaleStep.creating) return;
      _accept(o);
      offline = false;
      step = PhaleStep.order;
      _startTimer();
    } on PhaleException {
      if (_disposed || step != PhaleStep.creating) return;
      step = PhaleStep.createFailed;
    }
    notifyListeners();
  }

  /// S2d "Thử lại": back to S2a.
  void retry() {
    step = PhaleStep.confirm;
    notifyListeners();
  }

  // --- the transfer screen ----------------------------------------------------

  /// S6g "Xem đơn".
  void viewOrder() {
    if (!hasPending) return;
    step = PhaleStep.order;
    _startTimer();
    notifyListeners();
  }

  /// Back arrow of the transfer screen: the order stays alive.
  void backToShop() {
    _stopTimer();
    step = PhaleStep.shop;
    notifyListeners();
  }

  void _accept(PhaleOrder o) {
    order = o;
    final st = o.serverTime;
    if (st != null) _skew = st.difference(_clock());
  }

  void _claimPaid(PhaleOrder paid) {
    final claim = onPaid;
    if (claim == null || _paidFor == paid.orderId) return;
    _paidFor = paid.orderId;
    unawaited(() async {
      int? balance;
      try {
        balance = await claim(paid);
      } catch (_) {
        balance = null;
      }
      if (_disposed || balance == null || order?.orderId != paid.orderId) {
        return;
      }
      order = order!.copyWith(newBalance: balance);
      notifyListeners();
    }());
  }

  /// Asks the server for the order's state and moves the screen with it.
  /// A failure only sets [offline]; the order stays.
  Future<void> poll() async {
    final o = order;
    if (o == null || _disposed) return;
    if (step != PhaleStep.order && step != PhaleStep.cancelAsk) return;
    try {
      final fresh = await phaleGuard(() => gateway.orderStatus(o.orderId));
      if (_disposed || order?.orderId != o.orderId) return;
      offline = false;
      _accept(fresh);
      if (fresh.status == PhaleOrderStatus.paid) {
        _stopTimer();
        step = PhaleStep.done;
        _claimPaid(fresh);
      } else if (fresh.status == PhaleOrderStatus.cancelled) {
        _stopTimer();
        step = PhaleStep.cancelled;
      } else if (fresh.status != PhaleOrderStatus.pending) {
        _stopTimer();
      }
    } on PhaleException {
      if (_disposed) return;
      offline = true;
    }
    notifyListeners();
  }

  /// "Tôi đã chuyển": only asks the server again, never credits anything.
  /// Returns true when the order is still waiting (the caller toasts "Chưa thấy
  /// tiền về"). Taps closer than `checkGapSeconds` are ignored (null).
  Future<bool?> tapPaid() async {
    if (checking || order == null) return null;
    final now = _clock();
    final last = _lastCheck;
    if (last != null &&
        now.difference(last) < Duration(seconds: config.checkGapSeconds)) {
      return null;
    }
    _lastCheck = now;
    checking = true;
    notifyListeners();
    await poll();
    checking = false;
    notifyListeners();
    return step == PhaleStep.order && shownStatus == PhaleOrderStatus.pending;
  }

  // --- cancelling -------------------------------------------------------------

  /// "Hủy đơn": S6f, always asks.
  void askCancel() {
    if (order == null) return;
    step = PhaleStep.cancelAsk;
    notifyListeners();
  }

  /// S6f "Giữ đơn".
  void keepOrder() {
    step = PhaleStep.order;
    notifyListeners();
  }

  /// S6f "Hủy đơn": the server kills the QR, then S2e. If the server cannot be
  /// reached the order is kept and the screen goes offline (never a silent
  /// local cancel: the QR could still be paid).
  Future<void> confirmCancel() async {
    final o = order;
    if (o == null) return;
    try {
      await phaleGuard(() => gateway.cancelOrder(o.orderId));
    } on PhaleException {
      if (_disposed) return;
      offline = true;
      step = PhaleStep.order;
      notifyListeners();
      return;
    }
    if (_disposed) return;
    _stopTimer();
    pack = config.pack(o.packId);
    order = null;
    step = PhaleStep.cancelled;
    notifyListeners();
  }

  /// S2e / S6c "Tạo đơn mới": back to S2a with the same pack.
  void newOrder() {
    final id = order?.packId ?? pack?.id;
    final p = id == null ? null : config.pack(id);
    order = null;
    _stopTimer();
    if (p == null) {
      step = PhaleStep.shop;
      pack = null;
    } else {
      pack = p;
      step = PhaleStep.confirm;
    }
    notifyListeners();
  }

  /// S2e / S6c / S6d "Đóng": back to S1, the dead order is dropped.
  void closeOrder() {
    order = null;
    pack = null;
    _stopTimer();
    step = PhaleStep.shop;
    notifyListeners();
  }

  /// S2c "Xong".
  void finish() => closeOrder();

  // --- polling ------------------------------------------------------------------

  void _startTimer() {
    _stopTimer();
    if (!autoPoll) return;
    _timer = Timer.periodic(
      Duration(seconds: config.pollSeconds),
      (_) => unawaited(poll()),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}
