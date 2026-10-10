import 'dart:math';

import 'package:flutter/foundation.dart';

import 'rewards.dart';
import 'welfare_text.dart';

/// No 0/O or 1/I, so a code read aloud or from a screenshot is not mistyped.
const giftcodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Random characters after the prefix of a bulk code.
const giftcodeRandomLength = 10;
const maxGiftcodePrefix = 8;
const maxGiftcodeBatch = 10000;

/// Firestore allows 500 writes per batch.
const giftcodeWriteChunk = 500;

/// Codes are stored as `giftcodes/{CODE}`.
final _codeShape = RegExp(r'^[A-Z0-9]{4,32}$');

/// Turns what the player typed into a document id, on submit only (the
/// field itself has no formatter, so UniKey typing is never disturbed).
/// Null when it cannot be a code.
String? normalizeGiftcode(String raw) {
  final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
  return _codeShape.hasMatch(code) ? code : null;
}

/// Prefix of a bulk batch: empty, or up to [maxGiftcodePrefix] of A–Z/0–9.
String? normalizeGiftcodePrefix(String raw) {
  final p = raw.trim().toUpperCase();
  if (p.isEmpty) return '';
  if (p.length > maxGiftcodePrefix) return null;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(p) ? p : null;
}

/// [count] distinct codes: [prefix] then [giftcodeRandomLength] characters
/// of [giftcodeAlphabet] from a crypto-strength random source.
List<String> generateGiftcodes(
  int count, {
  String prefix = '',
  Random? random,
  Set<String> avoid = const {},
}) {
  final rng = random ?? Random.secure();
  final out = <String>{};
  while (out.length < count) {
    final b = StringBuffer(prefix);
    for (var i = 0; i < giftcodeRandomLength; i++) {
      b.write(giftcodeAlphabet[rng.nextInt(giftcodeAlphabet.length)]);
    }
    final code = b.toString();
    if (!avoid.contains(code)) out.add(code);
  }
  return out.toList();
}

enum GiftcodeType {
  /// One code, each player once, optional total limit.
  shared,

  /// A batch of codes, each used by one player.
  single,
}

/// `giftcodeBatches/{id}`: rewards, dates and the on/off switch for every
/// code of the batch. A player may redeem one code per batch.
@immutable
class GiftcodeBatch {
  GiftcodeBatch({
    required this.id,
    required this.type,
    RewardBundle? rewards,
    this.title = '',
    this.prefix = '',
    this.count = 1,
    this.code,
    this.enabled = true,
    this.startsAt,
    this.expiresAt,
    this.maxUses,
    this.createdAt,
  }) : rewards = rewards ?? RewardBundle.empty;

  final String id;
  final GiftcodeType type;
  final RewardBundle rewards;

  /// Admin note, e.g. "Livestream 10/10".
  final String title;
  final String prefix;
  final int count;

  /// The code of a shared batch. Null for bulk batches (the codes are only
  /// in `giftcodes/`).
  final String? code;
  final bool enabled;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  /// Shared codes only. Null: no limit.
  final int? maxUses;
  final DateTime? createdAt;

  GiftcodeBatch copyWith({bool? enabled}) => GiftcodeBatch(
    id: id,
    type: type,
    rewards: rewards,
    title: title,
    prefix: prefix,
    count: count,
    code: code,
    enabled: enabled ?? this.enabled,
    startsAt: startsAt,
    expiresAt: expiresAt,
    maxUses: maxUses,
    createdAt: createdAt,
  );

  /// Dates stay [DateTime]; the store converts them. `createdAt` is added
  /// by the store (server time).
  Map<String, Object?> toMap() => {
    'type': type.name,
    'title': title.trim(),
    'prefix': prefix,
    'count': count,
    'code': ?code,
    'rewards': rewards.toJson(),
    'enabled': enabled,
    'startsAt': ?startsAt,
    'expiresAt': ?expiresAt,
    'maxUses': ?maxUses,
  };

  static GiftcodeBatch? fromMap(
    String id,
    Map<String, Object?> data, {
    DateTime? Function(Object? raw)? date,
  }) {
    final type = switch (data['type']) {
      'shared' => GiftcodeType.shared,
      'single' => GiftcodeType.single,
      _ => null,
    };
    if (type == null) return null;
    final readDate = date ?? (raw) => raw is DateTime ? raw : null;
    final count = data['count'];
    final maxUses = data['maxUses'];
    return GiftcodeBatch(
      id: id,
      type: type,
      rewards: RewardBundle.fromJson(data['rewards']),
      title: data['title'] is String ? data['title'] as String : '',
      prefix: data['prefix'] is String ? data['prefix'] as String : '',
      count: count is int ? count : 1,
      code: data['code'] is String ? data['code'] as String : null,
      enabled: data['enabled'] == true,
      startsAt: readDate(data['startsAt']),
      expiresAt: readDate(data['expiresAt']),
      maxUses: maxUses is int ? maxUses : null,
      createdAt: readDate(data['createdAt']),
    );
  }
}

/// `giftcodes/{CODE}`. Players may `get` the one they typed, never list.
@immutable
class GiftcodeDoc {
  const GiftcodeDoc({
    required this.code,
    required this.type,
    required this.batchId,
    this.uses = 0,
    this.maxUses,
    this.usedBy,
  });

  final String code;
  final GiftcodeType type;
  final String batchId;

  /// Shared codes: players who redeemed it so far.
  final int uses;
  final int? maxUses;

  /// Single-use codes: the player who redeemed it.
  final String? usedBy;

  Map<String, Object?> toMap() => {
    'type': type.name,
    'batchId': batchId,
    if (type == GiftcodeType.shared) 'uses': uses,
    'maxUses': ?maxUses,
    'usedBy': ?usedBy,
  };

  static GiftcodeDoc? fromMap(String code, Map<String, Object?>? data) {
    if (data == null) return null;
    final type = switch (data['type']) {
      'shared' => GiftcodeType.shared,
      'single' => GiftcodeType.single,
      _ => null,
    };
    final batchId = data['batchId'];
    if (type == null || batchId is! String || batchId.isEmpty) return null;
    final uses = data['uses'];
    final maxUses = data['maxUses'];
    final usedBy = data['usedBy'];
    return GiftcodeDoc(
      code: code,
      type: type,
      batchId: batchId,
      uses: uses is int ? uses : 0,
      maxUses: maxUses is int ? maxUses : null,
      usedBy: usedBy is String && usedBy.isNotEmpty ? usedBy : null,
    );
  }
}

enum RedeemResult {
  success,

  /// Nothing typed.
  empty,

  /// No such code.
  invalid,
  notStarted,
  expired,
  disabled,

  /// Single code used by someone else, or a shared code at its limit.
  used,

  /// This player already redeemed this code or another of the batch.
  already,

  /// A redeem is still running (double tap).
  busy,
  signedOut,

  /// This tab may not write the account right now.
  refused,
  failed,
}

/// What the player reads under the field (copy in [WelfareText]).
/// Disabled and not-yet-started codes read as a wrong code.
String redeemMessage(RedeemResult result) => switch (result) {
  RedeemResult.success => WelfareText.codeSuccess,
  RedeemResult.empty => WelfareText.codeEmpty,
  RedeemResult.invalid ||
  RedeemResult.notStarted ||
  RedeemResult.disabled => WelfareText.codeWrong,
  RedeemResult.expired => WelfareText.codeExpired,
  RedeemResult.used => WelfareText.codeUsed,
  RedeemResult.already => WelfareText.codeAlready,
  RedeemResult.busy => WelfareText.codeBusy,
  RedeemResult.signedOut => WelfareText.codeGuest,
  RedeemResult.refused => WelfareText.codeRefused,
  RedeemResult.failed => WelfareText.codeFailed,
};

/// Null when [uid] may redeem [code] now. The transaction and firestore.rules
/// check the same things.
RedeemResult? checkRedeem({
  required GiftcodeDoc? code,
  required GiftcodeBatch? batch,
  required bool redeemedBatch,
  required String uid,
  required DateTime now,
}) {
  if (code == null || batch == null || batch.id != code.batchId) {
    return RedeemResult.invalid;
  }
  if (code.type == GiftcodeType.single && code.usedBy == uid) {
    return RedeemResult.already;
  }
  if (redeemedBatch) return RedeemResult.already;
  if (!batch.enabled) return RedeemResult.disabled;
  if (batch.startsAt != null && now.isBefore(batch.startsAt!)) {
    return RedeemResult.notStarted;
  }
  if (batch.expiresAt != null && !batch.expiresAt!.isAfter(now)) {
    return RedeemResult.expired;
  }
  switch (code.type) {
    case GiftcodeType.single:
      if (code.usedBy != null) return RedeemResult.used;
    case GiftcodeType.shared:
      final limit = code.maxUses;
      if (limit != null && code.uses >= limit) return RedeemResult.used;
  }
  return null;
}

@immutable
class RedeemOutcome {
  RedeemOutcome(this.result, {RewardBundle? rewards, this.code = ''})
    : rewards = rewards ?? RewardBundle.empty;

  final RedeemResult result;

  /// The gift, when [result] is [RedeemResult.success].
  final RewardBundle rewards;
  final String code;

  String get message => redeemMessage(result);
}

/// One line of the CSV an admin downloads.
@immutable
class GiftcodeRow {
  const GiftcodeRow(this.code, {this.usedBy});

  final String code;
  final String? usedBy;
}

/// `code,used_by` lines, header first.
String giftcodeCsv(Iterable<GiftcodeRow> rows) {
  final b = StringBuffer('code,used_by\n');
  for (final row in rows) {
    b.write(row.code);
    b.write(',');
    b.write(row.usedBy ?? '');
    b.write('\n');
  }
  return b.toString();
}
