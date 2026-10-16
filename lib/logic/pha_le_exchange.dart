/// In-game exchange: Pha lê → xu (web and Android when a coin purchase is short).
const phaLePerMillionXu = 100;
const xuPerPhaLeExchangePack = 1000000;

/// How many 1M-xu packs cover [missingXu] (round up).
int exchangePacksForMissingXu(int missingXu) {
  if (missingXu <= 0) return 0;
  return (missingXu + xuPerPhaLeExchangePack - 1) ~/ xuPerPhaLeExchangePack;
}

int phaLeCostForMissingXu(int missingXu) =>
    exchangePacksForMissingXu(missingXu) * phaLePerMillionXu;

int xuFromExchangePacks(int packs) => packs * xuPerPhaLeExchangePack;
