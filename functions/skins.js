'use strict';
// Pha lê price of one decoration skin, from economy.json `skins` (Hà Phương's
// block), the same rule as the app's SkinCatalog.priceOf: an id is
// `{slot_snake}_{theme}` (skinIds), the theme gives the tier (themeTiers),
// backgrounds × bigSlotMultiplier. 0 = not sold for Pha lê (free, xu, event).

function parse(block, id) {
  const slotIds = (block.skinIds && block.skinIds.slotIds) || {};
  const themes = block.themeTiers || {};
  for (const [slot, snake] of Object.entries(slotIds)) {
    if (!id.startsWith(`${snake}_`)) continue;
    const theme = id.slice(snake.length + 1);
    if (typeof themes[theme] === 'string') return { slot, theme, tier: themes[theme] };
  }
  return null;
}

function skinPrice(eco, id) {
  const block = (eco && eco.skins) || {};
  const skin = typeof id === 'string' ? parse(block, id) : null;
  if (!skin) return 0;
  const tier = (block.tiers || {})[skin.tier];
  if (!tier || tier.currency !== 'phaLe' || typeof tier.price !== 'number') return 0;
  const big = (block.bigSlotMultiplier || {})[skin.slot];
  const mult = (typeof big === 'number' ? big : 1) * groupMultiplier(block, skin.slot);
  return Math.max(0, Math.round(tier.price * mult));
}

// slotGroupPriceMultiplier of the group (`slots`) holding the slot:
// shop x2, pet room x1. 1 when not listed.
function groupMultiplier(block, slot) {
  const groups = block.slots || {};
  const mult = block.slotGroupPriceMultiplier || {};
  for (const [group, slots] of Object.entries(groups)) {
    if (Array.isArray(slots) && slots.includes(slot)) {
      return typeof mult[group] === 'number' ? mult[group] : 1;
    }
  }
  return 1;
}

// The pot-frame slot became the avatar-frame slot (khung_chau_{theme} ->
// khung_avatar_{theme}); a wallet that bought the old id owns the new one.
function legacySkinId(id) {
  return typeof id === 'string' && id.startsWith('khung_avatar_')
    ? `khung_chau_${id.slice('khung_avatar_'.length)}` : null;
}

module.exports = { skinPrice, legacySkinId };
