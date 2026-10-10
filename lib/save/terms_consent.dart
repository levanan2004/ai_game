import 'dart:convert';

/// Bump when /terms or /privacy change enough to ask everyone again
/// (man_dieu_khoan_v1.md: termsVersion = 1, 29/9/2026).
const termsVersion = 1;

/// What the player agreed to on the terms screen. Stored on its own
/// (`tiemhoa.terms`), outside [GameState], so a new game or a cloud pull
/// never touches it.
class TermsConsent {
  const TermsConsent({
    required this.version,
    required this.acceptedAt,
    this.age16Confirmed = true,
  });

  final int version;

  /// Local time of the tap.
  final DateTime acceptedAt;
  final bool age16Confirmed;

  bool get isCurrent => version == termsVersion;

  /// "29/09/2026" in the device's time zone.
  String get acceptedDate {
    final d = acceptedAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String encode() => jsonEncode({
    'version': version,
    'acceptedAt': isoWithOffset(acceptedAt),
    'age16Confirmed': age16Confirmed,
  });

  /// Null when nothing valid is stored (the player is asked again).
  static TermsConsent? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final version = j['version'];
      final at = DateTime.tryParse('${j['acceptedAt']}');
      if (version is! int || at == null) return null;
      return TermsConsent(
        version: version,
        acceptedAt: at.toLocal(),
        age16Confirmed: j['age16Confirmed'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// ISO 8601 with the local offset, e.g. "2026-09-29T15:47:00+07:00".
/// [DateTime.toIso8601String] drops the offset for local times.
String isoWithOffset(DateTime t) {
  final local = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final mins = off.inMinutes.abs();
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$sign${two(mins ~/ 60)}:${two(mins % 60)}';
}
