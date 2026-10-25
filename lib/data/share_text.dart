/// Ảnh chia sẻ (spec_khung_chia_se.md): words from assets/data/chia_se.json
/// (Nhất). No invite codes yet, so nothing with {maMoi} is ever shown.
library;

import 'dart:convert';

/// What the share image shows (spec §5): (A) a bouquet, (B) the shop.
enum ShareKind { bouquet, shop }

/// Link on the card, in the QR and in the caption (spec "Chữ chốt": the
/// game's /tai-game page, no `?ma=` yet).
const shareLink = 'https://tiemhoasommai.com/tai-game';

/// [shareLink] as printed on the card.
const shareLinkLabel = 'tiemhoasommai.com/tai-game';

/// Card captions fixed in spec "Chữ chốt (Nhất, 25/10)"; not in
/// chia_se.json.
const shareCardCaptions = {
  ShareKind.bouquet: [
    'Bó hoa này gói bằng cả tấm lòng',
    'Gửi bạn một chút nắng sớm',
    'Hoa tươi mới gói, tặng bạn nè',
    'Mỗi bó hoa là một lời thương',
  ],
  ShareKind.shop: [
    'Tiệm nhỏ của mình, mời bạn ghé chơi',
    'Góc nhỏ thơm hương hoa mỗi sáng',
    'Mở cửa đón nắng, đón bạn',
  ],
};

class ShareText {
  ShareText._(this._j);

  static final empty = ShareText._(const {});

  static const asset = 'assets/data/chia_se.json';

  final Map<String, dynamic> _j;

  factory ShareText.parse(String? json) {
    final j = json == null ? null : jsonDecode(json);
    return j is Map<String, dynamic> ? ShareText._(j) : empty;
  }

  /// `group.key`, e.g. `button.share`; the key itself when missing.
  String ui(String key, [Map<String, String> args = const {}]) {
    final dot = key.indexOf('.');
    final g = _j[key.substring(0, dot)];
    final v = g is Map ? g[key.substring(dot + 1)] : null;
    return _fill(v is String ? v : key, args);
  }

  /// Share-sheet messages for [kind] with the tokens filled in. Lines that
  /// need an invite code are left out (chia_se.json notes).
  List<String> captions(ShareKind kind, {required String tenTiem}) {
    final list =
        _j[kind == ShareKind.bouquet ? 'caption.bouquet' : 'caption.shop'];
    return [
      for (final c in list is List ? list : const [])
        if (c is String && !c.contains('{maMoi}'))
          _fill(c, {'tenTiem': tenTiem, 'link': shareLink}),
    ];
  }

  List<String> get hashtags => [
    for (final h in _j['hashtags'] is List ? _j['hashtags'] as List : const [])
      if (h is String) h,
  ];

  static String _fill(String s, Map<String, String> args) {
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
    return s;
  }
}
