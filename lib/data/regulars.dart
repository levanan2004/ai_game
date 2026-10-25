/// Sổ tay khách quen (spec_so_tay_khach_quen.md): the ten regulars.
///
/// Rules come from `khach_quen_block.json` (Hà Phương), names and stories
/// from `chuoi_chuyen_khach_quen.json` (Nhất), UI words from
/// `so_tay_strings.json` (Nhất). The two customer files are joined by `id`
/// and `step` (spec "Nguồn dữ liệu"); no value is written in code.
library;

import 'dart:convert';

/// One visit of a regular's story: [step] in both files.
class RegularVisit {
  const RegularVisit({
    required this.step,
    required this.sourceOccasion,
    required this.orderOccasion,
    required this.species,
    required this.unlock,
    required this.order,
    required this.thanks,
    required this.poor,
  });

  final int step;

  /// Nhất's occasion (`chain[].occasion`), e.g. `14/2`, `new_home`.
  final String sourceOccasion;

  /// economy.json occasion the order uses (`visits[].orderOccasion`).
  final String orderOccasion;

  /// `visits[].speciesOverride`: the species the order asks for.
  final List<String> species;

  /// `visits[].unlock` as written in the block.
  final Map<String, dynamic> unlock;

  final String order;
  final String thanks;
  final String poor;

  int? _int(String k) => (unlock[k] as num?)?.toInt();
  int? get minGameDay => _int('minGameDay');
  int? get minLifetimeGreat => _int('minLifetimeGreat');
  int? get requiresStep => _int('requiresStep');
  int? get prevMinStars => _int('prevMinStars');
  int? get minGapDays => _int('minGapDays');
  String? get holiday => unlock['holiday'] as String?;
  bool get onCustomerBirthday => unlock['onCustomerBirthday'] == true;
  int? get anniversaryOfStep => _int('anniversaryOfStep');
  int? get anniversaryDays => _int('anniversaryDays');
  int? get windowDays => _int('windowDays');

  /// `scheduledDay.announceDaysBefore`; null when the visit is not scheduled.
  int? get announceDaysBefore {
    final s = unlock['scheduledDay'];
    return s is Map ? (s['announceDaysBefore'] as num?)?.toInt() : null;
  }

  List<String> get requiresUnlocked => [
    for (final id in (unlock['requiresUnlocked'] as List?) ?? const [])
      id as String,
  ];

  /// `requiresUnlockedAny`: at least one group fully unlocked.
  List<List<String>> get requiresUnlockedAny => [
    for (final g in (unlock['requiresUnlockedAny'] as List?) ?? const [])
      [for (final id in g as List) id as String],
  ];
}

class RegularDef {
  const RegularDef({
    required this.id,
    required this.name,
    required this.profile,
    required this.birthday,
    required this.birthdayDayOfYear,
    required this.favoriteFlowerIds,
    required this.minGameDay,
    required this.minLifetimeGreat,
    required this.visits,
  });

  final String id;
  final String name;
  final String profile;

  /// Real day/month (`birthday`), shown as written.
  final String birthday;
  final int birthdayDayOfYear;
  final List<String> favoriteFlowerIds;

  /// `customerUnlock`: when the first visit can happen.
  final int minGameDay;
  final int minLifetimeGreat;
  final List<RegularVisit> visits;

  /// `assets/images/regulars/{id}.webp` (Phú).
  String get avatar => 'assets/images/regulars/$id.webp';

  RegularVisit? visit(int step) {
    for (final v in visits) {
      if (v.step == step) return v;
    }
    return null;
  }
}

/// UI words from so_tay_strings.json. `{name}` tokens are filled by code.
class SoTayText {
  SoTayText._(this._j);

  static final empty = SoTayText._(const {});

  final Map<String, dynamic> _j;

  Object? _at(String key) {
    Object? v = _j;
    for (final part in key.split('.')) {
      v = v is Map ? v[part] : null;
    }
    return v;
  }

  /// `group.key`, e.g. `tabs.all`; the key itself when missing.
  String ui(String key, [Map<String, Object> args = const {}]) {
    final v = _at(key);
    return fill(v is String ? v : key, args);
  }

  /// Two-line entries (`nextVisit.*`).
  List<String> lines(String key, [Map<String, Object> args = const {}]) {
    final v = _at(key);
    if (v is String) return [fill(v, args)];
    return [
      for (final l in v is List ? v : const [])
        if (l is String) fill(l, args),
    ];
  }

  /// Display name of Nhất's occasion (`occasions`). `14/2` etc. are mapped
  /// to the holiday ids the strings use.
  String occasion(String source) {
    final id = _occasionAlias[source] ?? source;
    final v = _at('occasions.$id');
    return v is String ? v : source;
  }

  /// `holidays.{id}`, e.g. "Valentine 14/2".
  String holiday(String id) {
    final v = _at('holidays.$id');
    return v is String ? v : id;
  }

  static const _occasionAlias = {
    '14/2': 'valentine',
    '8/3': 'women_0803',
    '20/10': 'women_2010',
    '20/11': 'teacher_2011',
  };

  static String fill(String s, Map<String, Object> args) {
    var out = s;
    args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }
}

/// The block's rules plus the joined customers.
class RegularsCatalog {
  const RegularsCatalog({
    required this.customers,
    required this.text,
    this.notebookMinGameDay = 0,
    this.notebookMinLifetimeGreat = 0,
    this.firstVisitMinStars = 0,
    this.retryGapDays = 0,
    this.maxRetries = 0,
    this.holidayRetryWindowDays = 0,
    this.cooldownDays = 0,
    this.maxRegularVisitsPerDay = 0,
    this.maxRegularVisitsPerHolidayDay = 0,
    this.maxStoryVisitsPerDay = 0,
    this.maxStoryVisitsPerHolidayDay = 0,
    this.maxShareOfDailyCustomers = 0,
    this.casualVisitChancePerDay = 0,
  });

  static const blockAsset = 'assets/data/khach_quen_block.json';
  static const storyAsset = 'assets/data/chuoi_chuyen_khach_quen.json';
  static const textAsset = 'assets/data/so_tay_strings.json';

  static const empty = RegularsCatalog(customers: [], text: null);

  /// Ordered by `customerUnlock.minGameDay`, then file order (spec §4.4).
  final List<RegularDef> customers;
  final SoTayText? text;

  SoTayText get t => text ?? SoTayText.empty;

  final int notebookMinGameDay;
  final int notebookMinLifetimeGreat;
  final int firstVisitMinStars;
  final int retryGapDays;
  final int maxRetries;
  final int holidayRetryWindowDays;
  final int cooldownDays;
  final int maxRegularVisitsPerDay;
  final int maxRegularVisitsPerHolidayDay;
  final int maxStoryVisitsPerDay;
  final int maxStoryVisitsPerHolidayDay;
  final double maxShareOfDailyCustomers;
  final double casualVisitChancePerDay;

  bool get isEmpty => customers.isEmpty;

  RegularDef? byId(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Null strings leave the notebook out of the game (an older build's data).
  static RegularsCatalog parse({String? block, String? stories, String? text}) {
    if (block == null || stories == null) return empty;
    final b = jsonDecode(block) as Map<String, dynamic>;
    final s = jsonDecode(stories) as Map<String, dynamic>;
    final r = b['regulars'] as Map<String, dynamic>;
    final fail = (b['failureHandling'] as Map<String, dynamic>?) ?? const {};
    final anti = (b['antiRepeat'] as Map<String, dynamic>?) ?? const {};
    final unlock = (r['notebookUnlock'] as Map<String, dynamic>?) ?? const {};
    final become = (r['becomeRegular'] as Map<String, dynamic>?) ?? const {};
    int i(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
    double d(Map m, String k) => (m[k] as num?)?.toDouble() ?? 0;

    final stories0 = {
      for (final c in (s['customers'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: c,
    };
    final list = <RegularDef>[];
    for (final c in (r['customers'] as List).cast<Map<String, dynamic>>()) {
      final id = c['id'] as String;
      final story = stories0[id];
      if (story == null) continue;
      final chain = {
        for (final st in (story['chain'] as List).cast<Map<String, dynamic>>())
          (st['step'] as num).toInt(): st,
      };
      final cu = (c['customerUnlock'] as Map<String, dynamic>?) ?? const {};
      list.add(
        RegularDef(
          id: id,
          name: story['name'] as String,
          profile: (story['profile'] as String?) ?? '',
          birthday: (story['birthday'] as String?) ?? '',
          birthdayDayOfYear: i(c, 'birthdayDayOfYear'),
          favoriteFlowerIds: [
            for (final f in (c['favoriteFlowerIds'] as List?) ?? const [])
              f as String,
          ],
          minGameDay: i(cu, 'minGameDay'),
          minLifetimeGreat: i(cu, 'minLifetimeGreat'),
          visits: [
            for (final v in (c['visits'] as List).cast<Map<String, dynamic>>())
              RegularVisit(
                step: (v['step'] as num).toInt(),
                sourceOccasion:
                    (chain[(v['step'] as num).toInt()]?['occasion']
                        as String?) ??
                    (v['sourceOccasion'] as String? ?? ''),
                orderOccasion: v['orderOccasion'] as String,
                species: [
                  for (final f in (v['speciesOverride'] as List?) ?? const [])
                    f as String,
                ],
                unlock: (v['unlock'] as Map<String, dynamic>?) ?? const {},
                order:
                    (chain[(v['step'] as num).toInt()]?['order'] as String?) ??
                    '',
                thanks:
                    (chain[(v['step'] as num).toInt()]?['thanks'] as String?) ??
                    '',
                poor:
                    (chain[(v['step'] as num).toInt()]?['poor'] as String?) ??
                    '',
              ),
          ]..sort((a, b) => a.step.compareTo(b.step)),
        ),
      );
    }
    final ordered = [for (var k = 0; k < list.length; k++) (k, list[k])]
      ..sort((a, b) {
        final c = a.$2.minGameDay.compareTo(b.$2.minGameDay);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return RegularsCatalog(
      customers: [for (final e in ordered) e.$2],
      text: text == null
          ? null
          : SoTayText._(jsonDecode(text) as Map<String, dynamic>),
      notebookMinGameDay: i(unlock, 'minGameDay'),
      notebookMinLifetimeGreat: i(unlock, 'minLifetimeGreat'),
      firstVisitMinStars: i(become, 'firstVisitMinStars'),
      retryGapDays: i(fail, 'retryGapDays'),
      maxRetries: i(fail, 'maxRetries'),
      holidayRetryWindowDays: i(
        (fail['holidayFallback'] as Map?) ?? const {},
        'holidayRetryWindowDays',
      ),
      cooldownDays: i(anti, 'customerCooldownDays'),
      maxRegularVisitsPerDay: i(anti, 'maxRegularVisitsPerDay'),
      maxRegularVisitsPerHolidayDay: i(anti, 'maxRegularVisitsPerHolidayDay'),
      maxStoryVisitsPerDay: i(anti, 'maxStoryVisitsPerDay'),
      maxStoryVisitsPerHolidayDay: i(anti, 'maxStoryVisitsPerHolidayDay'),
      maxShareOfDailyCustomers: d(anti, 'maxRegularShareOfDailyCustomers'),
      casualVisitChancePerDay: d(anti, 'casualVisitChancePerDay'),
    );
  }
}
