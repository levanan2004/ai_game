'use strict';
// node --test word_filter.test.js  (from functions/). The sentences are Nhất's
// (_kiem_tra_tu_cam.py), shared with test/logic/word_filter_test.dart.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { createFilter, defaultFilter, pythonRegexForJs, fold } = require('./word_filter');
const { checkEntry } = require('./verify');
const { FakeFirestore } = require('./fake_firestore');

const cases = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'test', 'fixtures', 'tu_cam_cases.json'), 'utf8'));
const f = defaultFilter();

test('Nhất\'s clean sentences hit nothing', () => {
  for (const t of cases.pass) assert.deepEqual(f.hits(t), [], t);
});

test('reminders only hit mask (che) entries', () => {
  for (const t of cases.mask) {
    const h = f.hits(t);
    assert.ok(h.length > 0, t);
    assert.ok(h.every((x) => !x.block), t);
  }
});

test('bad sentences are caught', () => {
  for (const t of cases.hit) assert.ok(f.hits(t).length > 0, t);
});

test('accents matter: đồ ngu is caught, đồ ngủ is not; decomposed input is composed first', () => {
  assert.ok(f.hits('đồ ngu').length > 0);
  assert.deepEqual(f.hits('đồ ngủ'), []);
  assert.ok(f.hits('đồ ngu'.normalize('NFD')).length > 0);
  assert.equal(fold('Đẹp ệ'), 'dep e');
});

test('shop names: any hit (block or mask) or a staff name is refused', () => {
  for (const name of ['Tiệm Hoa Nhà Mây', 'Hoa Nắng Sớm 100000', 'Góc Hoa Nhỏ', 'Hoa Ơi', 'Vườn Hoa Nhà Bé 7']) {
    assert.ok(f.allowsShopName(name), name);
  }
  for (const name of ['Tiệm vcl', 'sexy ghê', 'zalo', 'Admin', 'Tiệm Hoa Sớm Mai', 'tiem hoa som mai', 'BQT Hoa', 'Đội Tiệm', 'Quản trị viên']) {
    assert.ok(!f.allowsShopName(name), name);
  }
  // "admin ơi" is fine in chat, not as a name.
  assert.deepEqual(f.hits('admin ơi cho mình hỏi'), []);
  assert.ok(!f.allowsShopName('admin ơi'));
});

test('Python \\b \\w \\W \\d become Unicode classes', () => {
  assert.equal(pythonRegexForJs('\\d'), '\\p{Nd}');
  assert.equal(pythonRegexForJs('[\\w@]'), '[\\p{L}\\p{N}_@]');
  assert.ok(new RegExp(pythonRegexForJs('\\bab\\b'), 'u').test('ơ ab'));
  assert.ok(!new RegExp(pythonRegexForJs('\\bab\\b'), 'u').test('ơab'));
});

test('an empty list lets every text through', () => {
  const none = createFilter({ nhom: [], danh_sach_trang: [] });
  assert.deepEqual(none.hits('vcl'), []);
});

test('verify: a board row with a refused name is deleted in fix mode, kept in log mode', async () => {
  for (const mode of ['fix', 'log']) {
    const db = new FakeFirestore();
    db.seed('charm_board/season-1/entries/u', { uid: 'u', displayName: 'Tiệm vcl', charm: 80, petId: 'kim_long', stage: 2, worn: {} });
    const warnings = [];
    const verdict = await checkEntry({
      db, eco: null, period: 'season-1', uid: 'u', entry: db.read('charm_board/season-1/entries/u'),
      ref: db.doc('charm_board/season-1/entries/u'), mode, now: new Date(),
      logger: { warn: (m, d) => warnings.push([m, d]), info() {} },
    });
    assert.equal(verdict, 'name');
    assert.equal(warnings[0][0], 'charm board name refused');
    assert.equal(db.read('charm_board/season-1/entries/u') === undefined, mode === 'fix');
  }
});
