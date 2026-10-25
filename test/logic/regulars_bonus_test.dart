import 'dart:convert';

import 'package:ai_game/logic/match_scoring.dart';
import 'package:ai_game/logic/regulars.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final data = loadTestData();
  final cat = data.regulars;

  test('bonusExtra is read from khach_quen_block.json', () {
    expect(cat.giftMatchBonus, 0);
    expect(cat.giftTipMultiplier, 1.0);
    expect(cat.retryMatchBonus, 0.04);
    expect(cat.retryTipMultiplier, 1.0);
    expect(cat.matchBonusCap, 0.12);
    expect(cat.tipMultiplierCap, 1.35);
    expect(cat.lifetimeGreatForOldSaves, 3);
  });

  test('the gift adds nothing; a retry adds the retry hint only', () {
    final plain = regularBonus(cat, retry: false);
    expect(plain.match, 0);
    expect(plain.tipMult, 1.0);
    final retry = regularBonus(cat, retry: true);
    expect(retry.match, closeTo(cat.retryMatchBonus, 1e-9));
    expect(retry.tipMult, 1.0);
    expect(retry.match, lessThanOrEqualTo(cat.matchBonusCap));
  });

  test('a match bonus raises the score and can lift the tier', () {
    final e = data.economy;
    const base = MatchResult(
      score: 0.5,
      species: 1,
      stemCount: 1,
      paper: 1,
      ribbon: 1,
      wiltPenaltyApplied: false,
      tier: Tier.unhappy,
      mismatchReason: null,
    );
    expect(identical(withMatchBonus(e, base, 0), base), isTrue);
    final up = withMatchBonus(e, base, 0.04);
    expect(up.score, closeTo(0.54, 1e-9));
    expect(up.tier, tierFor(e, 0.54));
    expect(withMatchBonus(e, base, 0.9).score, 1.0);
  });

  test('a retry visit of a regular is marked and gets the bonus', () {
    final s = newSession(seed: 7);
    s.state
      ..day = 3
      ..lifetimeGreat = 3;
    s.regularProgress('anh_minh_khoa').retries = 1;
    for (final f in s.unlockedFlowers) {
      if (s.canAddBundle(f.id)) s.addBundle(f.id);
    }
    s.buyAndGoToShop();
    s.openShop();
    for (var t = 0; t < 4000 && s.state.phase == DayPhase.open; t++) {
      if (s.eventOffer != null) s.chooseEvent(s.eventOffer!.choices.last.id);
      if (s.queue.any((c) => c.regularId != null)) break;
      s.tick(0.1);
      for (final c in [...s.queue]) {
        if (c.regularId == null) c.patienceLeft = 0;
      }
    }
    final c = s.queue.firstWhere((c) => c.regularId != null);
    expect(c.regularRetry, isTrue);
    expect(s.regularBonusFor(c).match, closeTo(cat.retryMatchBonus, 1e-9));
  });

  group('lifetimeGreat for old saves', () {
    Map<String, dynamic> saveJson() =>
        jsonDecode(newSession(seed: 1).state.encode()) as Map<String, dynamic>;

    test('a save without the field gets the block number', () {
      final j = saveJson()..remove('lifetimeGreat');
      final old = GameState.decode(jsonEncode(j))!;
      expect(old.lifetimeGreatMissing, isTrue);
      final s = newSession(saved: old);
      expect(s.state.lifetimeGreat, cat.lifetimeGreatForOldSaves);
      expect(s.state.lifetimeGreatMissing, isFalse);
    });

    test('a new save keeps its own count, even 0', () {
      final j = saveJson()..['lifetimeGreat'] = 0;
      final s = newSession(saved: GameState.decode(jsonEncode(j)));
      expect(s.state.lifetimeGreat, 0);
      expect(jsonDecode(s.state.encode())['lifetimeGreat'], 0);
    });
  });
}
