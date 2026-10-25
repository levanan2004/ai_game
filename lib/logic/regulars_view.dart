/// What the Sổ tay khách quen screens show for each regular
/// (spec_so_tay_khach_quen.md §4–§6), from the block, the stories and the
/// save. All text comes from so_tay_strings.json (Nhất).
library;

import '../data/economy.dart';
import '../data/regulars.dart';
import '../save/game_state.dart';
import 'regulars.dart';

/// Card states (§4.6, §4.7, §4.5).
enum RegularCardState { locked, meeting, regular }

RegularCardState cardStateOf(RegularsCatalog cat, RegularProgress? p) {
  if (p == null || !p.met) return RegularCardState.locked;
  return isRegular(cat, p)
      ? RegularCardState.regular
      : RegularCardState.meeting;
}

/// Display name of a flower, paper or ribbon id (economy.json `nameVi`).
String itemNameVi(Economy e, String id) {
  for (final f in e.flowers) {
    if (f.id == id) return f.nameVi;
  }
  for (final p in e.papers) {
    if (p.id == id) return p.nameVi;
  }
  for (final r in e.ribbons) {
    if (r.id == id) return r.nameVi;
  }
  return id;
}

/// "hoa hồng · baby" (§4.5c).
String favoriteNames(Economy e, RegularDef def) =>
    [for (final id in def.favoriteFlowerIds) itemNameVi(e, id)].join(' · ');

/// Hint lines on a locked card (§4.6, `lockedCard.*`).
List<String> lockedHints(
  RegularsCatalog cat,
  Economy e,
  RegularDef def, {
  required int day,
  required int great,
}) {
  final t = cat.t;
  final first = def.visits.isEmpty ? null : def.visits.first;
  final minDay = first?.minGameDay ?? def.minGameDay;
  final minGreat = first?.minLifetimeGreat ?? def.minLifetimeGreat;
  return [
    if (day < minDay) t.ui('lockedCard.fromDay', {'minGameDay': minDay}),
    if (great < minGreat)
      t.ui('lockedCard.needGreat', {'minLifetimeGreat': minGreat}),
    if (first?.holiday != null)
      t.ui('lockedCard.holiday', {'tenLe': t.holiday(first!.holiday!)}),
  ];
}

/// Holiday icon (§8): le_valentine, le_8_3_20_10 (also teacher_2011 for
/// now), le_tet; null for a holiday without one.
String? holidayIcon(String id) => switch (id) {
  'valentine' => 'le_valentine',
  'women_0803' || 'women_2010' || 'teacher_2011' => 'le_8_3_20_10',
  'tet' => 'le_tet',
  _ => null,
};

/// Days from [day] to the next first day of holiday [id]; null if unknown.
int? daysToHoliday(Economy e, String id, int day) {
  HolidayDef? h;
  for (final x in e.holidays) {
    if (x.id == id) h = x;
  }
  if (h == null || h.days.isEmpty || e.yearLengthDays <= 0) return null;
  final first = h.days.reduce((a, b) => a < b ? a : b);
  final today = gameDayOfYear(e, day);
  return (first - today) % e.yearLengthDays;
}

int _daysToDayOfYear(Economy e, int target, int day) {
  if (e.yearLengthDays <= 0) return 0;
  return (target - gameDayOfYear(e, day)) % e.yearLengthDays;
}

/// §5.1 next-visit hint: [lines] (two lines, `nextVisit.*`), an orange
/// [needUnlock] line, and the icon (holiday id, 'invite', 'birthday', 'letter').
class NextVisitView {
  const NextVisitView(this.lines, {this.needUnlock, this.icon = 'letter'});
  final List<String> lines;
  final String? needUnlock;
  final String icon;
}

NextVisitView nextVisitView(
  RegularsCatalog cat,
  Economy e,
  RegularDef def,
  RegularProgress p, {
  required int day,
  required Set<String> owned,
}) {
  final t = cat.t;
  final name = def.name;
  final v = nextVisit(def, p);
  if (v == null) {
    return NextVisitView(t.lines('nextVisit.chainDone', {'name': name}));
  }
  final missing = [
    for (final id in v.requiresUnlocked)
      if (!owned.contains(id)) id,
  ];
  final any = v.requiresUnlockedAny;
  if (missing.isEmpty &&
      any.isNotEmpty &&
      !any.any((g) => g.every(owned.contains))) {
    missing.addAll(any.first.where((id) => !owned.contains(id)));
  }
  final needUnlock = missing.isEmpty
      ? null
      : t.ui('nextVisit.needUnlock', {
          'tenHoaGiay': [
            for (final id in missing) itemNameVi(e, id),
          ].join(', '),
        });
  NextVisitView view(String key, Map<String, Object> args, String icon) =>
      NextVisitView(
        t.lines(key, {'name': name, ...args}),
        needUnlock: needUnlock,
        icon: icon,
      );
  if (p.retryAfterDay > 0) {
    return view('nextVisit.retry', {
      'retryGapDays': cat.retryGapDays,
    }, 'letter');
  }
  final h = v.holiday;
  if (h != null) {
    return view('nextVisit.holiday', {
      'tenLe': t.holiday(h),
      'n': daysToHoliday(e, h, day) ?? 0,
    }, h);
  }
  if (v.onCustomerBirthday) {
    return view('nextVisit.birthday', {
      'birthdayDayOfYear': def.birthdayDayOfYear,
      'n': _daysToDayOfYear(e, def.birthdayDayOfYear, day),
    }, 'birthday');
  }
  if (p.scheduledDay > 0) {
    return view('nextVisit.scheduledKnown', {'d': p.scheduledDay}, 'invite');
  }
  if (v.announceDaysBefore != null) {
    return view('nextVisit.scheduledSoon', const {}, 'invite');
  }
  final ann = v.anniversaryOfStep;
  if (ann != null) {
    final d = (p.doneDay[ann] ?? day) + (v.anniversaryDays ?? 0);
    return view('nextVisit.anniversary', {'d': d}, 'letter');
  }
  final need = v.requiresStep;
  final from = need != null && p.doneDay.containsKey(need)
      ? p.doneDay[need]! + (v.minGapDays ?? 0)
      : (v.minGameDay ?? def.minGameDay);
  return view('nextVisit.minGap', {'d': from < day ? day : from}, 'letter');
}

/// §5.2 letter states.
enum LetterState { great, okay, poorEnd, missed, waiting, far }

class LetterView {
  const LetterView({
    required this.step,
    required this.state,
    required this.title,
    required this.line,
    this.unread = false,
  });
  final int step;
  final LetterState state;
  final String title;

  /// `thanks`, `poor`, the missed line or the next-visit hint.
  final String line;
  final bool unread;

  bool get canOpen =>
      state == LetterState.great ||
      state == LetterState.okay ||
      state == LetterState.poorEnd;
}

List<LetterView> lettersOf(
  RegularsCatalog cat,
  Economy e,
  RegularDef def,
  RegularProgress p, {
  required int day,
  required Set<String> owned,
}) {
  final t = cat.t;
  final great = e.reviewStars['great'] ?? 5;
  final next = nextVisit(def, p);
  final out = <LetterView>[];
  for (final v in def.visits) {
    final done = p.stepsDone[v.step];
    final dip = t.occasion(v.sourceOccasion);
    final args = <String, Object>{'step': v.step, 'tenDip': dip};
    final unread = p.unread.contains(v.step);
    if (done is int) {
      out.add(
        LetterView(
          step: v.step,
          state: done >= great ? LetterState.great : LetterState.okay,
          title: t.ui('letter.title', args),
          line: v.thanks,
          unread: unread,
        ),
      );
    } else if (done == RegularProgress.poorEnding) {
      out.add(
        LetterView(
          step: v.step,
          state: LetterState.poorEnd,
          title: t.ui('letter.poorEnd', args),
          line: v.poor,
          unread: unread,
        ),
      );
    } else if (done == RegularProgress.skipped) {
      out.add(
        LetterView(
          step: v.step,
          state: LetterState.missed,
          title: t.ui('letter.title', args),
          line: t.ui('letter.missed', {
            'tenLe': t.holiday(v.holiday ?? v.sourceOccasion),
          }),
          unread: unread,
        ),
      );
    } else if (identical(v, next)) {
      final hint = nextVisitView(cat, e, def, p, day: day, owned: owned);
      out.add(
        LetterView(
          step: v.step,
          state: LetterState.waiting,
          title: t.ui('letter.titleLocked', args),
          line: [
            if (hint.lines.length > 1) hint.lines.last else ...hint.lines,
            ?hint.needUnlock,
          ].join(', '),
        ),
      );
    } else {
      out.add(
        LetterView(
          step: v.step,
          state: LetterState.far,
          title: t.ui('letter.titleFar', args),
          line: '',
        ),
      );
    }
  }
  return out;
}

/// "Mời ghé lại" shows when a step ended poorly or was missed (§5.6).
bool canInviteAgain(RegularDef def, RegularProgress p) => def.visits.any((v) {
  final s = p.stepsDone[v.step];
  return s == RegularProgress.poorEnding || s == RegularProgress.skipped;
});

/// Birthday today (§5.2 "Hôm nay!").
bool birthdayToday(Economy e, RegularDef def, int day) =>
    def.birthdayDayOfYear > 0 && gameDayOfYear(e, day) == def.birthdayDayOfYear;
