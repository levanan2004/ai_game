import 'package:web/web.dart';

const _storageKey = 'ai_game.tab';

/// Stable for this tab, including a reload. A new tab gets its own id.
String currentTabId() {
  final existing = window.sessionStorage.getItem(_storageKey);
  if (existing != null && existing.length >= 8 && existing.length <= 80) {
    return existing;
  }
  final id = 'tab${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
  window.sessionStorage.setItem(_storageKey, id);
  return id;
}
