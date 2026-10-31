import 'dart:convert';

/// Nhất's Season Pass words (tiem-hoa-marketing/v14_season_pass/text_vi.json,
/// copied verbatim to assets/data/season_pass_strings.json). `{slot}`s are
/// filled by [get]; numbers go in already formatted.
class SeasonPassText {
  const SeasonPassText(this._keys);

  static const asset = 'assets/data/season_pass_strings.json';
  static const empty = SeasonPassText({});

  final Map<String, String> _keys;

  static SeasonPassText parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return SeasonPassText({
      for (final e in j.entries)
        if (e.value is String && !e.key.startsWith('_'))
          e.key: e.value as String,
    });
  }

  bool has(String key) => _keys.containsKey(key);

  /// [key] with each `{slot}` replaced; '' when missing.
  String get(String key, [Map<String, Object> vars = const {}]) {
    var t = _keys[key] ?? '';
    for (final v in vars.entries) {
      t = t.replaceAll('{${v.key}}', '${v.value}');
    }
    return t;
  }
}
