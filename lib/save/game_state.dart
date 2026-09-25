import 'dart:convert';

/// Persisted placeholder progress.
///
/// [money] and [day] are empty slots for an economy that is not decided yet.
/// They are not prices, costs, or balance numbers. [tapCount] only proves that
/// a tap can be saved.
class GameState {
  const GameState({this.money = 0, this.day = 0, this.tapCount = 0});

  static const initial = GameState();

  /// Placeholder. Not a currency amount.
  final int money;

  /// Placeholder. Not a simulated calendar.
  final int day;

  /// Placeholder interaction count. Not a game mechanic.
  final int tapCount;

  Map<String, int> toJson() => {
    'money': money,
    'day': day,
    'tapCount': tapCount,
  };

  String encode() => jsonEncode(toJson());

  /// Missing or corrupt [raw] becomes [initial].
  ///
  /// A JSON object may omit a field (that field stays 0). A present field that
  /// is not an int makes the whole payload corrupt.
  static GameState decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return initial;
    }
    try {
      return tryParse(jsonDecode(raw)) ?? initial;
    } on FormatException {
      return initial;
    }
  }

  static GameState? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final money = _optionalInt(value, 'money');
    final day = _optionalInt(value, 'day');
    final tapCount = _optionalInt(value, 'tapCount');
    if (money == null || day == null || tapCount == null) {
      return null;
    }
    return GameState(money: money, day: day, tapCount: tapCount);
  }

  GameState copyWith({int? money, int? day, int? tapCount}) {
    return GameState(
      money: money ?? this.money,
      day: day ?? this.day,
      tapCount: tapCount ?? this.tapCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameState &&
        other.money == money &&
        other.day == day &&
        other.tapCount == tapCount;
  }

  @override
  int get hashCode => Object.hash(money, day, tapCount);

  @override
  String toString() =>
      'GameState(money: $money, day: $day, tapCount: $tapCount)';

  static int? _optionalInt(Map<dynamic, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      return 0;
    }
    final value = json[key];
    return value is int ? value : null;
  }
}
