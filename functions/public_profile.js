'use strict';
// public_profiles/{uid}: the few public facts the profile card (spec 6)
// shows that only the save knows. Written by the server only (rules: signed-in
// players read, nobody writes), from the save it already reads: on a world
// chat message (world_chat.js) and on a Mị lực board row (verifyCharmEntry).
//
//   day        the shop's game day ("Ngày thứ {n}")
//   updatedAt
//
// Not here yet (no data or rule to build them from, see the task report):
// rating (the Đánh giá board does not exist), the 3 rarest pots (economy.json
// has no pot rarity), VIP (task 6).

function publicProfile(progress, now) {
  const day = Math.max(0, Math.floor(Number(progress && progress.day) || 0));
  return { day, updatedAt: now };
}

module.exports = { publicProfile };
