'use strict';
// node --test verify.test.js  (from functions/). The default mode is fix.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { loadEconomy } = require('./charm');
const { modeFromEnv, checkEntry } = require('./verify');
const { FakeFirestore } = require('./fake_firestore');

const economyPath = fs.existsSync(path.join(__dirname, 'economy.json'))
  ? path.join(__dirname, 'economy.json')
  : path.join(__dirname, '..', 'assets', 'data', 'economy.json');
const eco = loadEconomy(JSON.parse(fs.readFileSync(economyPath, 'utf8')));
const NOW = new Date('2026-10-20T01:00:00Z');
const OLD = new Date('2026-10-15T01:00:00Z');

const save = (id, stage, worn) => ({ petCharm: id, pets: [{ id, stage, ...(worn ? { worn } : {}) }] });

function setup(entry, progress) {
  const db = new FakeFirestore();
  db.seed('charm_board/season-1/entries/u', { uid: 'u', displayName: 'U', petId: 'kim_long', stage: 2, worn: {}, reachedAt: OLD, ...entry });
  if (progress !== undefined) db.seed('users/u', { progress });
  const warnings = [];
  const logger = { warn: (m, d) => warnings.push([m, d]), info() {} };
  const run = (mode) => checkEntry({
    db, eco, period: 'season-1', uid: 'u', entry: db.read('charm_board/season-1/entries/u'),
    ref: db.doc('charm_board/season-1/entries/u'), mode, now: NOW, logger,
  });
  return { db, warnings, run, row: () => db.read('charm_board/season-1/entries/u') };
}

test('the mode is fix unless CHARM_MODE=log', () => {
  assert.equal(modeFromEnv({}), 'fix');
  assert.equal(modeFromEnv(undefined), 'fix');
  assert.equal(modeFromEnv({ CHARM_MODE: 'fix' }), 'fix');
  assert.equal(modeFromEnv({ CHARM_MODE: 'anything' }), 'fix');
  assert.equal(modeFromEnv({ CHARM_MODE: 'log' }), 'log');
});

test('fix: a row above the save is overwritten with the recomputed value and logged', async () => {
  const s = setup({ charm: 500 }, save('kim_long', 2, { neck: 'no_co_vai' }));
  assert.equal(await s.run(modeFromEnv({})), 'lower');
  assert.equal(s.row().charm, 305);
  assert.deepEqual(s.row().worn, { neck: 'no_co_vai' });
  assert.deepEqual(s.row().reachedAt, NOW);
  assert.equal(s.warnings.length, 1);
  assert.deepEqual(
    { stored: s.warnings[0][1].stored, recomputed: s.warnings[0][1].recomputed, mode: s.warnings[0][1].mode },
    { stored: 500, recomputed: 305, mode: 'fix' });
});

test('fix: the second pass over the fixed row is ok (no loop)', async () => {
  const s = setup({ charm: 500 }, save('kim_long', 2));
  await s.run('fix');
  assert.equal(await s.run('fix'), 'ok');
  assert.equal(s.warnings.length, 1);
});

test('fix: no pet, under 20 or an unreadable save deletes the row, each one logged', async () => {
  for (const progress of [save('ca_chep', 0), { petCharm: null, pets: [] }, null, undefined]) {
    const s = setup({ charm: 80 }, progress);
    assert.equal(await s.run('fix'), 'remove');
    assert.equal(s.row(), undefined);
    assert.equal(s.warnings.length, 1);
  }
});

test('log: mismatches are logged and nothing changes', async () => {
  const s = setup({ charm: 500 }, save('kim_long', 2));
  assert.equal(await s.run('log'), 'lower');
  assert.equal(s.row().charm, 500);
  assert.equal(s.warnings[0][1].mode, 'log');
  const gone = setup({ charm: 80 }, null);
  assert.equal(await gone.run('log'), 'remove');
  assert.ok(gone.row());
});

test('a row below what the save backs is never raised (cloud save can lag)', async () => {
  const s = setup({ charm: 150 }, save('kim_long', 2));
  assert.equal(await s.run('fix'), 'ok');
  assert.equal(s.row().charm, 150);
  assert.equal(s.warnings.length, 0);
});