import 'dart:convert';
import 'dart:math';

import 'package:ai_game/logic/review_picker.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ReviewRecord _review({
  String outcome = 'great',
  String comment = 'Đẹp quá',
  int stars = 5,
}) {
  return ReviewRecord(
    day: 1,
    customerName: 'Lan Anh',
    avatarId: 'lan_anh',
    occasionId: 'birthday',
    stars: stars,
    comment: comment,
    outcome: outcome,
  );
}

String _suggestion(String outcome, String tone) {
  return loadTestData().reviews.ownerReplies[outcome]!
      .firstWhere((line) => line.tone == tone)
      .text;
}

void main() {
  final texts = loadTestData().reviews;

  test('suggestion chips are distinct tones from ownerReplies', () {
    for (var seed = 0; seed < 12; seed++) {
      final chips = ownerReplyChoices(texts, 'great', Random(seed));
      expect(chips.length, texts.ownerReplyChoiceCount);
      expect(chips.map((c) => c.tone).toSet(), hasLength(chips.length));
      for (final chip in chips) {
        expect(
          texts.ownerReplies['great']!.map((l) => l.tone),
          contains(chip.tone),
        );
        expect(chip.label, ownerReplyToneLabel[chip.tone]);
        expect(
          texts.ownerReplies['great']!
              .where((l) => l.tone == chip.tone)
              .map((l) => l.text),
          contains(chip.text),
        );
      }
    }
  });

  test('every suggestion fits in the 80-character reply', () {
    final lines = [
      for (final group in texts.ownerReplies.values)
        ...group.map((l) => l.text),
    ];
    expect(lines, isNotEmpty);
    expect(lines.map((s) => s.length).reduce((a, b) => a > b ? a : b), 48);
    for (final line in lines) {
      expect(line.length, lessThanOrEqualTo(48), reason: line);
    }
  });

  test('a chip fills a sentence of that tone', () {
    final line = pickOwnerReply(texts, 'unhappy', 'sorry', Random(2));
    expect(line, isNotNull);
    expect(
      texts.ownerReplies['unhappy']!
          .where((l) => l.tone == 'sorry')
          .map((l) => l.text),
      contains(line),
    );
    expect(pickOwnerReply(texts, 'unhappy', 'no-such-tone', Random(0)), isNull);
  });

  test('an outcome without suggestions still accepts a typed reply', () async {
    expect(ownerReplyChoices(texts, 'missing', Random(0)), isEmpty);
    final s = newSession();
    s.state.addReview(_review(outcome: 'missing'));
    expect(
      s.replyToReview(s.state.reviews.single, 'Mình đã đọc lời bạn'),
      isTrue,
    );
    expect(s.state.reviews.single.replyText, 'Mình đã đọc lời bạn');
    expect(s.state.reviews.single.stars, 5);
    expect(s.state.reviews.single.starRaised, isFalse);
    expect(
      texts.customerFollowUps['typed'],
      contains(s.state.reviews.single.customerReply),
    );
  });

  test('reply text trims, clips to 80, and rejects blank input', () {
    expect(normalizeReply('  '), isNull);
    expect(normalizeReply('  Cảm ơn bạn  '), 'Cảm ơn bạn');
    expect(normalizeReply('a' * 90)!.length, 80);
  });

  test('one reply is saved and a second reply is ignored', () async {
    final first = newSession();
    first.state.addReview(_review());
    final raw = first.state.encode();
    final backing = <String, String>{};
    await ProgressStore.memory(backing).save(GameState.decode(raw)!);
    final s = newSession(backing: backing, saved: GameState.decode(raw));
    final stored = s.state.reviews.single;

    expect(s.replyToReview(stored, '   '), isFalse);
    expect(s.replyToReview(stored, '  Cảm ơn bạn đã ghé  '), isTrue);
    expect(s.state.reviews.single.replyText, 'Cảm ơn bạn đã ghé');
    expect(s.state.reviews.single.stars, 5);
    expect(s.state.reviews.single.customerReply, isNotNull);
    expect(s.replyToReview(s.state.reviews.single, 'Đổi ý'), isFalse);
    expect(s.state.reviews.single.replyText, 'Cảm ơn bạn đã ghé');
    await s.pendingSaves;

    final loaded = GameState.decode(backing[ProgressStore.storageKey]);
    expect(loaded!.reviews.single.replyText, 'Cảm ơn bạn đã ghé');
    expect(loaded.reviews.single.customerReply, isNotNull);
    expect(loaded.reviews.single.stars, 5);
    s.backToTitle();
    expect(s.state.reviews.single.replyText, 'Cảm ơn bạn đã ghé');
  });

  test('a save without replyText still loads', () {
    final s = newSession();
    s.state.addReview(_review());
    final j = s.state.toJson();
    final reviews = (j['reviews'] as List).cast<Map<String, Object?>>();
    reviews.single.remove('replyText');
    final back = GameState.decode(jsonEncode(j));
    expect(back!.reviews.single.replyText, isNull);
  });

  test('a staff review and its card note survive a save', () {
    final s = newSession();
    s.state.addReview(
      ReviewRecord(
        day: 2,
        customerName: 'Bích Ngân',
        avatarId: 'bich_ngan',
        occasionId: 'birthday',
        stars: 4,
        comment: 'Ổn',
        outcome: 'okay',
        byStaff: true,
        cardText: 'Chúc mừng',
      ),
    );
    final back = GameState.decode(jsonEncode(s.state.toJson()));
    final review = back!.reviews.single;
    expect(review.byStaff, isTrue);
    expect(review.cardText, 'Chúc mừng');
  });

  test('customer follow-ups exist for a raise and for every tone', () {
    const keys = [
      'raised',
      'thanks',
      'sorry',
      'improve',
      'invite',
      'cute',
      'typed',
    ];
    for (final key in keys) {
      final lines = texts.customerFollowUps[key];
      expect(lines, isNotEmpty, reason: key);
      for (final line in lines!) {
        expect(line.trim(), line);
        expect(line.length, inInclusiveRange(1, 80), reason: line);
      }
    }
  });

  test('an untouched sorry or improve suggestion adds one star, up to 4', () {
    final s = newSession();
    s.state.addReview(
      _review(outcome: 'unhappy', stars: 3, comment: 'Hơi lệch'),
    );
    final before = s.rating.average;
    expect(
      s.replyToReview(s.state.reviews.single, _suggestion('unhappy', 'sorry')),
      isTrue,
    );
    final review = s.state.reviews.single;
    expect(review.stars, 4);
    expect(review.starRaised, isTrue);
    expect(texts.customerFollowUps['raised'], contains(review.customerReply));
    expect(s.rating.average, greaterThan(before));

    s.state.addReview(
      _review(outcome: 'leftUnserved', stars: 2, comment: 'Chờ quá lâu'),
    );
    expect(
      s.replyToReview(
        s.state.reviews.last,
        _suggestion('leftUnserved', 'improve'),
      ),
      isTrue,
    );
    expect(s.state.reviews.last.stars, 3);

    s.state.addReview(
      _review(outcome: 'onlineMissed', stars: 1, comment: 'Không thấy giao'),
    );
    expect(
      s.replyToReview(
        s.state.reviews.last,
        _suggestion('onlineMissed', 'sorry'),
      ),
      isTrue,
    );
    expect(s.state.reviews.last.stars, 2);
    expect(
      s.replyToReview(
        s.state.reviews.last,
        _suggestion('onlineMissed', 'improve'),
      ),
      isFalse,
    );
    expect(s.state.reviews.last.stars, 2);
  });

  test('a 4-star sorry stays at 4 and the customer still answers', () {
    final s = newSession();
    s.state.addReview(_review(outcome: 'okay', stars: 4, comment: 'Cũng được'));
    final line = _suggestion('okay', 'improve');
    expect(s.replyToReview(s.state.reviews.single, line), isTrue);
    final review = s.state.reviews.single;
    expect(review.stars, 4);
    expect(review.starRaised, isFalse);
    expect(texts.customerFollowUps['improve'], contains(review.customerReply));
  });

  test('thanks, typed text, and an edited suggestion do not change stars', () {
    final s = newSession();
    s.state.addReview(
      _review(outcome: 'unhappy', stars: 3, comment: 'Chưa đúng'),
    );
    expect(
      s.replyToReview(s.state.reviews.single, _suggestion('unhappy', 'thanks')),
      isTrue,
    );
    expect(s.state.reviews.single.stars, 3);
    expect(
      texts.customerFollowUps['thanks'],
      contains(s.state.reviews.single.customerReply),
    );

    final edited = newSession();
    edited.state.addReview(
      _review(outcome: 'unhappy', stars: 3, comment: 'Chưa ưng'),
    );
    final sorry = _suggestion('unhappy', 'sorry');
    expect(
      edited.replyToReview(edited.state.reviews.single, '$sorry nha'),
      isTrue,
    );
    expect(edited.state.reviews.single.stars, 3);
    expect(edited.state.reviews.single.starRaised, isFalse);
    expect(
      texts.customerFollowUps['typed'],
      contains(edited.state.reviews.single.customerReply),
    );
  });

  test('a raised star is still there after the save reloads', () async {
    final first = newSession();
    first.state.addReview(
      _review(outcome: 'unhappy', stars: 3, comment: 'Bó hơi lệch'),
    );
    final raw = first.state.encode();
    final backing = <String, String>{};
    await ProgressStore.memory(backing).save(GameState.decode(raw)!);
    final s = newSession(backing: backing, saved: GameState.decode(raw));
    expect(
      s.replyToReview(s.state.reviews.single, _suggestion('unhappy', 'sorry')),
      isTrue,
    );
    await s.pendingSaves;
    final loaded = GameState.decode(backing[ProgressStore.storageKey]);
    expect(loaded!.reviews.single.stars, 4);
    expect(loaded.reviews.single.starRaised, isTrue);
    expect(loaded.reviews.single.customerReply, isNotNull);
  });

  test(
    'an old reply gains the third customer line without changing stars',
    () async {
      final first = newSession();
      first.state.addReview(
        _review(
          outcome: 'unhappy',
          stars: 4,
          comment: 'Không giống bó',
        ).copyWith(replyText: _suggestion('unhappy', 'improve')),
      );
      final raw = first.state.encode();
      expect(GameState.decode(raw)!.reviews.single.customerReply, isNull);
      final backing = <String, String>{};
      await ProgressStore.memory(backing).save(GameState.decode(raw)!);
      final s = newSession(backing: backing, saved: GameState.decode(raw));
      final review = s.state.reviews.single;
      expect(review.stars, 4);
      expect(review.starRaised, isFalse);
      expect(
        texts.customerFollowUps['improve'],
        contains(review.customerReply),
      );
      await s.pendingSaves;
      final loaded = GameState.decode(backing[ProgressStore.storageKey]);
      expect(loaded!.reviews.single.customerReply, review.customerReply);
      expect(loaded.reviews.single.stars, 4);
    },
  );
}
