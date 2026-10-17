'use strict';
// Numbers that still live in the app's Dart code, not in economy.json. The
// server needs them to check a Pha lê credit or spend. KEEP IN SYNC with:
//   lib/logic/login_rewards.dart  defaultLoginRewards (used while
//                                 config/loginRewards is missing or old)
//   lib/logic/rewarded_ad.dart    rewardedPhaLeAmount, rewardedAdDailyCap
//   lib/logic/pha_le_exchange.dart phaLePerMillionXu, xuPerPhaLeExchangePack
// TODO(Hà Phương): move these into economy.json so both sides read one file.

const ph = (n) => ({ kind: 'phaLe', amount: n });
const gh = (n) => ({ kind: 'giotHoa', amount: n });

const defaultLoginRewards = {
  version: 2,
  newbie: [
    { items: [gh(10)] },
    { items: [{ kind: 'pot', id: 'dragon', amount: 1 }] },
    { items: [ph(50)] },
    { items: [{ kind: 'treat', id: 'banh_mat', amount: 4 }] },
    { items: [{ kind: 'coins', amount: 50000 }] },
    { items: [{ kind: 'pot', id: 'tiger', amount: 1 }, gh(20)] },
    { items: [ph(150), gh(25)] },
  ],
  weekly: [
    { items: [{ kind: 'treat', id: 'banh_mat', amount: 1 }] },
    { items: [{ kind: 'coins', amount: 30000 }] },
    { items: [ph(20)] },
    { items: [{ kind: 'treat', id: 'banh_mat', amount: 2 }] },
    { items: [{ kind: 'coins', amount: 50000 }] },
    { items: [gh(3)] },
    { items: [ph(30), gh(30)] },
  ],
  milestones: [
    { day: 14, rewards: { items: [ph(40)] } },
    { day: 30, rewards: { items: [ph(80)] } },
  ],
};

module.exports = {
  defaultLoginRewards,
  rewardedPhaLeAmount: 2,
  rewardedAdDailyCap: 5,
  phaLePerExchangePack: 100,
  xuPerExchangePack: 1000000,
};
