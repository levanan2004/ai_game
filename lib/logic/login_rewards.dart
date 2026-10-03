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

/// `config/loginRewards` still has the old one-table shape. The game
/// ignores it; the admin editor says so and offers to save the new shape.
class LegacyLoginConfig implements Exception {
  const LegacyLoginConfig();

  @override
  String toString() => 'config/loginRewards uses the old one-table shape';
}

/// One-time gift for reaching [day] check-in days in total.
@immutable
class LoginMilestone {
  const LoginMilestone(this.day, this.rewards);

  /// Total claimed days (all weeks) that unlocks it.
  final int day;
  final RewardBundle rewards;

  Map<String, Object?> toJson() => {'day': day, 'rewards': rewards.toJson()};

  static LoginMilestone? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    if (day is! int || day < 1) return null;
    final rewards = RewardBundle.fromJson(raw['rewards']);
    if (rewards.isEmpty) return null;
    return LoginMilestone(day, rewards);
  }

  @override
  bool operator ==(Object other) =>
      other is LoginMilestone && other.day == day && other.rewards == rewards;

  @override
  int get hashCode => Object.hash(day, rewards);
}

/// Hà Phương's tables (approved by An), used while `config/loginRewards`
/// is missing, broken or still in the old one-table shape.
final defaultLoginRewards = LoginRewardConfig(
  // Tuần tân thủ: the first week only, once per account.
  newbie: [
    RewardBundle(const [RewardItem.giotHoa(10)]),
    RewardBundle(const [RewardItem.pot('dragon')]),
    RewardBundle(const [RewardItem.phaLe(50)]),
    RewardBundle(const [RewardItem.treat(4)]),
    RewardBundle(const [RewardItem.coins(50000)]),
    RewardBundle(const [RewardItem.pot('tiger'), RewardItem.giotHoa(20)]),
    RewardBundle(const [RewardItem.phaLe(150), RewardItem.giotHoa(25)]),
  ],
  // From week 2, every week.
  weekly: [
    RewardBundle(const [RewardItem.treat(1)]),
    RewardBundle(const [RewardItem.coins(30000)]),
    RewardBundle(const [RewardItem.phaLe(10)]),
    RewardBundle(const [RewardItem.treat(2)]),
    RewardBundle(const [RewardItem.coins(50000)]),
    RewardBundle(const [RewardItem.giotHoa(3)]),
    RewardBundle(const [RewardItem.phaLe(30), RewardItem.giotHoa(5)]),
  ],
  milestones: [
    LoginMilestone(14, RewardBundle(const [RewardItem.pot('koi')])),
    LoginMilestone(30, RewardBundle(const [RewardItem.pot('crane')])),
  ],
);

/// `config/loginRewards`, edited in /quan-tri. Nothing in the game reads a
/// day's gift any other way, so the numbers can change at any time.
///
/// Firestore shape (version 2):
/// `{version: 2, newbie: [7 bundles], weekly: [7 bundles],
///   milestones: [{day, rewards}], repeat, consecutive, updatedAt}`.
/// The old one-table shape (`{days, repeat, consecutive}`, no version) is
/// ignored: the game uses [defaultLoginRewards] until an admin saves again.
@immutable
class LoginRewardConfig {
  LoginRewardConfig({
    required List<RewardBundle> newbie,
    required List<RewardBundle> weekly,
    List<LoginMilestone> milestones = const [],
    this.repeat = true,
    this.consecutive = false,
  }) : newbie = _seven(newbie),
       weekly = _seven(weekly),
       milestones = List.unmodifiable(
         [...milestones]..sort((a, b) => a.day.compareTo(b.day)),
       );

  static const version = 2;

  /// Most milestones the rules accept.
  static const maxMilestones = 10;

  static List<RewardBundle> _seven(List<RewardBundle> days) =>
      List.unmodifiable([
        for (var i = 0; i < loginRewardDays; i++)
          i < days.length ? days[i] : RewardBundle.empty,
      ]);

  /// Week 1 (cycle 1), day 1 first. Claimable once per account.
  final List<RewardBundle> newbie;

  /// Week 2 on (cycle 2+), day 1 first.
  final List<RewardBundle> weekly;

  /// One-time gifts by total check-in days, lowest first.
  final List<LoginMilestone> milestones;

  /// After day 7, a new week starts on the next day (with [weekly]). Off:
  /// the board stops after the newbie week.
  final bool repeat;

  /// A missed day starts the week again from day 1. Off (default): only
  /// claimed days count.
  final bool consecutive;

  /// The table for week [cycle] (1 = newbie week).
  List<RewardBundle> table(int cycle) => cycle <= 1 ? newbie : weekly;

  /// Day [n] (1..7) of week [cycle].
  RewardBundle day(int n, {int cycle = 1}) => table(cycle)[n - 1];

  LoginRewardConfig copyWith({
    List<RewardBundle>? newbie,
    List<RewardBundle>? weekly,
    List<LoginMilestone>? milestones,
    bool? repeat,
    bool? consecutive,
  }) => LoginRewardConfig(
    newbie: newbie ?? this.newbie,
    weekly: weekly ?? this.weekly,
    milestones: milestones ?? this.milestones,
    repeat: repeat ?? this.repeat,
    consecutive: consecutive ?? this.consecutive,
  );

  /// Day [n] of the newbie table, or of the weekly one when [weekly].
  LoginRewardConfig withDay(
    int n,
    RewardBundle bundle, {
    bool weekly = false,
  }) => weekly
      ? copyWith(weekly: [...this.weekly]..[n - 1] = bundle)
      : copyWith(newbie: [...newbie]..[n - 1] = bundle);

  /// Milestones reached by going from [before] to [after] total days.
  List<LoginMilestone> reached(int before, int after) => [
    for (final m in milestones)
      if (m.day > before && m.day <= after) m,
  ];

  /// Everything one claim gives: day [day] of the claimed week plus any
  /// milestone it reached. [before] is the state the claim started from.
  RewardBundle claimReward(LoginState before, LoginState after, int day) {
    final from = after.claimedCount == 1 && before.claimedCount < 7
        // A restart after a missed day ('consecutive') jumps the week.
        ? before.totalDays
        : after.totalDays - 1;
    return RewardBundle([
      ...this.day(day, cycle: after.cycle).items,
      for (final m in reached(from, after.totalDays)) ...m.rewards.items,
    ]);
  }

  Map<String, Object?> toMap() => {
    'version': version,
    'newbie': [for (final d in newbie) d.toJson()],
    'weekly': [for (final d in weekly) d.toJson()],
    'milestones': [for (final m in milestones) m.toJson()],
    'repeat': repeat,
    'consecutive': consecutive,
  };

  /// The old one-table doc (`days`, no `version`).
  static bool isLegacyMap(Object? raw) =>
      raw is Map && raw['version'] == null && raw['days'] is List;

  /// Null when [raw] is not a usable version-2 table (the caller falls back
  /// to [defaultLoginRewards]). The legacy shape is null too.
  static LoginRewardConfig? fromMap(Object? raw) {
    if (raw is! Map || raw['version'] != version) return null;
    List<RewardBundle>? week(Object? list) =>
        list is List && list.length == loginRewardDays
        ? [for (final d in list) RewardBundle.fromJson(d)]
        : null;
    final newbie = week(raw['newbie']);
    final weekly = week(raw['weekly']);
    if (newbie == null || weekly == null) return null;
    final ms = raw['milestones'];
    return LoginRewardConfig(
      newbie: newbie,
      weekly: weekly,
      milestones: [
        if (ms is List)
          for (final m in ms) ?LoginMilestone.fromJson(m),
      ],
      repeat: raw['repeat'] != false,
      consecutive: raw['consecutive'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoginRewardConfig &&
      listEquals(other.newbie, newbie) &&
      listEquals(other.weekly, weekly) &&
      listEquals(other.milestones, milestones) &&
      other.repeat == repeat &&
      other.consecutive == consecutive;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(newbie),
    Object.hashAll(weekly),
    Object.hashAll(milestones),
    repeat,
    consecutive,
  );
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

  /// Check-in days claimed in total, all weeks: what milestones count.
  /// Derived from the week number, so no extra field is stored. Exact
  /// unless 'consecutive' restarted a week early (then it runs ahead).
  int get totalDays => (cycle - 1) * loginRewardDays + claimedCount;

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
    this.cycle = 1,
    this.next,
  });

  /// The week the board shows (1 = newbie week).
  final int cycle;

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
      cycle: state.cycle,
    );
  }
  var count = state.claimedCount;
  var cycle = state.cycle;
  if (count >= loginRewardDays) {
    if (!config.repeat) {
      return LoginPlan(
        shownCount: loginRewardDays,
        day: 0,
        claimedToday: false,
        finished: true,
        cycle: state.cycle,
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
    cycle: cycle,
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
