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
    expect(_hit('/play-tiem-hoa-som-mai/'), (200, '/index.html'));
    expect(_hit('/play-tiem-hoa-som-mai'), (301, '/play-tiem-hoa-som-mai/'));
    expect(_hit('/quan-tri/'), (200, '/index.html'));
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
}
