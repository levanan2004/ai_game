import '../data/pha_le_rules.dart';

/// In-game exchange: Pha lê → xu (web and Android when a coin purchase is
/// short). Rate from economy.json `phaLeExchange` (Pha lê per pack, xu per pack).
int get phaLePerMillionXu => PhaLeRules.current.exchangePhaLe;
int get xuPerPhaLeExchangePack => PhaLeRules.current.exchangeCoins;

/// How many 1M-xu packs cover [missingXu] (round up).
int exchangePacksForMissingXu(int missingXu) {
  if (missingXu <= 0) return 0;
  return (missingXu + xuPerPhaLeExchangePack - 1) ~/ xuPerPhaLeExchangePack;
}

int phaLeCostForMissingXu(int missingXu) =>
    exchangePacksForMissingXu(missingXu) * phaLePerMillionXu;

int xuFromExchangePacks(int packs) => packs * xuPerPhaLeExchangePack;
