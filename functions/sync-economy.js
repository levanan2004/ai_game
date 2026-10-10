'use strict';
// Copies the game's economy.json next to the function so the server uses the
// same pets, stage multipliers and item tiers as the app. Run before deploy
// (firebase.json predeploy does it: see README).
const fs = require('fs');
const path = require('path');
const from = path.join(__dirname, '..', 'assets', 'data', 'economy.json');
fs.copyFileSync(from, path.join(__dirname, 'economy.json'));
console.log('economy.json synced from', from);
