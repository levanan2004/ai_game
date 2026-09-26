/// Live crowd counts. [online] were seen in the last minute or so.
/// [ever] is everyone who has opened the game at least once.
class CrowdCounts {
  const CrowdCounts({required this.online, required this.ever});

  final int online;
  final int ever;
}

/// Heartbeat plus the two counts. Null in tests and when Firebase is down.
abstract class PresenceClient {
  /// Stable id: the Google uid when signed in, otherwise a local guest id.
  Future<String> identity(String? uid);

  Future<void> pulse(String id);

  Future<CrowdCounts> counts();
}

/// "Đang online 3/12", or an ellipsis until the first count arrives.
String onlineCrowdLabel(int? online, int? ever) {
  if (online == null || ever == null) return 'Đang online …';
  return 'Đang online $online/$ever';
}
