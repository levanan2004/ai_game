import 'package:flutter/foundation.dart';

import 'rewards.dart';

/// Điểm danh 7 ngày: one tile per calendar day in Việt Nam.
const loginRewardDays = 7;

/// Asia/Ho_Chi_Minh is UTC+7 all year (no daylight saving).
const vnUtcOffset = Duration(hours: 7);

/// Calendar day number in Việt Nam: whole days since 1970-01-01 there.
/// firestore.rules computes the same number from `request.time`.
int vnDayNumber(DateTime time) =>
    (time.toUtc().millisecondsSinceEpoch + vnUtcOffset.inMilliseconds) ~/
    Duration.millisecondsPerDay;

/// Time left until the next Việt Nam midnight, when a new tile opens.
Duration untilNextVnDay(DateTime now) {
  final next =
      (vnDayNumber(now) + 1) * Duration.millisecondsPerDay -
      vnUtcOffset.inMilliseconds;
  return Duration(milliseconds: next - now.toUtc().millisecondsSinceEpoch);
}

/// "2026-10-03" for [time] in Việt Nam.
String vnDateKey(DateTime time) {
  final v = time.toUtc().add(vnUtcOffset);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${v.year}-${two(v.month)}-${two(v.day)}';
}

/// The owner's table, used while `config/loginRewards` is missing or broken.
final defaultLoginRewards = LoginRewardConfig(
  days: [
    RewardBundle(const [RewardItem.giotHoa(10)]),
    RewardBundle(const [RewardItem.pot('dragon')]),
    RewardBundle(const [RewardItem.phaLe(100)]),
    RewardBundle(const [RewardItem.pot('koi')]),
    RewardBundle(const [RewardItem.pot('crane')]),
    RewardBundle(const [RewardItem.pot('tiger'), RewardItem.giotHoa(20)]),
    RewardBundle(const [RewardItem.phaLe(900), RewardItem.giotHoa(25)]),
  ],
);

/// `config/loginRewards`, edited in /quan-tri. Nothing in the game reads a
/// day's gift any other way, so the numbers can change at any time.
@immutable
class LoginRewardConfig {
  LoginRewardConfig({
    required List<RewardBundle> days,
    this.repeat = false,
    this.consecutive = false,
  }) : days = List.unmodifiable([
         for (var i = 0; i < loginRewardDays; i++)
           i < days.length ? days[i] : RewardBundle.empty,
       ]);

  /// Always [loginRewardDays] bundles, day 1 first.
  final List<RewardBundle> days;

  /// After day 7, a new cycle starts on the next day. Off: the table stops.
  final bool repeat;

  /// A missed day starts again from day 1. Off (default): only claimed
  /// days count.
  final bool consecutive;

  RewardBundle day(int n) => days[n - 1];

  LoginRewardConfig copyWith({
    List<RewardBundle>? days,
    bool? repeat,
    bool? consecutive,
  }) => LoginRewardConfig(
    days: days ?? this.days,
    repeat: repeat ?? this.repeat,
    consecutive: consecutive ?? this.consecutive,
  );

  LoginRewardConfig withDay(int n, RewardBundle bundle) =>
      copyWith(days: [...days]..[n - 1] = bundle);

  Map<String, Object?> toMap() => {
    'days': [for (final d in days) d.toJson()],
    'repeat': repeat,
    'consecutive': consecutive,
  };

  /// Null when [raw] is not a usable table (the caller falls back to
  /// [defaultLoginRewards]).
  static LoginRewardConfig? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final list = raw['days'];
    if (list is! List || list.length != loginRewardDays) return null;
    return LoginRewardConfig(
      days: [for (final d in list) RewardBundle.fromJson(d)],
      repeat: raw['repeat'] == true,
      consecutive: raw['consecutive'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoginRewardConfig &&
      listEquals(other.days, days) &&
      other.repeat == repeat &&
      other.consecutive == consecutive;

  @override
  int get hashCode => Object.hash(Object.hashAll(days), repeat, consecutive);
}

/// `users/{uid}/welfare/login`, written only through a claim.
@immutable
class LoginState {
  const LoginState({this.claimedCount = 0, this.lastClaimDay, this.cycle = 1});

  static const none = LoginState();

  /// Tiles claimed in this [cycle], 0..7.
  final int claimedCount;

  /// [vnDayNumber] of the last claim. Null before the first one.
  final int? lastClaimDay;
  final int cycle;

  static LoginState fromMap(Map<String, Object?>? data) {
    if (data == null) return none;
    final count = data['claimedCount'];
    final day = data['lastClaimDay'];
    final cycle = data['cycle'];
    return LoginState(
      claimedCount: count is int ? count.clamp(0, loginRewardDays) : 0,
      lastClaimDay: day is int ? day : null,
      cycle: cycle is int && cycle > 0 ? cycle : 1,
    );
  }

  /// Fields the claim writes, besides `lastClaimDate` and `lastClaimAt`.
  Map<String, Object?> toMap() => {
    'claimedCount': claimedCount,
    'lastClaimDay': lastClaimDay,
    'cycle': cycle,
  };

  @override
  bool operator ==(Object other) =>
      other is LoginState &&
      other.claimedCount == claimedCount &&
      other.lastClaimDay == lastClaimDay &&
      other.cycle == cycle;

  @override
  int get hashCode => Object.hash(claimedCount, lastClaimDay, cycle);

  @override
  String toString() => 'LoginState($claimedCount, $lastClaimDay, c$cycle)';
}

enum LoginTile { claimed, today, locked }

/// What the Điểm danh tab shows today, and the state a claim would write.
@immutable
class LoginPlan {
  const LoginPlan({
    required this.shownCount,
    required this.day,
    required this.claimedToday,
    required this.finished,
    this.next,
  });

  /// Tiles drawn as "đã nhận".
  final int shownCount;

  /// Tile that can be claimed now (1..7), or 0.
  final int day;
  final bool claimedToday;

  /// All 7 claimed and the table does not repeat.
  final bool finished;

  /// State after claiming [day]. Null when nothing can be claimed.
  final LoginState? next;

  bool get canClaim => next != null;

  LoginTile tile(int n) => n <= shownCount
      ? LoginTile.claimed
      : n == day
      ? LoginTile.today
      : LoginTile.locked;
}

/// The one rule for claiming, shared by the screen, the transaction and the
/// tests (firestore.rules checks the same steps).
LoginPlan planLogin(LoginState state, LoginRewardConfig config, int today) {
  final last = state.lastClaimDay;
  if (last != null && last >= today) {
    // Claimed today (or this device's clock is behind the last claim).
    return LoginPlan(
      shownCount: state.claimedCount,
      day: 0,
      claimedToday: true,
      finished: false,
    );
  }
  var count = state.claimedCount;
  var cycle = state.cycle;
  if (count >= loginRewardDays) {
    if (!config.repeat) {
      return const LoginPlan(
        shownCount: loginRewardDays,
        day: 0,
        claimedToday: false,
        finished: true,
      );
    }
    count = 0;
    cycle++;
  } else if (config.consecutive &&
      count > 0 &&
      last != null &&
      today - last > 1) {
    count = 0;
    cycle++;
  }
  return LoginPlan(
    shownCount: count,
    day: count + 1,
    claimedToday: false,
    finished: false,
    next: LoginState(
      claimedCount: count + 1,
      lastClaimDay: today,
      cycle: cycle,
    ),
  );
}

enum LoginClaimResult {
  /// Today's tile was added just now.
  claimed,

  /// Today was already claimed (here, in another tab or on another device).
  already,

  /// Day 7 is done and the table does not repeat.
  finished,

  /// A claim is still running (double tap).
  busy,

  /// Not signed in, or this tab may not write the account now.
  refused,

  /// Network, rules, or this device's clock is on another day.
  failed,
}

@immutable
class LoginClaimOutcome {
  const LoginClaimOutcome(this.result, this.state, {this.day = 0});

  final LoginClaimResult result;

  /// The server's state after the attempt.
  final LoginState state;

  /// Day claimed (1..7) when [result] is [LoginClaimResult.claimed].
  final int day;
}
