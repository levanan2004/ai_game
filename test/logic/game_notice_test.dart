import 'package:ai_game/logic/game_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notice links are https, http, or a site path', () {
    expect(
      normalizeNoticeLink(' https://tiemhoasommai.com/about '),
      'https://tiemhoasommai.com/about',
    );
    expect(normalizeNoticeLink('http://example.com/a'), 'http://example.com/a');
    expect(normalizeNoticeLink('/about'), '/about');
    expect(normalizeNoticeLink('/'), '/');
    expect(normalizeNoticeLink(''), isNull);
    expect(normalizeNoticeLink('javascript:alert(1)'), isNull);
    expect(normalizeNoticeLink('//evil.com'), isNull);
    expect(normalizeNoticeLink('tiemhoasommai.com'), isNull);
    expect(normalizeNoticeLink('/about page'), isNull);
  });

  test('notice search matches title or body and sort flips direction', () {
    final older = GameNotice(
      id: 'old',
      title: 'Bảo trì',
      body: 'Tối nay',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final newer = GameNotice(
      id: 'new',
      title: 'Sự kiện',
      body: 'Ghé trang chủ',
      createdAt: DateTime.utc(2026, 9, 1),
    );
    final blank = GameNotice(id: 'blank', title: '', body: '');
    expect(noticeMatches(newer, 'trang'), isTrue);
    expect(noticeMatches(older, 'sự'), isFalse);
    expect(noticeMatches(newer, '  '), isTrue);

    final rows = [older, newer, blank];
    expect(sortNotices(rows, NoticeListSort.created).map((n) => n.id), [
      'new',
      'old',
      'blank',
    ]);
    expect(
      sortNotices(
        rows,
        NoticeListSort.created,
        ascending: true,
      ).map((n) => n.id),
      ['old', 'new', 'blank'],
    );
    expect(sortNotices(rows, NoticeListSort.title).map((n) => n.id), [
      'new',
      'old',
      'blank',
    ]);
    expect(
      sortNotices(rows, NoticeListSort.title, ascending: true).map((n) => n.id),
      ['old', 'new', 'blank'],
    );
  });
}
