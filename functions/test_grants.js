'use strict';
// Test helper: gives [uid] a server record (charm.js serverOwned) of every
// pet, worn pet item and pot in [progress], as if bought with Pha lê.
function grantFromSave(db, uid, progress) {
  const p = progress || {};
  const items = {};
  let n = 0;
  const buy = (kind, id) => db.seed(`wallets/${uid}/ledger/t${n++}`, { type: 'buy', kind, id, phaLe: -1 });
  for (const pet of Array.isArray(p.pets) ? p.pets : []) {
    if (!pet) continue;
    buy('pet', pet.id);
    for (const id of Object.values(pet.worn || {})) items[id] = { bought: 1, sold: 0 };
  }
  for (const id of Object.keys(p.potCounts || {})) buy('pot', id);
  db.seed(`wallets/${uid}`, { items });
}
module.exports = { grantFromSave };
