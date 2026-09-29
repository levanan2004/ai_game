import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';
import 'terms_consent.dart';

/// JSON save/load for [GameState] and the terms consent.
///
/// [persistent] uses [SharedPreferences], which stores the strings in the
/// browser's localStorage on web and in the platform store on mobile.
class ProgressStore {
  ProgressStore({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
  }) : _read = read,
       _write = write;

  static const storageKey = 'ai_game.progress';

  /// Kept apart from the progress so a new game never clears it.
  static const termsKey = 'tiemhoa.terms';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;

  /// In-memory store. [backing] is shared so a second store can restore it.
  factory ProgressStore.memory([Map<String, String>? backing]) {
    final data = backing ?? <String, String>{};
    return ProgressStore(
      read: (key) async => data[key],
      write: (key, value) async {
        data[key] = value;
      },
    );
  }

  static Future<ProgressStore> persistent() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore(
      read: (key) async => prefs.getString(key),
      write: (key, value) async {
        await prefs.setString(key, value);
      },
    );
  }

  /// Null when nothing valid is saved (the caller starts a new game).
  Future<GameState?> load() async => GameState.decode(await _read(storageKey));

  Future<void> save(GameState state) => _write(storageKey, state.encode());

  /// Null when the player has never agreed (or storage was cleared).
  Future<TermsConsent?> loadTerms() async =>
      TermsConsent.decode(await _read(termsKey));

  Future<void> saveTerms(TermsConsent terms) =>
      _write(termsKey, terms.encode());
}
