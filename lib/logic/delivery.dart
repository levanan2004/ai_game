import 'dart:math';

import '../data/economy.dart';
import 'bouquet.dart';
import 'customers.dart';
import 'match_scoring.dart';
import 'payment.dart';

/// Designer note on `dailyGoals` `online_orders`: the target is capped at
/// 2 × shippers hired. The 2 lives only in that note (no JSON field).
const onlineGoalCapPerShipper = 2;

enum OrderKind { preorder, sameday }

enum OrderStatus {
  offered,
  declined,
  accepted,
  packed,
  dispatched,
  done,
  missed,
  cancelled,
}

/// One online order for today. Not saved: a reload replays the morning.
class OnlineOrder {
  OnlineOrder({
    required this.id,
    required this.kind,
    required this.customerName,
    required this.avatarId,
    required this.request,
    required this.line,
    required this.deadline,
    required this.spawnAt,
    required this.acceptLeft,
  });

  final int id;
  final OrderKind kind;
  final String customerName;
  final String avatarId;
  final BouquetRequest request;

  /// Short "7 Hồng · giấy kraft · nơ satin" line.
  final String line;
  final double deadline;
  final double spawnAt;
  double acceptLeft;
  OrderStatus status = OrderStatus.offered;

  /// Stems held back from walk-ins, still sitting in stock until packed.
  final Map<String, int> reserved = {};

  /// Stem uids taken from the reservation into the draft.
  final Set<int> reservedUids = {};

  /// Bundles this preorder added to the market cart.
  final Map<String, int> cartBundles = {};

  Bouquet? bouquet;
  Tier tier = Tier.okay;
  bool wrapHit = false;
  int bouquetPrice = 0;
  String? shipperId;
  int payout = 0;
  bool late = false;

  bool get open =>
      status == OrderStatus.accepted ||
      status == OrderStatus.packed ||
      status == OrderStatus.dispatched;

  bool get waitingDispatch =>
      status == OrderStatus.accepted || status == OrderStatus.packed;
}

/// A hired vehicle for today.
class ShipperRun {
  ShipperRun({
    required this.id,
    required this.capacity,
    required this.deliverSeconds,
    required this.returnSeconds,
  });

  final String id;
  final int capacity;
  final double deliverSeconds;
  final double returnSeconds;

  final List<int> load = [];
  double loadStarted = 0;
  final List<int> trip = [];
  final Map<int, double> handoverAt = {};
  double departAt = -1;
  double routeDoneAt = -1;
  double backAt = -1;
  int handed = 0;
  String? floatText;
  double floatLeft = 0;

  bool awayAt(double t) => departAt >= 0 && t < backAt;

  bool deliveringAt(double t) => departAt >= 0 && t < routeDoneAt;

  bool returningAt(double t) => departAt >= 0 && t >= routeDoneAt && t < backAt;
}

/// Why the shipper button cannot be used.
enum ShipperBlock { locked, shopOpen, debt, poor, maxed }

class ShipperOffer {
  const ShipperOffer({
    required this.level,
    required this.cost,
    required this.label,
    required this.lockLabel,
    this.block,
    this.nextName,
  });

  final int level;
  final int cost;
  final String label;
  final String? lockLabel;
  final ShipperBlock? block;
  final String? nextName;

  bool get canBuy => block == null;
  bool get hired => level > 0;
}

Map<String, int> stemNeeds(BouquetRequest r) {
  final m = Map<String, int>.from(r.stems);
  if (r.fillerId != null && r.fillerCount > 0) {
    m[r.fillerId!] = (m[r.fillerId!] ?? 0) + r.fillerCount;
  }
  return m;
}

/// "giấy kraft" when the paper is already named Giấy …, not "giấy giấy kraft".
String _kindLabel(String kind, String name) {
  final lower = name.toLowerCase();
  if (lower.startsWith('$kind ')) return lower;
  return '$kind $lower';
}

String orderLine(Economy e, BouquetRequest r) {
  final parts = <String>[
    for (final en in r.stems.entries) '${en.value} ${e.flower(en.key).nameVi}',
    if (r.fillerId != null && r.fillerCount > 0)
      '${r.fillerCount} ${e.flower(r.fillerId!).nameVi}',
    _kindLabel('giấy', e.paper(r.paperId).nameVi),
    _kindLabel('nơ', e.ribbon(r.ribbonId).nameVi),
  ];
  return parts.join(' · ');
}

/// Short strip title: the species with the most stems.
String orderShort(Economy e, BouquetRequest r) {
  final main = r.stems.entries.reduce((a, b) => b.value > a.value ? b : a);
  return '${main.value} ${e.flower(main.key).nameVi}';
}

int shippersHiredCount(Map<String, int> levels) =>
    levels.values.where((v) => v > 0).length;

double demandBonus(Economy e, Map<String, int> levels) {
  var sum = 0.0;
  for (final s in e.delivery.shippers) {
    if ((levels[s.id] ?? 0) > 0) sum += s.demandBonusPerDay;
  }
  return sum;
}

int shipperWages(Economy e, Map<String, int> levels) {
  var sum = 0;
  for (final s in e.delivery.shippers) {
    if ((levels[s.id] ?? 0) > 0) sum += s.dailyWage;
  }
  return sum;
}

/// `delivery.unlock` plus each shipper's `unlock` object.
bool shipperIsUnlocked(
  Economy e,
  ShipperDef shipper, {
  required int day,
  required int rank,
  required Map<String, int> levels,
}) {
  final u = shipper.unlock;
  if (u.day != null && day < u.day!) return false;
  if (u.rank != null && rank < u.rank!) return false;
  if (u.shipper != null && (levels[u.shipper!] ?? 0) < 1) return false;
  return true;
}

/// First failing reason, in the order the spec prints on the button.
String? shipperLockLabel(
  Economy e,
  ShipperDef shipper, {
  required int day,
  required int rank,
  required Map<String, int> levels,
}) {
  final u = shipper.unlock;
  if (u.day != null && day < u.day!) return 'Mở ngày ${u.day}';
  if (u.rank != null && rank < u.rank!) return 'Cần hạng ${u.rank}';
  if (u.shipper != null && (levels[u.shipper!] ?? 0) < 1) {
    return 'Cần ${e.delivery.shipper(u.shipper!).nameVi}';
  }
  return null;
}

ShipperOffer shipperOffer(
  Economy e,
  ShipperDef shipper, {
  required int day,
  required int rank,
  required Map<String, int> levels,
  required int money,
  required bool shopClosed,
}) {
  final level = levels[shipper.id] ?? 0;
  final lock = shipperLockLabel(
    e,
    shipper,
    day: day,
    rank: rank,
    levels: levels,
  );
  if (level <= 0) {
    if (lock != null) {
      return ShipperOffer(
        level: 0,
        cost: shipper.hireCost,
        label: lock,
        lockLabel: lock,
        block: ShipperBlock.locked,
      );
    }
    ShipperBlock? block;
    if (!shopClosed) {
      block = ShipperBlock.shopOpen;
    } else if (money < 0) {
      block = ShipperBlock.debt;
    } else if (money < shipper.hireCost) {
      block = ShipperBlock.poor;
    }
    return ShipperOffer(
      level: 0,
      cost: shipper.hireCost,
      label: 'Thuê',
      lockLabel: null,
      block: block,
    );
  }
  if (level >= shipper.levels.length) {
    return ShipperOffer(
      level: level,
      cost: 0,
      label: 'Tối đa',
      lockLabel: null,
      block: ShipperBlock.maxed,
    );
  }
  final next = shipper.levels[level];
  ShipperBlock? block;
  if (!shopClosed) {
    block = ShipperBlock.shopOpen;
  } else if (money < 0) {
    block = ShipperBlock.debt;
  } else if (money < next.cost) {
    block = ShipperBlock.poor;
  }
  return ShipperOffer(
    level: level,
    cost: next.cost,
    label: 'Nâng',
    lockLabel: null,
    block: block,
    nextName: next.nameVi,
  );
}

/// Expected online orders for one morning, before the preorder/sameday split.
double expectedOnlineOrders(
  Economy e, {
  required int shopRank,
  required double rating,
  required Map<String, int> levels,
  required bool holiday,
}) {
  final d = e.delivery;
  final raw =
      d.ordersBase + d.ordersPerRank * (shopRank - 1) + demandBonus(e, levels);
  final capped = raw < d.ordersCap ? raw : d.ordersCap.toDouble();
  return capped *
      e.ratingFactorFor(rating) *
      (holiday ? d.holidayMultiplier : 1);
}

/// P(spawn) for one real second while [hour] is inside the spawn window.
double samedaySpawnChance(
  Economy e, {
  required int hour,
  required double expected,
}) {
  final d = e.delivery;
  if (hour < d.spawnHourStart || hour > d.spawnHourEnd) return 0;
  var sumW = 0.0;
  for (var h = d.spawnHourStart; h <= d.spawnHourEnd; h++) {
    sumW += e.arrivalWeightsByHour[h] ?? 0;
  }
  if (sumW <= 0 || e.secondsPerHour <= 0) return 0;
  final w = e.arrivalWeightsByHour[hour] ?? 0;
  return expected * d.samedayShare * w / (sumW * e.secondsPerHour);
}

int gameHour(Economy e, double elapsed) =>
    e.openHour + (elapsed / e.secondsPerHour).floor();

String deadlineClock(Economy e, double seconds) {
  final hours = e.openHour + seconds / e.secondsPerHour;
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// "Giao trong 2 phút", from `deadlineSeconds`.
String deliverWindowLabel(double seconds) {
  final m = (seconds / 60).round();
  if (m >= 1) return 'Giao trong $m phút';
  return 'Giao trong ${seconds.round()} giây';
}

String countdownLabel(double secondsLeft) {
  final s = max(0, secondsLeft.ceil());
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

class OnlinePay {
  const OnlinePay({
    required this.pay,
    required this.tip,
    required this.fee,
    required this.reviewOutcome,
    required this.late,
  });

  final int pay;
  final int tip;
  final int fee;
  final String reviewOutcome;
  final bool late;

  int get total => pay + tip + fee;
}

/// On-time formula from `delivery.payment._formula`. No fast-service bonus.
OnlinePay payOnTime(
  Economy e, {
  required int price,
  required Tier tier,
  required bool wrapHit,
  double holidayTip = 1,
  double occasionTip = 1,
}) {
  final d = e.delivery;
  final t = e.tiers[tier.name]!;
  final pay = roundTo1000(price * t.payFactor * d.onlinePriceMultiplier);
  final wrapBonus = wrapHit
      ? max(e.wrapBonusMin, roundTo1000(price * e.wrapBonusPercent))
      : 0;
  final tip = roundTo1000(
    (price * t.tipPercent * holidayTip * occasionTip + wrapBonus) *
        d.onlinePriceMultiplier,
  );
  return OnlinePay(
    pay: pay,
    tip: tip,
    fee: d.deliveryFee,
    reviewOutcome: tier.name,
    late: false,
  );
}

/// Late: `roundTo1000(bouquetPrice * late.payFactor)`, fee and tip from data.
OnlinePay payLate(Economy e, {required int price}) {
  final d = e.delivery;
  return OnlinePay(
    pay: roundTo1000(price * d.latePayFactor),
    tip: d.lateTip,
    fee: d.lateDeliveryFee,
    reviewOutcome: d.lateReview,
    late: true,
  );
}

class PlannedShipper {
  const PlannedShipper({
    required this.id,
    required this.deliverSeconds,
    required this.returnSeconds,
    required this.capacity,
  });

  final String id;
  final double deliverSeconds;
  final double returnSeconds;
  final int capacity;
}

class _Slot {
  _Slot(this.spec);

  final PlannedShipper spec;
  final List<int> load = [];
  double loadStarted = 0;
  bool away = false;
  double backAt = 0;
  final Map<int, double> handover = {};
}

double _preview(_Slot s, double now, DeliveryRules d) {
  final stops = s.load.length;
  final double depart;
  if (s.load.length + 1 >= s.spec.capacity) {
    depart = now;
  } else if (s.load.isEmpty) {
    depart = now + d.loadWaitSeconds;
  } else {
    depart = s.loadStarted + d.loadWaitSeconds;
  }
  return depart + s.spec.deliverSeconds + d.extraStopSeconds * stops;
}

void _writeHandovers(_Slot s, double depart, DeliveryRules d) {
  for (var i = 0; i < s.load.length; i++) {
    s.handover[s.load[i]] =
        depart + s.spec.deliverSeconds + d.extraStopSeconds * i;
  }
}

void _depart(_Slot s, double depart, DeliveryRules d) {
  _writeHandovers(s, depart, d);
  final n = s.load.length;
  final last = n == 0
      ? depart
      : depart + s.spec.deliverSeconds + d.extraStopSeconds * (n - 1);
  s.backAt = last + s.spec.returnSeconds;
  s.away = true;
  s.load.clear();
}

void _commit(_Slot s, int order, double now, DeliveryRules d) {
  if (s.load.isEmpty) s.loadStarted = now;
  s.load.add(order);
  if (s.load.length >= s.spec.capacity) {
    _depart(s, now, d);
  } else {
    _writeHandovers(s, s.loadStarted + d.loadWaitSeconds, d);
  }
}

/// Auto-assign orders that are all ready at [readyAt], earliest deadline
/// first. Returns each order index's hand-over time.
///
/// A shipper at the shop with room is preferred; otherwise the simulation
/// waits for the one who gets back first. Full trips leave at once, a
/// partial trip leaves [DeliveryRules.loadWaitSeconds] after its first stop.
Map<int, double> planHandovers(
  Economy e, {
  required List<PlannedShipper> shippers,
  required List<double> deadlines,
  double readyAt = 0,
}) {
  final d = e.delivery;
  final slots = [for (final s in shippers) _Slot(s)];
  final shelf = List<int>.generate(deadlines.length, (i) => i)
    ..sort((a, b) => deadlines[a].compareTo(deadlines[b]));
  var time = readyAt;
  var guard = 0;
  while (shelf.isNotEmpty || slots.any((s) => s.load.isNotEmpty || s.away)) {
    if (guard++ > 10000) break;
    var progressed = true;
    while (progressed && shelf.isNotEmpty) {
      progressed = false;
      final home = [
        for (final s in slots)
          if (!s.away && s.load.length < s.spec.capacity) s,
      ];
      if (home.isEmpty) break;
      _Slot? best;
      var bestH = double.infinity;
      for (final s in home) {
        final h = _preview(s, time, d);
        if (h < bestH) {
          bestH = h;
          best = s;
        }
      }
      _commit(best!, shelf.removeAt(0), time, d);
      progressed = true;
    }
    if (shelf.isEmpty && slots.every((s) => s.load.isEmpty && !s.away)) break;
    var next = double.infinity;
    for (final s in slots) {
      if (!s.away && s.load.isNotEmpty && s.load.length < s.spec.capacity) {
        final t = s.loadStarted + d.loadWaitSeconds;
        if (t < next) next = t;
      }
      if (s.away && s.backAt < next) next = s.backAt;
    }
    if (next.isInfinite) break;
    if (next < time) next = time;
    time = next;
    for (final s in slots) {
      if (!s.away &&
          s.load.isNotEmpty &&
          time >= s.loadStarted + d.loadWaitSeconds - 1e-9) {
        _depart(s, s.loadStarted + d.loadWaitSeconds, d);
      }
      if (s.away && time >= s.backAt - 1e-9) {
        s.away = false;
      }
    }
  }
  return {for (final s in slots) ...s.handover};
}

/// Hired shippers as the planner sees them (current level's stats).
List<PlannedShipper> plannedFleet(Economy e, Map<String, int> levels) {
  final out = <PlannedShipper>[];
  for (final s in e.delivery.shippers) {
    final lv = s.levelDef(levels[s.id] ?? 0);
    if (lv == null) continue;
    out.add(
      PlannedShipper(
        id: s.id,
        deliverSeconds: lv.deliverSeconds,
        returnSeconds: lv.returnSeconds,
        capacity: lv.capacity,
      ),
    );
  }
  return out;
}

/// Green hint: if [extra] is accepted along with [acceptedDeadlines], does
/// its hand-over land on or before [extraDeadline]? Packed at t = 0.
bool wouldArriveOnTime(
  Economy e, {
  required Map<String, int> levels,
  required List<double> acceptedDeadlines,
  required double extraDeadline,
}) {
  final fleet = plannedFleet(e, levels);
  if (fleet.isEmpty) return false;
  final deadlines = [...acceptedDeadlines, extraDeadline];
  final times = planHandovers(e, shippers: fleet, deadlines: deadlines);
  final h = times[deadlines.length - 1];
  if (h == null) return false;
  return h <= extraDeadline + 1e-9;
}

/// First stem the stock cannot cover, as (name, missing count), or null.
(String, int)? missingStem(
  Economy e,
  BouquetRequest request,
  int Function(String flowerId) available,
) {
  for (final en in stemNeeds(request).entries) {
    final have = available(en.key);
    if (have < en.value) {
      return (e.flower(en.key).nameVi, en.value - have);
    }
  }
  return null;
}

/// Morning preorder count: Poisson(expected × share), at most `maxBoard`.
int preorderCount(Economy e, double expected, Random rng) {
  final d = e.delivery;
  final n = poisson(expected * d.preorderShare, rng);
  return n > d.maxBoard ? d.maxBoard : n;
}

double preorderDeadlineSeconds(Economy e, Random rng) {
  final hours = e.delivery.deadlineHours;
  final hour = hours[rng.nextInt(hours.length)];
  return (hour - e.openHour) * e.secondsPerHour;
}

double samedayDeadline(Economy e, double spawnAt) {
  final t = spawnAt + e.delivery.deadlineSeconds;
  return t < e.dayRealSeconds ? t : e.dayRealSeconds;
}

/// Daily-goal target after the shipper cap.
int cappedGoalTarget({
  required int targetBase,
  required int targetPerRank,
  required int shopRank,
  required String metric,
  required int requiresShippers,
  required int shippersHired,
}) {
  var target = targetBase + targetPerRank * (shopRank - 1);
  if (metric == 'onlineDelivered' && requiresShippers > 0) {
    final cap = shippersHired * onlineGoalCapPerShipper;
    if (target > cap) target = cap;
  }
  return target;
}
