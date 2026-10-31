'use strict';
// Copies the game's economy.json next to the function so the server uses the
// same pets, stage multipliers and item tiers as the app, and Nhất's word list
// tu_cam.json for the shop-name filter (word_filter.js). Run before deploy
// (firebase.json predeploy does it: see README). nguong_chong_hack.json is
// Hà Phương's anti-cheat thresholds (anti_cheat.js); not bundled in the app.
const fs = require('fs');
const path = require('path');
for (const name of ['economy.json', 'tu_cam.json', 'nguong_chong_hack.json']) {
  const from = path.join(__dirname, '..', 'assets', 'data', name);
  fs.copyFileSync(from, path.join(__dirname, name));
  console.log(name, 'synced from', from);
}
