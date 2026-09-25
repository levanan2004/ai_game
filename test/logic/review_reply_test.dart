import 'dart:convert';
import 'dart:math';

import 'package:ai_game/logic/review_picker.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ReviewRecord _review({String outcome = 'great', String comment = 'Đẹp quá'}) {
  return ReviewRecord(
    day: 1,
    customerName: 'Lan Anh',
    avatarId: 'lan_anh',
    occasionId: 'birthday',
    stars: 5,
    comment: comment,
    outcome: outcome,
  );
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
      }
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

  test('an outcome without replies offers no chips', () {
    expect(ownerReplyChoices(texts, 'missing', Random(0)), isEmpty);
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
    expect(s.replyToReview(s.state.reviews.single, 'Đổi ý'), isFalse);
    expect(s.state.reviews.single.replyText, 'Cảm ơn bạn đã ghé');
    await s.pendingSaves;

    final loaded = GameState.decode(backing[ProgressStore.storageKey]);
    expect(loaded!.reviews.single.replyText, 'Cảm ơn bạn đã ghé');
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
}
