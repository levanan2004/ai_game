import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('economy, reviews and orders parse', () {
    final d = loadTestData();
    final e = d.economy;
    expect(e.maxStems, greaterThan(0));
    expect(
      e.weightSpecies + e.weightStemCount + e.weightPaper + e.weightRibbon,
      closeTo(1, 1e-9),
    );
    expect(e.upgrades, isNotEmpty);
    for (final o in ['great', 'okay', 'unhappy', 'leftUnserved']) {
      expect(d.reviews.outcomes[o]!.generic, isNotEmpty, reason: o);
    }
    expect(d.orders.customers, isNotEmpty);
    for (final c in d.orders.customers) {
      expect(['m', 'f'], contains(c.gender), reason: c.name);
      expect(['teen', 'adult', 'senior'], contains(c.age), reason: c.name);
      expect(c.avatarId, isNotEmpty, reason: 'no avatar for ${c.name}');
      expect(
        File('assets/images/customers/${c.avatarId}.png').existsSync(),
        isTrue,
        reason: c.avatarId,
      );
    }
    for (final line in d.orders.speakerOnly.keys) {
      final all = [
        for (final l in d.orders.byOccasion.values) ...l,
        for (final l in d.orders.byHoliday.values) ...l,
      ];
      expect(all, contains(line), reason: 'speakerOnly line not used: $line');
    }
    for (final o in e.occasions) {
      expect(d.orders.byOccasion[o.id], isNotEmpty, reason: o.id);
    }
  });

  test('every review sentence respects maxChars', () {
    final r = loadTestData().reviews;
    for (final o in r.outcomes.values) {
      for (final s in [
        ...o.generic,
        for (final l in o.byReason.values) ...l,
        for (final l in o.byOccasion.values) ...l,
        for (final l in o.byHoliday.values) ...l,
      ]) {
        expect(s.length, lessThanOrEqualTo(r.maxChars), reason: s);
      }
    }
  });

  test('art exists for every flower, paper, ribbon and upgrade id', () {
    final e = loadTestData().economy;
    final files = [
      for (final f in e.flowers) 'flowers/${f.id}',
      for (final p in e.papers) 'papers/${p.id}',
      for (final r in e.ribbons) 'ribbons/${r.id}',
      for (final u in e.upgrades) 'upgrades/${u.id}',
    ];
    for (final f in files) {
      expect(File('assets/images/$f.png').existsSync(), isTrue, reason: f);
    }
  });
}
