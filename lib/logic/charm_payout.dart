import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/economy.dart';
import 'charm_rewards.dart';

/// What the automatic season payout (functions/payout.js) did with one row.
/// Written to `charm_board/{period}/review/{uid}`.
enum PayoutStatus {
  /// The reward mail exists.
  sent('sent'),

  /// Anomalous: no mail, waiting for the admin ("Duyệt thưởng").
  held('held'),

  /// Dropped from the board (no save, no pet, under 20): no reward.
  skipped('skipped'),

  /// The mail write failed; the next tick retries.
  failed('failed'),

  /// A held row the admin paid.
  released('released');

  const PayoutStatus(this.key);
  final String key;

  static PayoutStatus? fromKey(Object? raw) {
    for (final s in values) {
      if (s.key == raw) return s;
    }
    return null;
  }
}

/// Why a row was held (`flags`) or dropped (`reason`) by the payout.
String payoutFlagText(String key) => switch (key) {
  'mismatch' => 'Mị lực tính lại khác bảng',
  'over_cap' => 'Mị lực trên 600',
  'new_account' => 'Tài khoản lập trong mùa',
  'no_save' => 'Không đọc được save',
  'no_pet' => 'Ô Mị lực không có thú',
  'under_min' => 'Dưới mức tối thiểu',
  _ => key,
};

@immutable
class PayoutLine {
  const PayoutLine({
    required this.uid,
    required this.status,
    this.displayName = '',
    this.rank = 0,
    this.stored = 0,
    this.recomputed = 0,
    this.flags = const [],
    this.reason,
    this.petId = '',
    this.stage = 0,
    this.mailId,
  });

  final String uid;
  final PayoutStatus status;
  final String displayName;

  /// 0 for a dropped row.
  final int rank;

  /// What the board said / what the save gives.
  final int stored;
  final int recomputed;

  /// Why a held row is held.
  final List<String> flags;

  /// Why a dropped row was dropped.
  final String? reason;
  final String petId;
  final int stage;
  final String? mailId;

  /// The words shown next to the row.
  List<String> get why => [
    for (final f in flags) payoutFlagText(f),
    if (reason != null) payoutFlagText(reason!),
  ];

  PayoutLine copyWith({PayoutStatus? status}) => PayoutLine(
    uid: uid,
    status: status ?? this.status,
    displayName: displayName,
    rank: rank,
    stored: stored,
    recomputed: recomputed,
    flags: flags,
    reason: reason,
    petId: petId,
    stage: stage,
    mailId: mailId,
  );
}

/// `charm_board/{period}.payout`, the summary of the run, and the season end.
@immutable
class PayoutMeta {
  const PayoutMeta({
    this.status,
    this.endsAt,
    this.at,
    this.sent = 0,
    this.held = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  /// `done`, `partial`, or null while the payout has not run.
  final String? status;
  final DateTime? endsAt;
  final DateTime? at;
  final int sent;
  final int held;
  final int skipped;
  final int failed;

  bool get ran => status == 'done' || status == 'partial';
}

/// Admin side of the automatic payout: what it did, the kill switch, and the
/// release of a held row.
abstract class CharmPayoutStore {
  Future<PayoutMeta> meta(String period);
  Future<List<PayoutLine>> lines(String period);

  /// `config/charmPayout.autoPayout`; true when the doc is missing.
  Future<bool> autoPayout();
  Future<void> setAutoPayout(bool on);

  /// Marks a held line paid by the admin.
  Future<void> markReleased(String period, String uid);
}

/// In-memory store for tests and previews.
class MemoryCharmPayoutStore implements CharmPayoutStore {
  MemoryCharmPayoutStore({
    this.metas = const {},
    Map<String, List<PayoutLine>>? lines,
    this.auto = true,
  }) : _lines = lines ?? {};

  final Map<String, PayoutMeta> metas;
  final Map<String, List<PayoutLine>> _lines;
  bool auto;
  final List<(String, String)> released = [];

  @override
  Future<PayoutMeta> meta(String period) async =>
      metas[period] ?? const PayoutMeta();

  @override
  Future<List<PayoutLine>> lines(String period) async => [...?_lines[period]];

  @override
  Future<bool> autoPayout() async => auto;

  @override
  Future<void> setAutoPayout(bool on) async => auto = on;

  @override
  Future<void> markReleased(String period, String uid) async {
    released.add((period, uid));
    final list = _lines[period];
    if (list == null) return;
    _lines[period] = [
      for (final l in list)
        l.uid == uid ? l.copyWith(status: PayoutStatus.released) : l,
    ];
  }
}

/// The admin page's view of one season's payout: sent / skipped / held rows,
/// the kill switch, and releasing held rows one by one.
class CharmPayoutController extends ChangeNotifier {
  CharmPayoutController({
    required this.payout,
    required this.rewards,
    required this.economy,
    required this.period,
    Random? random,
  }) : _random = random ?? Random();

  final CharmPayoutStore payout;
  final CharmRewardStore rewards;
  final Economy economy;
  final Random _random;
  String period;

  bool loading = false;
  bool failed = false;
  PayoutMeta meta = const PayoutMeta();
  List<PayoutLine> lines = const [];
  bool autoPayout = true;

  /// The switch is being written.
  bool savingSwitch = false;

  /// The uids being released right now (double taps are ignored).
  final Set<String> releasing = {};

  List<PayoutLine> get held => _of(PayoutStatus.held);
  List<PayoutLine> get sent => [
    ..._of(PayoutStatus.sent),
    ..._of(PayoutStatus.released),
  ];
  List<PayoutLine> get skipped => _of(PayoutStatus.skipped);
  List<PayoutLine> get failedLines => _of(PayoutStatus.failed);

  List<PayoutLine> _of(PayoutStatus s) => [
    for (final l in lines)
      if (l.status == s) l,
  ];

  Future<void> load() async {
    loading = true;
    failed = false;
    notifyListeners();
    try {
      meta = await payout.meta(period);
      lines = await payout.lines(period)
        ..sort((a, b) {
          if (a.rank == 0 || b.rank == 0) return b.rank.compareTo(a.rank);
          return a.rank.compareTo(b.rank);
        });
      autoPayout = await payout.autoPayout();
    } catch (_) {
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setAutoPayout(bool on) async {
    if (savingSwitch) return;
    savingSwitch = true;
    notifyListeners();
    try {
      await payout.setAutoPayout(on);
      autoPayout = on;
    } catch (_) {
      // The switch snaps back: the write did not happen.
    }
    savingSwitch = false;
    notifyListeners();
  }

  /// "Duyệt thưởng" on one held row: writes that player's reward mail
  /// (create-only, so pressing twice cannot pay twice) with an item picked
  /// now, then marks the line released. False when it could not be done.
  Future<bool> release(PayoutLine line) async {
    if (line.status != PayoutStatus.held || line.rank < 1) return false;
    if (!releasing.add(line.uid)) return false;
    notifyListeners();
    var ok = false;
    try {
      final reward = economy.charmBoard.rewardFor(line.rank);
      if (reward != null) {
        final bundle = charmRewardBundle(reward, economy, _random);
        if (bundle.isNotEmpty) {
          await rewards.grant(
            charmRewardMail(
              period: period,
              rank: line.rank,
              uid: line.uid,
              rewards: bundle,
            ),
          );
        }
        await payout.markReleased(period, line.uid);
        ok = true;
      }
    } catch (_) {
      ok = false;
    }
    releasing.remove(line.uid);
    if (ok) {
      lines = [
        for (final l in lines)
          l.uid == line.uid ? l.copyWith(status: PayoutStatus.released) : l,
      ];
    }
    notifyListeners();
    return ok;
  }
}
