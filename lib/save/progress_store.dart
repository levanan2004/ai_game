import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// JSON save/load for [GameState].
///
/// [persistent] uses [SharedPreferences], which stores the string in the
/// browser's localStorage on web and in the platform store on mobile.
class ProgressStore {
  ProgressStore({
    required Future<String?> Function() read,
    required Future<void> Function(String value) write,
  }) : _read = read,
       _write = write;

  static const storageKey = 'ai_game.progress';

  final Future<String?> Function() _read;
  final Future<void> Function(String value) _write;

  /// In-memory store. [backing] is shared so a second store can restore it.
  factory ProgressStore.memory([Map<String, String>? backing]) {
    final data = backing ?? <String, String>{};
    return ProgressStore(
      read: () async => data[storageKey],
      write: (value) async {
        data[storageKey] = value;
      },
    );
  }

  static Future<ProgressStore> persistent() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore(
      read: () async => prefs.getString(storageKey),
      write: (value) async {
        await prefs.setString(storageKey, value);
      },
    );
  }

  /// Null when nothing valid is saved (the caller starts a new game).
  Future<GameState?> load() async => GameState.decode(await _read());

  Future<void> save(GameState state) => _write(state.encode());
}
