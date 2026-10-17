import 'package:ai_game/data/season_clock.dart';
import 'package:ai_game/data/titles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;

  test('economy.json: the two champion titles, names from the config', () {
    expect(e.titles.review!.id, TitleIds.rating);
    expect(e.titles.review!.name, 'Đệ Nhất Gói Hoa');
    expect(e.titles.review!.rank, 1);
    expect(e.titles.charm!.id, TitleIds.charm);
    expect(e.titles.charm!.name, 'Mị Lực Nhất Trời');
    expect(e.titles.nameOf(TitleIds.charm), 'Mị Lực Nhất Trời');
    expect(e.titles.nameOf('nope'), '');
    // Without the blocks: Nhất's text keys.
    const none = ChampionTitles();
    expect(none.nameOf(TitleIds.rating), TitleText.ratingChampion);
    expect(none.nameOf(TitleIds.charm), TitleText.charmChampion);
    expect(
      ChampionTitleConfig.fromJson({'name': ' '}, TitleBoard.charm),
      isNull,
    );
    expect(e.titles.review!.coversRange(1, 1), isTrue);
    expect(e.titles.review!.coversRange(2, 2), isFalse);
  });

  test('public_profiles + titles/: held, held before, pin only while held', () {
    final holders = {
      TitleIds.rating: TitleHolder.fromMap(TitleIds.rating, {
        'holderUid': 'b',
        'period': 'rating-4',
        'seasonEnd': DateTime.utc(2027, 1, 31, 17),
      })!,
      TitleIds.charm: TitleHolder.fromMap(TitleIds.charm, {
        'holderUid': 'a',
        'period': 'season-3',
      })!,
    };
    final a = PlayerTitles.fromMaps('a', {
      'titleStats': {
        TitleIds.rating: {'timesWon': 2, 'lastPeriod': 'rating-3'},
        TitleIds.charm: {'timesWon': 1, 'lastPeriod': 'season-3'},
        'junk': 5,
      },
      'pinnedTitle': TitleIds.rating,
      'bestRank': {
        'charm': {'rank': 1, 'period': 'season-3'},
        'review': {'rank': 0},
      },
    }, holders);
    expect(a.holds(TitleIds.charm), isTrue);
    expect(a.holds(TitleIds.rating), isFalse, reason: 'b took it');
    expect(a.wearing, '', reason: 'the pin of a lost title is not worn');
    expect(a.timesWon(TitleIds.rating), 2);
    expect(a.listed, [TitleIds.charm, TitleIds.rating]);
    expect(a.bestRank[TitleBoard.charm]!.rank, 1);
    expect(a.bestRank.containsKey(TitleBoard.review), isFalse);
    expect(TitleHolder.fromMap('x', {'holderUid': ''}), isNull);
    // b holds the rating title with no stats doc yet: still listed.
    final b = PlayerTitles.fromMaps('b', {
      'pinnedTitle': TitleIds.rating,
    }, holders);
    expect(b.listed, [TitleIds.rating]);
    expect(b.wearing, TitleIds.rating);
    // A player without anything.
    final none = PlayerTitles.fromMaps('z', null, holders);
    expect(none.listed, isEmpty);
    expect(none.wearing, '');
  });

  test('a permanent title (the coming milestones) is held for good', () {
    final m = PlayerTitles.fromMaps('m', {
      'titleStats': {
        'danh_hieu_1k': {'permanent': true},
      },
      'pinnedTitle': 'danh_hieu_1k',
    }, const {});
    expect(m.holds('danh_hieu_1k'), isTrue);
    expect(m.wearing, 'danh_hieu_1k');
    expect(m.listed, ['danh_hieu_1k']);
  });

  test('"mùa {month}/{year}": the VN month of the season\'s last day', () {
    // rating-2 ends Mon 07/12 00:00 VN: its last day is Sun 06/12.
    expect(titleSeasonMonth(DateTime.utc(2026, 12, 6, 17)), (
      month: 12,
      year: 2026,
    ));
    // A season ending Mon 01/02 00:00 VN closes on Sun 31/01.
    expect(titleSeasonMonth(DateTime.utc(2027, 1, 31, 17)), (
      month: 1,
      year: 2027,
    ));
    final holders = {
      TitleIds.rating: TitleHolder(
        titleId: TitleIds.rating,
        holderUid: 'a',
        seasonEnd: DateTime.utc(2026, 12, 6, 17),
      ),
    };
    final a = PlayerTitles.fromMaps('a', {
      'titleStats': {
        TitleIds.charm: {'timesWon': 1, 'lastPeriod': 'season-1'},
      },
    }, holders);
    expect(
      titleDetail(TitleIds.rating, a, null),
      'Hạng 1 bảng Đánh giá · mùa 12/2026',
    );
    // A lost title: the last season won, from the Mị lực clock (S1 ends 08/11).
    final clock = e.charmBoard.clock;
    expect(clock, isA<SeasonClock>());
    expect(
      titleDetail(TitleIds.charm, a, clock),
      'Hạng 1 bảng Mị lực · mùa 11/2026',
    );
    expect(titleDetail(TitleIds.charm, a, null), '');
  });
}
