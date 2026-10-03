import 'package:flutter/foundation.dart';

import 'giftcodes.dart';
import 'login_rewards.dart';
import 'rewards.dart';
import 'welfare_slides.dart';

/// The player's side of Phúc lợi. Claims run as Firestore transactions;
/// firestore.rules refuse a second claim on the same day or code.
abstract class WelfareService {
  /// `config/loginRewards`. Null when missing, broken or the old shape.
  Future<LoginRewardConfig?> loginConfig();

  Future<LoginState> loginState(String uid);

  /// Claims today's tile once. Reads the state inside the transaction, so a
  /// second tab or device gets [LoginClaimResult.already].
  Future<LoginClaimOutcome> claimLogin(
    String uid,
    LoginRewardConfig config,
    DateTime now,
  );

  /// Redeems one normalized [code] for [uid].
  Future<RedeemOutcome> redeem(String uid, String code, DateTime now);

  /// Every slide (the feed hides disabled ones).
  Future<List<WelfareSlide>> slides();
}

/// Admin side (`/quan-tri`). The rules reject everyone else.
abstract class WelfareAdmin {
  /// Null when missing. Throws [LegacyLoginConfig] for the old shape.
  Future<LoginRewardConfig?> loadLoginConfig();
  Future<void> saveLoginConfig(LoginRewardConfig config);

  String newBatchId();
  Future<List<GiftcodeBatch>> loadBatches();
  Future<bool> codeExists(String code);

  /// One `giftcodeBatches/{id}` plus `giftcodes/{batch.code}`.
  Future<void> createShared(GiftcodeBatch batch);

  /// The batch doc, then [codes] in writes of [giftcodeWriteChunk].
  /// [onProgress] gets the number of codes written so far.
  Future<void> createBulk(
    GiftcodeBatch batch,
    List<String> codes, {
    void Function(int written)? onProgress,
  });
  Future<void> setBatchEnabled(String batchId, bool enabled);

  /// Every code of a batch, for the CSV.
  Future<List<GiftcodeRow>> exportBatch(String batchId);

  String newSlideId();
  Future<List<WelfareSlide>> loadSlides();
  Future<void> saveSlide(WelfareSlide slide);
  Future<void> deleteSlide(String id);
}

enum WelfareTab { login, giftcode, slides }

/// What the Phúc lợi sheet shows. Claiming needs Google sign-in; the
/// "Bạn biết?" slides are public.
class WelfareFeed extends ChangeNotifier {
  WelfareFeed({this.service, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final WelfareService? service;
  final DateTime Function() _now;

  String? uid;
  LoginRewardConfig config = defaultLoginRewards;
  LoginState loginState = LoginState.none;
  List<WelfareSlide> _slides = const [];
  var open = false;
  var tab = WelfareTab.login;
  var loading = false;
  var loginBusy = false;
  var redeemBusy = false;
  String? error;

  /// Last giftcode answer, shown under the field.
  RedeemOutcome? lastRedeem;

  /// Day whose gifts the detail card shows; null when it is closed.
  int? detailDay;

  /// Last check-in answer, shown under the board.
  String? loginMessage;
  var _gone = false;

  DateTime now() => _now();

  int get today => vnDayNumber(_now());

  LoginPlan get plan => planLogin(loginState, config, today);

  /// Badge on the Phúc lợi button.
  bool get canClaimToday => uid != null && plan.canClaim;

  /// Enabled slides by order, or the built-in text cards when there are
  /// none.
  List<WelfareSlide> get slides {
    final list = visibleSlides(_slides);
    return list.isEmpty ? defaultWelfareSlides : list;
  }

  Future<void> bindUser(String? next) async {
    if (next == uid) return;
    uid = next;
    loginState = LoginState.none;
    lastRedeem = null;
    detailDay = null;
    loginMessage = null;
    error = null;
    _notify();
    await refresh();
  }

  Future<void> refresh() async {
    final store = service;
    if (store == null) return;
    final who = uid;
    loading = true;
    _notify();
    try {
      final results = await Future.wait<Object?>([
        store.loginConfig(),
        store.slides(),
        if (who != null) store.loginState(who),
      ]);
      if (_gone || who != uid) return;
      config = results[0] as LoginRewardConfig? ?? defaultLoginRewards;
      _slides = results[1] as List<WelfareSlide>;
      if (who != null) loginState = results[2] as LoginState;
      error = null;
    } catch (_) {
      if (_gone || who != uid) return;
      error = 'Chưa tải được Phúc lợi.';
    } finally {
      if (!_gone && who == uid) {
        loading = false;
        _notify();
      }
    }
  }

  void toggle() {
    open = !open;
    _notify();
    if (open) refresh();
  }

  void show(WelfareTab next) {
    tab = next;
    final opening = !open;
    open = true;
    _notify();
    if (opening) refresh();
  }

  void close() {
    open = false;
    detailDay = null;
    loginMessage = null;
    _notify();
  }

  void selectTab(WelfareTab next) {
    tab = next;
    detailDay = null;
    _notify();
  }

  /// Opens (or with null closes) the gift detail of check-in day [day].
  void showDay(int? day) {
    detailDay = day;
    _notify();
  }

  void setLoginMessage(String? message) {
    loginMessage = message;
    _notify();
  }

  /// Claims today's tile. Only the call that wrote the server state runs
  /// [grant] with that day's bundle (and a milestone gift, if reached).
  Future<LoginClaimResult> claimLogin({
    required bool allowed,
    required RewardBundle Function(RewardBundle bundle) grant,
  }) async {
    if (loginBusy) return LoginClaimResult.busy;
    final who = uid;
    final store = service;
    if (who == null || store == null || !allowed) {
      return LoginClaimResult.refused;
    }
    final now = plan;
    if (!now.canClaim) {
      return now.finished
          ? LoginClaimResult.finished
          : LoginClaimResult.already;
    }
    final table = config;
    final before = loginState;
    loginBusy = true;
    _notify();
    try {
      final outcome = await store.claimLogin(who, table, _now());
      if (_gone || who != uid) return LoginClaimResult.failed;
      loginState = outcome.state;
      if (outcome.result == LoginClaimResult.claimed && outcome.day > 0) {
        // That week's tile, plus any total-days milestone it reached.
        grant(table.claimReward(before, outcome.state, outcome.day));
      }
      return outcome.result;
    } catch (_) {
      return LoginClaimResult.failed;
    } finally {
      loginBusy = false;
      _notify();
    }
  }

  /// Redeems what the player typed. [raw] is normalized here, on submit.
  Future<RedeemOutcome> redeem(
    String raw, {
    required bool allowed,
    required RewardBundle Function(RewardBundle bundle) grant,
  }) async {
    if (redeemBusy) return RedeemOutcome(RedeemResult.busy);
    final outcome = await _redeem(raw, allowed: allowed, grant: grant);
    if (!_gone) {
      lastRedeem = outcome;
      _notify();
    }
    return outcome;
  }

  Future<RedeemOutcome> _redeem(
    String raw, {
    required bool allowed,
    required RewardBundle Function(RewardBundle bundle) grant,
  }) async {
    if (raw.trim().isEmpty) return RedeemOutcome(RedeemResult.empty);
    final who = uid;
    final store = service;
    if (who == null || store == null) {
      return RedeemOutcome(RedeemResult.signedOut);
    }
    if (!allowed) return RedeemOutcome(RedeemResult.refused);
    final code = normalizeGiftcode(raw);
    if (code == null) return RedeemOutcome(RedeemResult.invalid);
    redeemBusy = true;
    _notify();
    try {
      final outcome = await store.redeem(who, code, _now());
      if (_gone || who != uid) return RedeemOutcome(RedeemResult.failed);
      if (outcome.result == RedeemResult.success) grant(outcome.rewards);
      return outcome;
    } catch (_) {
      return RedeemOutcome(RedeemResult.failed);
    } finally {
      redeemBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_gone) notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
