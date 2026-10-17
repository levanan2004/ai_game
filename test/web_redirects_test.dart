import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// First matching rule wins, like Cloudflare Pages. A 200 rule is a rewrite and
/// is not redirected again.
class _Rule {
  _Rule(this.from, this.to, this.code);
  final String from;
  final String to;
  final int code;
}

List<_Rule> _rules() {
  final out = <_Rule>[];
  for (final raw in File('web/_redirects').readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final p = line.split(RegExp(r'\s+'));
    out.add(_Rule(p[0], p[1], p.length > 2 ? int.parse(p[2]) : 302));
  }
  return out;
}

/// (status, location or rewritten file) for [path].
(int, String?) _hit(String path) {
  for (final r in _rules()) {
    if (r.from == path) return (r.code, r.to);
  }
  return (200, null);
}

void main() {
  test('every _redirects source is a path (a host can never match)', () {
    for (final r in _rules()) {
      expect(r.from, startsWith('/'), reason: r.from);
    }
  });

  test('/site, /site/ and /site.html 301 to the home page', () {
    for (final p in ['/site', '/site/', '/site.html']) {
      expect(_hit(p), (301, '/'), reason: p);
    }
  });

  test('/ is the home page (200 rewrite to /site), play and guides stay', () {
    expect(_hit('/'), (200, '/site'));
    expect(File('web/site.html').existsSync(), isTrue);
    expect(_hit('/play'), (200, null));
    expect(_hit('/choi'), (301, '/play'));
    expect(_hit('/choi/'), (301, '/play'));
    expect(_hit('/play-tiem-hoa-som-mai'), (301, '/play'));
    expect(_hit('/play-tiem-hoa-som-mai/'), (301, '/play'));
    expect(_hit('/play%20tiem%20hoa%20som%20mai'), (301, '/play'));
    expect(_hit('/quan-tri'), (200, null));
    expect(_hit('/quan-tri/'), (301, '/quan-tri'));
    expect(
      _hit('/tai/android'),
      (
        302,
        'https://github.com/levanan2004/ai_game/releases/download/android-open/TiemHoaSomMai.apk',
      ),
    );
    expect(_hit('/huong-dan'), (200, null));
    expect(_hit('/y-nghia-hoa'), (200, null));
    expect(_hit('/huong-dan.html'), (301, '/huong-dan'));
    expect(File('web/huong-dan.html').existsSync(), isTrue);
    expect(File('web/y-nghia-hoa.html').existsSync(), isTrue);
  });

  test('the rewrite of / is the last rule and the /site rules come first', () {
    final rules = _rules();
    expect(rules.last.from, '/');
    final site = rules.indexWhere((r) => r.from == '/site');
    expect(site, lessThan(rules.indexWhere((r) => r.from == '/')));
  });

  test('home canonical is /, no page or the sitemap points at /site', () {
    final home = File('web/site.html').readAsStringSync();
    expect(home, contains('rel="canonical" href="https://tiemhoasommai.com/"'));
    expect(
      File('web/sitemap.xml').readAsStringSync(),
      isNot(contains('tiemhoasommai.com/site')),
    );
    for (final f in Directory('web').listSync().whereType<File>()) {
      if (!f.path.endsWith('.html')) continue;
      expect(
        f.readAsStringSync(),
        isNot(contains('href="/site"')),
        reason: f.path,
      );
    }
  });

  test('_headers and _redirects sit at the web root for the build', () {
    expect(File('web/_headers').existsSync(), isTrue);
    expect(File('web/_redirects').existsSync(), isTrue);
  });

  test('unknown URLs get a real 404: 404.html exists and no catch-all rule', () {
    final page = File('web/404.html');
    expect(page.existsSync(), isTrue);
    final html = page.readAsStringSync();
    expect(html, contains('noindex'));
    expect(html, contains('href="/"'));
    for (final r in _rules()) {
      expect(r.from, isNot(contains('*')), reason: 'catch-all swallows 404s');
      expect(r.from, isNot(contains(':')), reason: 'placeholder rule ${r.from}');
    }
    // Only the game routes and the home page are rewritten (200).
    final rewrites = _rules().where((r) => r.code == 200).map((r) => r.from);
    expect(
      rewrites.toSet(),
      {'/'},
    );
    // A made-up path matches no rule, so Pages falls through to 404.html.
    expect(_hit('/khong-co-trang-nay'), (200, null));
    expect(File('web/khong-co-trang-nay.html').existsSync(), isFalse);
  });

  test('every published content page is a clean URL and listed in the sitemap',
      () {
    const pages = [
      'meo-tang-sao',
      'thu-cung-chau-hoa',
      'cham-soc-hoa-tuoi',
      'hoi-dap',
      'nhat-ky-cap-nhat',
      'hoa-tet',
      'hoa-8-3-20-10-14-2',
      'hoa-20-11',
    ];
    final sitemap = File('web/sitemap.xml').readAsStringSync();
    for (final p in pages) {
      expect(File('web/$p.html').existsSync(), isTrue, reason: p);
      expect(_hit('/$p.html'), (301, '/$p'), reason: p);
      expect(_hit('/$p'), (200, null), reason: p);
      expect(sitemap, contains('https://tiemhoasommai.com/$p</loc>'));
      final html = File('web/$p.html').readAsStringSync();
      expect(html, contains('rel="canonical" href="https://tiemhoasommai.com/$p"'));
      expect(html, contains('https://tiemhoasommai.com/og_image_1200x630.png'));
    }
  });

  test('public pages have no alpha / ung ho / Dai thien nhan wording', () {
    final banned = RegExp('alpha|\u1EE7ng h\u1ED9|\u0110\u1EA1i thi\u1EC7n nh\u00E2n', caseSensitive: false);
    for (final f in Directory('web').listSync().whereType<File>()) {
      if (!f.path.endsWith('.html')) continue;
      if (f.path.endsWith('privacy.html') || f.path.endsWith('xoa-tai-khoan.html')) {
        continue; // describe the removed donation records being deleted
      }
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('every internal link on a page resolves to a file or a rule', () {
    final names = Directory('web').listSync().whereType<File>()
        .map((f) => f.path.split(RegExp(r'[\\/]')).last).toSet();
    final ok = <String>{
      '/',
      '/play',
      '/choi',
      '/quan-tri',
      '/play-tiem-hoa-som-mai/',
      for (final r in _rules()) r.from,
    };
    for (final n in names) {
      if (n.endsWith('.html') && n != 'index.html' && n != 'site.html' && n != '404.html') {
        ok.add('/${n.substring(0, n.length - 5)}');
      }
    }
    final href = RegExp('href="(/[^"#?]*)');
    for (final f in Directory('web').listSync().whereType<File>()) {
      if (!f.path.endsWith('.html')) continue;
      for (final m in href.allMatches(f.readAsStringSync())) {
        final h = m.group(1)!;
        if (RegExp(r'\.(png|ico|css|webp|json|js)$').hasMatch(h)) continue;
        expect(ok, contains(h), reason: '${f.path} -> $h');
      }
    }
  });

  test('legal pages are version 4; xoa-tai-khoan names the chat data', () {
    final line = RegExp(
      r'<p class="nho">Phiên bản 4 · Có hiệu lực từ \d{2}/\d{2}/\d{4}</p>',
    );
    for (final p in ['privacy', 'terms', 'xoa-tai-khoan']) {
      final html = File('web/$p.html').readAsStringSync();
      expect(line.allMatches(html), hasLength(1), reason: p);
    }
    expect(
      File('web/xoa-tai-khoan.html').readAsStringSync(),
      contains(
        'Khi xóa tài khoản, tụi mình cũng xóa danh sách người chơi bạn đã chặn '
        'hoặc ẩn, đồng ý nội quy chat, mọi tin nhắn Tin thế giới của bạn và các '
        'báo cáo chat do bạn gửi hoặc về bạn.',
      ),
    );
  });
}
