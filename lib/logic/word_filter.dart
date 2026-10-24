import 'dart:convert';

import 'vi_unicode.dart';

/// Nhất's bad-word list (assets/data/tu_cam.json, notes in
/// tiem-hoa-marketing/v6_tin_the_gioi/tu_cam_ghi_chu.md), matched the way
/// her checker `_kiem_tra_tu_cam.py` does:
///  1. NFC + lowercase
///  2. drop `.*_-'`~|` between two letters (`d.m` → `dm`)
///  3. join single letters split by spaces or punctuation (`v c l` → `vcl`)
///  4. a letter repeated 3+ times counts once (`vclllll` → `vcl`)
///  5. leet in words that have a letter (`l0z` → `loz`)
/// Accents matter: an entry with `chi_khop_co_dau` matches only the accented
/// text; every other entry matches the text with accents stripped. Words in
/// `danh_sach_trang` are never hit. Python's Unicode `\b`, `\w`, `\W`, `\d`
/// are rewritten for Dart (see [pythonRegexForDart]).
/// functions/word_filter.js is the same filter for the server.
class WordFilter {
  WordFilter._(this._rules, this._whitelist);

  factory WordFilter.fromJson(Map<String, dynamic> json) {
    final rules = <WordRule>[];
    for (final group in (json['nhom'] as List? ?? const [])) {
      for (final m in ((group as Map)['muc'] as List? ?? const [])) {
        final entry = m as Map;
        final id = entry['id'] as String;
        final block = entry['hanh_dong'] == 'chặn';
        final kind = entry['kieu'];
        final pattern = entry['mau'] as String;
        if (kind == 'tu') {
          final accented = entry['chi_khop_co_dau'] == true;
          final variants = [
            pattern,
            ...((entry['bien_the'] as List?) ?? const []).cast<String>(),
          ];
          for (final v in variants) {
            final vv = _nfc(
              v.toLowerCase(),
            ).replaceAll('*', '').replaceAllMapped(_tripleLetter, (x) => x[1]!);
            rules.add(
              WordRule._(
                id,
                block,
                accented ? _Where.accented : _Where.folded,
                RegExp(_word(accented ? vv : foldText(vv)), unicode: true),
              ),
            );
          }
        } else {
          rules.add(
            WordRule._(
              id,
              block,
              kind == 'regex_goc' ? _Where.original : _Where.folded,
              RegExp(pythonRegexForDart(pattern), unicode: true),
            ),
          );
        }
      }
    }
    final white = [
      for (final w in (json['danh_sach_trang'] as List? ?? const []))
        _nfc(w as String),
    ];
    return WordFilter._(rules, [
      for (final w in white)
        (
          RegExp(_word(w), unicode: true),
          RegExp(_word(foldText(w)), unicode: true),
        ),
    ]);
  }

  factory WordFilter.parse(String source) =>
      WordFilter.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// No list (offline tests): only [staffNames] are refused.
  static final empty = WordFilter._(const [], const []);

  static const asset = 'assets/data/tu_cam.json';

  final List<WordRule> _rules;

  /// `danh_sach_trang`: (accented, folded) whole-word patterns.
  final List<(RegExp, RegExp)> _whitelist;

  /// Every rule that matches [raw] (empty when the text is clean).
  List<WordRule> hits(String raw) {
    if (_rules.isEmpty) return const [];
    final original = _nfc(raw).toLowerCase();
    final s = _collapseRepeats(_normalize(original)).join();
    final f = foldText(s);
    final protectedAccented = <int>{};
    final protectedFolded = <int>{};
    for (final (accented, folded) in _whitelist) {
      for (final m in accented.allMatches(s)) {
        for (var i = m.start; i < m.end; i++) {
          protectedAccented.add(i);
        }
      }
      for (final m in folded.allMatches(f)) {
        for (var i = m.start; i < m.end; i++) {
          protectedFolded.add(i);
        }
      }
    }
    final out = <WordRule>[];
    for (final rule in _rules) {
      if (rule._where == _Where.original) {
        if (rule._rx.hasMatch(original)) out.add(rule);
        continue;
      }
      final accented = rule._where == _Where.accented;
      final src = accented ? s : f;
      final guard = accented ? protectedAccented : protectedFolded;
      for (final m in rule._rx.allMatches(src)) {
        if (m.end <= m.start) continue;
        var safe = false;
        for (var i = m.start; i < m.end && !safe; i++) {
          safe = guard.contains(i);
        }
        if (!safe) {
          out.add(rule);
          break;
        }
      }
    }
    return out;
  }

  /// Names a shop may not take on its own, besides the list (tu_cam_ghi_chu
  /// mục 6): only the staff and the game itself use them.
  static const staffNames = [
    'admin',
    'mod',
    'gm',
    'bqt',
    'quản trị viên',
    'tiệm hoa sớm mai',
    'đội tiệm',
  ];

  static final _staff = [
    for (final w in staffNames) RegExp(_word(foldText(w)), unicode: true),
  ];

  /// A shop name is refused on any hit, whether the list says block (`chặn`)
  /// or mask (`che`), and when it uses a staff name as a word.
  bool allowsShopName(String name) {
    if (hits(name).isNotEmpty) return false;
    final f = foldText(
      _collapseRepeats(_normalize(_nfc(name).toLowerCase())).join(),
    );
    return !_staff.any((rx) => rx.hasMatch(f));
  }
}

enum _Where { original, accented, folded }

/// One pattern of the list (a `tu` entry gives one per variant).
class WordRule {
  WordRule._(this.id, this.block, this._where, this._rx);

  /// The entry id, e.g. `tuc_tiu_01`.
  final String id;

  /// `hanh_dong` is `chặn` (refuse the message), not `che` (mask the word).
  final bool block;

  final _Where _where;
  final RegExp _rx;
}

const _separators = {'.', '*', '_', '-', "'", '`', '~', '|'};
const _leet = {'0': 'o', '1': 'i', '3': 'e', '4': 'a', '@': 'a', r'$': 's'};
final _letter = RegExp(r'^\p{L}$', unicode: true);
final _alnum = RegExp(r'^[\p{L}\p{N}]$', unicode: true);
final _tripleLetter = RegExp(r'(\p{L})\1{2,}', unicode: true);

bool _isL(String c) => _letter.hasMatch(c);
bool _isAlnum(String c) => _alnum.hasMatch(c);

/// Steps 2, 3 and 5 of the checker, one entry per code point.
List<String> _normalize(String text) {
  final chars = [for (final r in text.runes) String.fromCharCode(r)];
  final kept = <String>[];
  for (var k = 0; k < chars.length; k++) {
    final c = chars[k];
    if (_separators.contains(c) && kept.isNotEmpty && _isL(kept.last)) {
      var j = k + 1;
      while (j < chars.length && _separators.contains(chars[j])) {
        j++;
      }
      if (j < chars.length && _isL(chars[j])) continue;
    }
    kept.add(c);
  }
  // Tokens: words (letters, digits, @, $) and one token per other character.
  final toks = <(bool, List<String>)>[];
  var cur = <String>[];
  for (final c in kept) {
    if (_isAlnum(c) || c == '@' || c == r'$') {
      cur.add(c);
    } else {
      if (cur.isNotEmpty) toks.add((true, cur));
      cur = <String>[];
      toks.add((false, [c]));
    }
  }
  if (cur.isNotEmpty) toks.add((true, cur));
  bool single((bool, List<String>) t) =>
      t.$1 && t.$2.length == 1 && _isL(t.$2.first);
  final res = <String>[];
  var k = 0;
  while (k < toks.length) {
    final t = toks[k];
    if (single(t)) {
      final run = [t];
      var j = k + 1;
      while (j + 1 < toks.length && !toks[j].$1 && single(toks[j + 1])) {
        run.add(toks[j + 1]);
        j += 2;
      }
      if (run.length >= 2) {
        for (final r in run) {
          res.addAll(r.$2);
        }
        k = j;
        continue;
      }
    }
    res.addAll(t.$2);
    k++;
  }
  // Leet inside each [\w@$]+ run that has a letter and does not start with @.
  var p = 0;
  while (p < res.length) {
    bool wordy(String c) => _isAlnum(c) || c == '_' || c == '@' || c == r'$';
    if (!wordy(res[p])) {
      p++;
      continue;
    }
    var q = p;
    while (q < res.length && wordy(res[q])) {
      q++;
    }
    if (res[p] != '@' && res.sublist(p, q).any(_isL)) {
      for (var i = p; i < q; i++) {
        res[i] = _leet[res[i]] ?? res[i];
      }
    }
    p = q;
  }
  return res;
}

/// Step 4: three or more of the same letter count as one.
List<String> _collapseRepeats(List<String> s) {
  final out = <String>[];
  var p = 0;
  while (p < s.length) {
    var q = p;
    while (q < s.length && s[q] == s[p]) {
      q++;
    }
    if (_isL(s[p]) && q - p >= 3) {
      out.add(s[p]);
    } else {
      out.addAll(s.sublist(p, q));
    }
    p = q;
  }
  return out;
}

/// Whole word: no letter or digit right before or after.
String _word(String text) =>
    r'(?<![\p{L}\p{N}])' +
    _escape(text).replaceAll(' ', r'\s+') +
    r'(?![\p{L}\p{N}])';

String _escape(String text) =>
    text.replaceAllMapped(RegExp(r'[\\^$.|?*+()\[\]{}/]'), (m) => '\\${m[0]}');

const _wordClass = r'\p{L}\p{N}_';
const _boundary =
    r'(?:(?<![\p{L}\p{N}_])(?=[\p{L}\p{N}_])|(?<=[\p{L}\p{N}_])(?![\p{L}\p{N}_]))';

/// Python `re` is Unicode-aware for `\b \w \W \d`; Dart's are ASCII even with
/// `unicode: true`, so they are spelled out with `\p{..}` classes.
String pythonRegexForDart(String pattern) {
  final out = StringBuffer();
  var inClass = false;
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    if (c == r'\' && i + 1 < pattern.length) {
      final n = pattern[++i];
      if (n == 'b' && !inClass) {
        out.write(_boundary);
      } else if (n == 'w') {
        out.write(inClass ? _wordClass : '[$_wordClass]');
      } else if (n == 'W' && !inClass) {
        out.write('[^$_wordClass]');
      } else if (n == 'd') {
        out.write(r'\p{Nd}');
      } else {
        out.write('\\$n');
      }
      continue;
    }
    if (c == '[' && !inClass) {
      inClass = true;
    } else if (c == ']' && inClass) {
      inClass = false;
    }
    out.write(c);
  }
  return out.toString();
}

/// Accents off, `đ` → `d`, one character for one character (so match
/// positions line up with the accented text).
String foldText(String text) {
  final out = StringBuffer();
  for (final r in text.runes) {
    final c = String.fromCharCode(r);
    if (c == 'đ' || c == 'Đ') {
      out.write('d');
    } else {
      final d = viDecompose[c];
      out.write(d == null ? c : d[0]);
    }
  }
  return out.toString();
}

/// NFC for Latin letters: a base letter and its combining marks become the
/// precomposed letter ("e" + U+0323 + U+0302 → "ệ", the way some Vietnamese
/// keyboards type it). Other text is left as it is.
String _nfc(String text) {
  final runes = text.runes.toList();
  final out = StringBuffer();
  var i = 0;
  while (i < runes.length) {
    var j = i + 1;
    while (j < runes.length && viCombiningClass.containsKey(runes[j])) {
      j++;
    }
    final first = String.fromCharCode(runes[i]);
    if (j == i + 1) {
      out.write(first);
      i = j;
      continue;
    }
    // Full decomposition, marks in canonical order, then compose again.
    final parts = [
      for (final r in (viDecompose[first] ?? first).runes) r,
      ...runes.sublist(i + 1, j),
    ];
    // Stable insertion sort: marks of the same class keep their order.
    final marks = <int>[];
    for (final m in parts.skip(1)) {
      var at = marks.length;
      while (at > 0 &&
          (viCombiningClass[marks[at - 1]] ?? 0) > (viCombiningClass[m] ?? 0)) {
        at--;
      }
      marks.insert(at, m);
    }
    var base = String.fromCharCode(parts.first);
    final left = <int>[];
    for (final m in marks) {
      final ccc = viCombiningClass[m] ?? 0;
      final blocked =
          left.isNotEmpty && (viCombiningClass[left.last] ?? 0) >= ccc;
      final joined = blocked
          ? null
          : viComposePairs['$base${String.fromCharCode(m)}'];
      if (joined == null) {
        left.add(m);
      } else {
        base = joined;
      }
    }
    out.write(base);
    out.write(String.fromCharCodes(left));
    i = j;
  }
  return out.toString();
}
