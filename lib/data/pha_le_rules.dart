/// Free Pha lê and the Pha lê → xu rate, from `assets/data/economy.json`
/// (`phaLeFree`, `phaLeExchange`; Hà Phương). functions/wallet.js reads the
/// same keys when it checks an ad credit or an exchange.
library;

class PhaLeRules {
  const PhaLeRules({
    required this.adReward,
    required this.adMaxPerDay,
    required this.exchangePhaLe,
    required this.exchangeCoins,
  });

  /// `phaLeFree.adReward`: Pha lê for one rewarded ad watched to the end.
  final int adReward;

  /// `phaLeFree.adMaxPerDay`: rewarded ads of each kind per day.
  final int adMaxPerDay;

  /// `phaLeExchange.phaLe`: Pha lê for one exchange pack ...
  final int exchangePhaLe;

  /// ... which gives `phaLeExchange.coins` xu.
  final int exchangeCoins;

  /// Nothing until the app (or a test's game data) loads economy.json;
  /// GameData sets it from the file, like RarityRules.current.
  static PhaLeRules current = const PhaLeRules(
    adReward: 0,
    adMaxPerDay: 0,
    exchangePhaLe: 0,
    exchangeCoins: 0,
  );

  /// Both blocks are required: a missing or non-positive number throws.
  factory PhaLeRules.fromJson(Object? free, Object? exchange) {
    int n(Object? block, String name, String key) {
      final v = block is Map ? block[key] : null;
      if (v is! num || v <= 0 || v != v.toInt()) {
        throw FormatException(
          'economy.json: "$name.$key" must be a positive whole number',
        );
      }
      return v.toInt();
    }

    return PhaLeRules(
      adReward: n(free, 'phaLeFree', 'adReward'),
      adMaxPerDay: n(free, 'phaLeFree', 'adMaxPerDay'),
      exchangePhaLe: n(exchange, 'phaLeExchange', 'phaLe'),
      exchangeCoins: n(exchange, 'phaLeExchange', 'coins'),
    );
  }
}
