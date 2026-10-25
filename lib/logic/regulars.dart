/// Sổ tay khách quen rules (khach_quen_block.json, Hà Phương): when a regular
/// comes in, what a served bouquet does to the story, and the notebook's
/// hearts and letter states (spec_so_tay_khach_quen.md §4–§6).
library;

import 'dart:math';

import '../data/economy.dart';
import '../data/regulars.dart';
import '../save/game_state.dart';

/// Avatar id of a regular: `regulars/{id}` under assets/images (Phú).
/// [isRegularAvatar] tells it apart from a customers/index.json id.
String regularAvatarId(String id) => 'regulars/$id';

bool isRegularAvatar(String avatarId) => avatarId.startsWith('regulars/');

/// Day of the game year, 1-based (economy.json `holidays.yearLengthDays`).
int gameDayOfYear(Economy e, int day) =>
    e.yearLengthDays <= 0 ? day : ((day - 1) % e.yearLengthDays) + 1;

bool notebookOpen(
  RegularsCatalog cat, {
  required int day,
  required int great,
}) =>
    !cat.isEmpty &&
    day >= cat.notebookMinGameDay &&
    great >= cat.notebookMinLifetimeGreat;

/// First step without an entry in `stepsDone`; null when the chain is done.
RegularVisit? nextVisit(RegularDef def, RegularProgress p) {
  for (final v in def.visits) {
    if (!p.stepsDone.containsKey(v.step)) return v;
  }
  return null;
}

bool chainDone(RegularDef def, RegularProgress p) => nextVisit(def, p) == null;

/// `becomeRegular.firstVisitMinStars`: step 1 closed with enough stars.
bool isRegular(RegularsCatalog cat, RegularProgress p) {
  final first = p.stepsDone[1];
  return first is int && first >= cat.firstVisitMinStars;
}

/// Steps closed with stars (not `poorEnding` / `skipped`).
int stepsDoneCount(RegularProgress p) =>
    p.stepsDone.values.whereType<int>().length;

/// Hà Phương: `round(5 * done / visits)`; 0 before the regular is one (§6).
int heartsOf(RegularsCatalog cat, RegularDef def, RegularProgress p) {
  if (!isRegular(cat, p) || def.visits.isEmpty) return 0;
  return (heartScale * stepsDoneCount(p) / def.visits.length).round();
}

/// hoa_moi_block `khachQuen.heartScale`.
const heartScale = 5;

/// Why a story visit can come today.
enum VisitKind {
  /// Holiday, birthday or invitation day: skips the cooldown, comes first.
  special,

  /// A try after a failed one (`retryGapDays`).
  retry,
  normal,
}

/// One regular planned for today. [step] null = a casual visit.
class PlannedRegular {
  const PlannedRegular(this.id, this.step);

  final String id;
  final int? step;
}

/// True when the step before [v] is closed (stars, poorEnding or skipped)
/// with at least `prevMinStars`, and `minGapDays` have passed.
bool _afterPrevious(RegularVisit v, RegularProgress p, int day) {
  final need = v.requiresStep;
  if (need == null) return true;
  final prev = p.stepsDone[need];
  if (prev == null) return false;
  if (prev is int && v.prevMinStars != null && prev < v.prevMinStars!) {
    return false;
  }
  final gap = v.minGapDays;
  if (gap != null && day < (p.doneDay[need] ?? 0) + gap) return false;
  return true;
}

bool _unlocked(RegularVisit v, Set<String> owned) {
  if (!v.requiresUnlocked.every(owned.contains)) return false;
  final any = v.requiresUnlockedAny;
  return any.isEmpty || any.any((g) => g.every(owned.contains));
}

/// The rules of [v] other than its day (holiday, birthday, invitation,
/// anniversary) are met.
bool _basicsMet(
  RegularDef def,
  RegularVisit v,
  RegularProgress p, {
  required int day,
  required int great,
  required Set<String> owned,
}) {
  final minDay = v.minGameDay ?? (v.step == 1 ? def.minGameDay : null);
  if (minDay != null && day < minDay) return false;
  final minGreat =
      v.minLifetimeGreat ?? (v.step == 1 ? def.minLifetimeGreat : null);
  if (minGreat != null && great < minGreat) return false;
  return _afterPrevious(v, p, day) && _unlocked(v, owned);
}

/// Morning bookkeeping for one regular: picks the invitation day, moves a
/// missed anniversary, closes a missed holiday step as `skipped`.
/// Returns true when a new invitation was sent (badge).
bool regularMorning(
  RegularsCatalog cat,
  Economy e,
  RegularDef def,
  RegularProgress p, {
  required int day,
  required int great,
  required Set<String> owned,
}) {
  final v = nextVisit(def, p);
  if (v == null) return false;
  final basics = _basicsMet(def, v, p, day: day, great: great, owned: owned);
  final h = v.holiday;
  if (h != null && p.holidayDueDay > 0) {
    final holidayNow = e.holidayOn(day)?.id == h;
    if (!holidayNow &&
        day >
            p.holidayDueDay +
                _holidayLength(e, h, p.holidayDueDay) -
                1 +
                cat.holidayRetryWindowDays) {
      p.holidayDueDay = 0;
      p.retryAfterDay = 0;
      p.retries = 0;
      if (v.unlock['holidayFallback'] == 'skipAfterWindow') {
        p.stepsDone[v.step] = RegularProgress.skipped;
        p.doneDay[v.step] = day;
        p.unread.add(v.step);
        return false;
      }
    }
  }
  if (h != null &&
      basics &&
      p.holidayDueDay == 0 &&
      e.holidayOn(day)?.id == h) {
    p.holidayDueDay = day;
  }
  final ann = v.anniversaryOfStep;
  if (ann != null && basics && p.scheduledDay == 0) {
    final from = (p.doneDay[ann] ?? 0) + (v.anniversaryDays ?? 0);
    // block failureHandling.neverLock: a missed window moves the visit to a
    // `scheduledDay` 7 days later.
    if (p.doneDay.containsKey(ann) && day > from + (v.windowDays ?? 0)) {
      p.scheduledDay = day + 7;
      p.inviteUnseen = true;
      return true;
    }
  }
  final before = v.announceDaysBefore;
  if (before != null && basics && p.scheduledDay == 0) {
    var d = day + before;
    while (e.holidayOn(d) != null) {
      d++;
    }
    p.scheduledDay = d;
    p.inviteUnseen = true;
    return true;
  }
  return false;
}

int _holidayLength(Economy e, String id, int firstDay) {
  var n = 0;
  while (e.holidayOn(firstDay + n)?.id == id) {
    n++;
  }
  return max(n, 1);
}

/// Kind of today's story visit for [def], or null when none can come.
VisitKind? storyDue(
  RegularsCatalog cat,
  Economy e,
  RegularDef def,
  RegularProgress p, {
  required int day,
  required int great,
  required Set<String> owned,
}) {
  final v = nextVisit(def, p);
  if (v == null) return null;
  if (!_basicsMet(def, v, p, day: day, great: great, owned: owned)) {
    return null;
  }
  final h = v.holiday;
  final holidayOk =
      h == null || e.holidayOn(day)?.id == h || p.holidayDueDay > 0;
  if (!holidayOk) return null;
  if (p.retryAfterDay > 0) {
    return day >= p.retryAfterDay ? VisitKind.retry : null;
  }
  if (h != null) return VisitKind.special;
  if (v.onCustomerBirthday) {
    return gameDayOfYear(e, day) == def.birthdayDayOfYear
        ? VisitKind.special
        : null;
  }
  if (p.scheduledDay > 0) {
    return day >= p.scheduledDay ? VisitKind.special : null;
  }
  if (v.announceDaysBefore != null) return null;
  final ann = v.anniversaryOfStep;
  if (ann != null) {
    final from = (p.doneDay[ann] ?? 0) + (v.anniversaryDays ?? 0);
    if (!p.doneDay.containsKey(ann)) return null;
    return day >= from && day <= from + (v.windowDays ?? 0)
        ? VisitKind.special
        : null;
  }
  return _cooledDown(cat, p, day) ? VisitKind.normal : null;
}

bool _cooledDown(RegularsCatalog cat, RegularProgress p, int day) =>
    p.lastVisitDay == 0 || day >= p.lastVisitDay + cat.cooldownDays;

/// Today's regulars (block `antiRepeat`): story visits by priority, then
/// casual visits of finished chains. They replace strangers, so the total
/// stays within `maxRegularShareOfDailyCustomers` of [arrivals].
List<PlannedRegular> planRegularDay(
  RegularsCatalog cat,
  Economy e,
  Map<String, RegularProgress> progress, {
  required int day,
  required int great,
  required Set<String> owned,
  required int arrivals,
  required Random rng,
}) {
  if (arrivals <= 0 || !notebookOpen(cat, day: day, great: great)) {
    return const [];
  }
  final holiday = e.holidayOn(day) != null;
  final share = max(1, (arrivals * cat.maxShareOfDailyCustomers).floor());
  final cap = min(
    share,
    holiday ? cat.maxRegularVisitsPerHolidayDay : cat.maxRegularVisitsPerDay,
  );
  final storyCap = holiday
      ? cat.maxStoryVisitsPerHolidayDay
      : cat.maxStoryVisitsPerDay;
  final stories = <(int, int, PlannedRegular)>[];
  final casual = <PlannedRegular>[];
  for (var k = 0; k < cat.customers.length; k++) {
    final def = cat.customers[k];
    final p = progress[def.id] ?? RegularProgress();
    final kind = storyDue(cat, e, def, p, day: day, great: great, owned: owned);
    if (kind != null) {
      stories.add((
        kind.index,
        k,
        PlannedRegular(def.id, nextVisit(def, p)!.step),
      ));
    } else if (chainDone(def, p) &&
        _cooledDown(cat, p, day) &&
        rng.nextDouble() < cat.casualVisitChancePerDay) {
      casual.add(PlannedRegular(def.id, null));
    }
  }
  stories.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  final out = <PlannedRegular>[
    for (final s in stories.take(min(storyCap, cap))) s.$3,
  ];
  for (final c in casual) {
    if (out.length >= cap) break;
    out.add(c);
  }
  return out;
}

/// What a finished visit did to the story.
enum RegularOutcome { none, becameRegular, letter, retry, poorEnding }

/// Records a visit. [stars] are the review stars; [left] = the customer
/// left unserved (not a try, block `failureHandling.leftUnserved`).
RegularOutcome recordRegularVisit(
  RegularsCatalog cat,
  RegularProgress p, {
  required int? step,
  required int stars,
  required bool left,
  required int day,
}) {
  p.lastVisitDay = day;
  if (step == null || p.stepsDone.containsKey(step)) {
    return RegularOutcome.none;
  }
  if (left) {
    p.retryAfterDay = day + cat.retryGapDays;
    return RegularOutcome.none;
  }
  if (stars >= cat.firstVisitMinStars) {
    _close(p, step, stars, day);
    return step == 1 ? RegularOutcome.becameRegular : RegularOutcome.letter;
  }
  if (p.retries >= cat.maxRetries) {
    _close(p, step, RegularProgress.poorEnding, day);
    return RegularOutcome.poorEnding;
  }
  p.retries++;
  p.retryAfterDay = day + cat.retryGapDays;
  return RegularOutcome.retry;
}

void _close(RegularProgress p, int step, Object value, int day) {
  p.stepsDone[step] = value;
  p.doneDay[step] = day;
  if (!p.unread.contains(step)) p.unread.add(step);
  p.retries = 0;
  p.retryAfterDay = 0;
  p.scheduledDay = 0;
  p.holidayDueDay = 0;
  p.inviteUnseen = false;
}

/// "Mời ghé lại" (block `afterMaxRetries`): a closed `poorEnding` /
/// `skipped` step opens again for another try.
bool inviteAgain(RegularDef def, RegularProgress p) {
  for (final v in def.visits) {
    final s = p.stepsDone[v.step];
    if (s == RegularProgress.poorEnding || s == RegularProgress.skipped) {
      p.stepsDone.remove(v.step);
      p.doneDay.remove(v.step);
      p.unread.remove(v.step);
      return true;
    }
  }
  return false;
}

/// Notebook badge count (§3): unread letters plus new invitations.
int notebookBadge(Map<String, RegularProgress> progress) {
  var n = 0;
  for (final p in progress.values) {
    n += p.unread.length;
    if (p.inviteUnseen) n++;
  }
  return n;
}
