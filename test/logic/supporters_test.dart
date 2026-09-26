import 'package:ai_game/logic/format.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/supporters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Supporter _s({
  required String id,
  int? amount,
  DateTime? date,
  bool visible = true,
  String name = 'Lan',
  String avatar = 'minh_anh',
}) {
  return Supporter(
    id: id,
    name: name,
    message: '',
    date: date,
    visible: visible,
    avatar: avatar,
    amount: amount,
  );
}

void main() {
  final older = DateTime.utc(2026, 1, 1);
  final newer = DateTime.utc(2026, 6, 1);

  test('supporters sort by amount, then date, hiding visible false', () {
    final sorted = sortSupporters([
      _s(id: 'low', amount: 50000, date: newer),
      _s(id: 'high', amount: 1000000, date: older),
      _s(id: 'tieOld', amount: 200000, date: older),
      _s(id: 'tieNew', amount: 200000, date: newer),
      _s(id: 'noneNew', date: newer),
      _s(id: 'zero', amount: 0, date: older),
      _s(id: 'hidden', amount: 9000000, date: newer, visible: false),
    ]);
    expect(sorted.map((s) => s.id), [
      'high',
      'tieNew',
      'tieOld',
      'low',
      'noneNew',
      'zero',
    ]);
  });

  test('missing visible stays on the board; empty name is anonymous', () {
    final one = supporterFromFields(id: 'a', name: '  ', amount: 50000);
    expect(one.visible, isTrue);
    expect(one.displayName, 'Một người ẩn danh');
    expect(sortSupporters([one]).single.id, 'a');
    final hidden = supporterFromFields(id: 'b', visible: false, amount: 1);
    expect(sortSupporters([hidden]), isEmpty);
  });

  test('storage avatar urls encode the path; preset codes do not', () {
    expect(storageAvatarUrl('minh_anh'), isNull);
    expect(storageAvatarUrl(''), isNull);
    expect(
      storageAvatarUrl('supporters/minh_anh.jpg'),
      'https://firebasestorage.googleapis.com/v0/b/'
      'tiem-hoa-som-mai.firebasestorage.app/o/'
      'supporters%2Fminh_anh.jpg?alt=media',
    );
  });

  test('support amounts use k under 1tr and one decimal above', () {
    expect(formatSupportAmount(null), isNull);
    expect(formatSupportAmount(0), isNull);
    expect(formatSupportAmount(-1), isNull);
    expect(formatSupportAmount(50000), '50k');
    expect(formatSupportAmount(200000), '200k');
    expect(formatSupportAmount(1000000), '1tr');
    expect(formatSupportAmount(1200000), '1,2tr');
    expect(formatSupportAmount(2000000), '2tr');
    expect(formatSupportAmount(1150000), '1,2tr');
  });

  test('admin amounts accept plain, dotted, k and tr forms', () {
    expect(parseSupportAmount(''), 0);
    expect(parseSupportAmount('200000'), 200000);
    expect(parseSupportAmount('200.000'), 200000);
    expect(parseSupportAmount('200k'), 200000);
    expect(parseSupportAmount('1,5tr'), 1500000);
    expect(parseSupportAmount('2 TR'), 2000000);
    expect(parseSupportAmount('abc'), isNull);
    expect(parseSupportAmount('-5'), isNull);
  });

  test('admin dates are dd/mm/yyyy and must exist', () {
    expect(parseDayMonthYear('26/09/2026'), DateTime(2026, 9, 26));
    expect(parseDayMonthYear('1-2-2026'), DateTime(2026, 2, 1));
    expect(parseDayMonthYear('31/02/2026'), isNull);
    expect(parseDayMonthYear('2026-09-26'), isNull);
    expect(formatDayMonthYear(DateTime(2026, 2, 1)), '01/02/2026');
  });

  test('phones keep digits and a leading plus', () {
    expect(normalizePhone(''), '');
    expect(normalizePhone('090 123 4567'), '0901234567');
    expect(normalizePhone('+84.901.234.567'), '+84901234567');
    expect(normalizePhone('12345'), isNull);
    expect(normalizePhone('09abc'), isNull);
  });

  test('opening the donor board pauses the day and closing returns', () {
    final s = newSession();
    stockAndOpen(s);
    expect(s.screen, Screen.shop);
    final before = s.state.elapsed;
    s.openDonors();
    expect(s.screen, Screen.donors);
    expect(s.paused, isTrue);
    s.tick(5);
    expect(s.state.elapsed, before);
    s.closeDonors();
    expect(s.screen, Screen.shop);
    expect(s.paused, isFalse);
    s.tick(1);
    expect(s.state.elapsed, greaterThan(before));
  });

  test('a clock already paused stays paused after the donor board', () {
    final s = newSession();
    stockAndOpen(s);
    s.openPause();
    s.openDonors();
    s.closeDonors();
    expect(s.screen, Screen.shop);
    expect(s.paused, isTrue);
    expect(s.pauseMenuOpen, isTrue);
  });
}
