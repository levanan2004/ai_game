/// Typed views of the text files from Hà Phương: `assets/data/reviews.json`
/// (review sentences + selection rules) and `assets/data/orders.json`
/// (customer request lines + customer names). The game never hard-codes
/// these sentences.
library;

class OutcomeTexts {
  const OutcomeTexts({
    required this.generic,
    required this.byReason,
    required this.byOccasion,
    required this.byHoliday,
  });

  factory OutcomeTexts.fromJson(Map<String, dynamic> j) => OutcomeTexts(
    generic: _strings(j['generic']),
    byReason: _groups(j['byReason']),
    byOccasion: _groups(j['byOccasion']),
    byHoliday: _groups(j['byHoliday']),
  );

  final List<String> generic;
  final Map<String, List<String>> byReason;
  final Map<String, List<String>> byOccasion;
  final Map<String, List<String>> byHoliday;
}

class OwnerReplyLine {
  const OwnerReplyLine({required this.text, required this.tone});

  final String text;
  final String tone;
}

class ReviewTexts {
  const ReviewTexts({
    required this.maxChars,
    required this.reasonChance,
    required this.holidayChance,
    required this.occasionChance,
    required this.noRepeatLast,
    required this.outcomes,
    this.ownerReplyChoiceCount = 3,
    this.ownerReplies = const {},
  });

  factory ReviewTexts.fromJson(Map<String, dynamic> j) {
    final sel = j['selection'] as Map<String, dynamic>;
    final outcomes = j['outcomes'] as Map<String, dynamic>;
    final replies = (j['ownerReplies'] as Map<String, dynamic>?) ?? const {};
    return ReviewTexts(
      maxChars: (j['maxChars'] as num).toInt(),
      reasonChance: (sel['reasonChance'] as num).toDouble(),
      holidayChance: (sel['holidayChance'] as num).toDouble(),
      occasionChance: (sel['occasionChance'] as num).toDouble(),
      noRepeatLast: (sel['noRepeatLast'] as num).toInt(),
      ownerReplyChoiceCount: (sel['ownerReplyChoices'] as num?)?.toInt() ?? 3,
      outcomes: {
        for (final e in outcomes.entries)
          if (!e.key.startsWith('_'))
            e.key: OutcomeTexts.fromJson(e.value as Map<String, dynamic>),
      },
      ownerReplies: {
        for (final e in replies.entries)
          if (!e.key.startsWith('_'))
            e.key: [
              for (final line in e.value as List)
                OwnerReplyLine(
                  text: (line as Map<String, dynamic>)['text'] as String,
                  tone: line['tone'] as String,
                ),
            ],
      },
    );
  }

  final int maxChars;
  final double reasonChance;
  final double holidayChance;
  final double occasionChance;
  final int noRepeatLast;

  /// How many suggestion chips the reply sheet shows (reviews.json).
  final int ownerReplyChoiceCount;
  final Map<String, OutcomeTexts> outcomes;
  final Map<String, List<OwnerReplyLine>> ownerReplies;
}

/// One customer from orders.json `customers` (gender m/f, age teen/adult/senior).
class CustomerProfile {
  const CustomerProfile({
    required this.name,
    required this.gender,
    required this.age,
    this.avatarId = '',
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> j) => CustomerProfile(
    name: j['name'] as String,
    gender: (j['gender'] as String?) ?? '',
    age: (j['age'] as String?) ?? '',
  );

  final String name;
  final String gender;
  final String age;

  /// File name in assets/images/customers (from customers/index.json).
  final String avatarId;

  CustomerProfile withAvatar(String id) =>
      CustomerProfile(name: name, gender: gender, age: age, avatarId: id);
}

/// orders.json `speakerOnly` entry: which customers may say a line.
/// A missing field means "anyone"; a value is one string or a list.
class SpeakerRule {
  const SpeakerRule({this.genders, this.ages});

  factory SpeakerRule.fromJson(Map<String, dynamic> j) =>
      SpeakerRule(genders: _oneOrMany(j['gender']), ages: _oneOrMany(j['age']));

  final Set<String>? genders;
  final Set<String>? ages;

  bool allows(CustomerProfile c) =>
      (genders == null || genders!.contains(c.gender)) &&
      (ages == null || ages!.contains(c.age));

  static Set<String>? _oneOrMany(Object? v) {
    if (v == null) return null;
    if (v is String) return {v};
    return (v as List).cast<String>().toSet();
  }
}

class OrderTexts {
  const OrderTexts({
    required this.noRepeatLast,
    required this.holidayChance,
    required this.byOccasion,
    required this.byHoliday,
    required this.customers,
    this.speakerOnly = const {},
    this.onlinePreorder = const [],
    this.onlineSameday = const [],
  });

  factory OrderTexts.fromJson(Map<String, dynamic> j) => OrderTexts(
    noRepeatLast: (j['noRepeatLast'] as num).toInt(),
    holidayChance: (j['holidayChance'] as num).toDouble(),
    byOccasion: _groups(j['byOccasion']),
    byHoliday: _groups(j['byHoliday']),
    customers: [
      for (final c in (j['customers'] as List? ?? const []))
        CustomerProfile.fromJson(c as Map<String, dynamic>),
    ],
    speakerOnly: {
      for (final e
          in ((j['speakerOnly'] as Map<String, dynamic>?) ?? const {}).entries)
        if (!e.key.startsWith('_'))
          e.key: SpeakerRule.fromJson(e.value as Map<String, dynamic>),
    },
    onlinePreorder: _onlineGroup(j['online'], 'preorder'),
    onlineSameday: _onlineGroup(j['online'], 'sameday'),
  );

  final int noRepeatLast;
  final double holidayChance;
  final Map<String, List<String>> byOccasion;
  final Map<String, List<String>> byHoliday;
  final List<CustomerProfile> customers;

  /// Request line -> who may say it. Lines not listed are for anyone.
  final Map<String, SpeakerRule> speakerOnly;

  /// Morning-board lines (`orders.json` `online.preorder`).
  final List<String> onlinePreorder;

  /// Same-day card lines (`orders.json` `online.sameday`).
  final List<String> onlineSameday;

  /// True when [line] may be given to [speaker] (orders.json `speakerRule`).
  bool canSay(String line, CustomerProfile? speaker) {
    final rule = speakerOnly[line];
    if (rule == null) return true;
    return speaker != null && rule.allows(speaker);
  }

  /// Same texts, with avatar ids filled from customers/index.json.
  OrderTexts withAvatars(Map<String, String> avatarByName) => OrderTexts(
    noRepeatLast: noRepeatLast,
    holidayChance: holidayChance,
    byOccasion: byOccasion,
    byHoliday: byHoliday,
    customers: [
      for (final c in customers)
        avatarByName[c.name] == null ? c : c.withAvatar(avatarByName[c.name]!),
    ],
    speakerOnly: speakerOnly,
    onlinePreorder: onlinePreorder,
    onlineSameday: onlineSameday,
  );
}

List<String> _strings(Object? v) =>
    v == null ? const [] : (v as List).cast<String>();

/// `online` is `{preorder: [...], sameday: [...]}`.
List<String> _onlineGroup(Object? online, String key) {
  if (online is! Map) return const [];
  return _strings(online[key]);
}

Map<String, List<String>> _groups(Object? v) {
  if (v == null) return const {};
  return {
    for (final e in (v as Map<String, dynamic>).entries)
      if (!e.key.startsWith('_')) e.key: _strings(e.value),
  };
}
