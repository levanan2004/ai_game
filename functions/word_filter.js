'use strict';
// Nhất's bad-word list (tu_cam.json, synced from assets/data by
// sync-economy.js), matched the way her checker _kiem_tra_tu_cam.py does.
// lib/logic/word_filter.dart is the same filter in the app; see there for the
// steps. Python's Unicode \b \w \W \d are spelled out for JS (u flag).
const fs = require('fs');
const path = require('path');

const SEP = new Set(['.', '*', '_', '-', "'", '`', '~', '|']);
const LEET = { 0: 'o', 1: 'i', 3: 'e', 4: 'a', '@': 'a', $: 's' };
const isL = (c) => /^\p{L}$/u.test(c);
const isAlnum = (c) => /^[\p{L}\p{N}]$/u.test(c);
const nfc = (s) => s.normalize('NFC');

function foldChar(c) {
  if (c === 'đ' || c === 'Đ') return 'd';
  const b = c.normalize('NFD').replace(/\p{Mn}/gu, '');
  return b ? Array.from(b)[0] : c;
}
const fold = (s) => Array.from(s).map(foldChar).join('');

const escape = (s) => s.replace(/[\\^$.|?*+()[\]{}/]/g, '\\$&');
const word = (s) => `(?<![\\p{L}\\p{N}])${escape(s).replace(/ /g, '\\s+')}(?![\\p{L}\\p{N}])`;

const W = '\\p{L}\\p{N}_';
const B = `(?:(?<![${W}])(?=[${W}])|(?<=[${W}])(?![${W}]))`;

/** Python `re` pattern -> JS pattern with the u flag. */
function pythonRegexForJs(p) {
  let out = '';
  let inClass = false;
  for (let i = 0; i < p.length; i++) {
    const c = p[i];
    if (c === '\\' && i + 1 < p.length) {
      const n = p[++i];
      if (n === 'b' && !inClass) out += B;
      else if (n === 'w') out += inClass ? W : `[${W}]`;
      else if (n === 'W' && !inClass) out += `[^${W}]`;
      else if (n === 'd') out += '\\p{Nd}';
      else out += `\\${n}`;
      continue;
    }
    if (c === '[' && !inClass) inClass = true;
    else if (c === ']' && inClass) inClass = false;
    out += c;
  }
  return out;
}

/** Steps 2, 3 and 5 of the checker, one array entry per code point. */
function normalize(text) {
  const chars = Array.from(text);
  const kept = [];
  for (let k = 0; k < chars.length; k++) {
    const c = chars[k];
    if (SEP.has(c) && kept.length && isL(kept[kept.length - 1])) {
      let j = k + 1;
      while (j < chars.length && SEP.has(chars[j])) j++;
      if (j < chars.length && isL(chars[j])) continue;
    }
    kept.push(c);
  }
  const toks = [];
  let cur = [];
  for (const c of kept) {
    if (isAlnum(c) || c === '@' || c === '$') {
      cur.push(c);
    } else {
      if (cur.length) toks.push([true, cur]);
      cur = [];
      toks.push([false, [c]]);
    }
  }
  if (cur.length) toks.push([true, cur]);
  const single = (t) => t[0] && t[1].length === 1 && isL(t[1][0]);
  const res = [];
  let k = 0;
  while (k < toks.length) {
    const t = toks[k];
    if (single(t)) {
      const run = [t];
      let j = k + 1;
      while (j + 1 < toks.length && !toks[j][0] && single(toks[j + 1])) {
        run.push(toks[j + 1]);
        j += 2;
      }
      if (run.length >= 2) {
        for (const r of run) res.push(...r[1]);
        k = j;
        continue;
      }
    }
    res.push(...t[1]);
    k++;
  }
  const wordy = (c) => isAlnum(c) || c === '_' || c === '@' || c === '$';
  let p = 0;
  while (p < res.length) {
    if (!wordy(res[p])) { p++; continue; }
    let q = p;
    while (q < res.length && wordy(res[q])) q++;
    if (res[p] !== '@' && res.slice(p, q).some(isL)) {
      for (let i = p; i < q; i++) res[i] = LEET[res[i]] || res[i];
    }
    p = q;
  }
  return res;
}

/** Step 4: three or more of the same letter count as one. */
function collapseRepeats(s) {
  const out = [];
  let p = 0;
  while (p < s.length) {
    let q = p;
    while (q < s.length && s[q] === s[p]) q++;
    if (isL(s[p]) && q - p >= 3) out.push(s[p]);
    else out.push(...s.slice(p, q));
    p = q;
  }
  return out;
}

// Names a shop may not take as a word (tu_cam_ghi_chu mục 6).
const STAFF_NAMES = ['admin', 'mod', 'gm', 'bqt', 'quản trị viên', 'tiệm hoa sớm mai', 'đội tiệm'];
const STAFF = STAFF_NAMES.map((w) => new RegExp(word(fold(w)), 'u'));

function createFilter(json) {
  const rules = [];
  for (const g of json.nhom || []) {
    for (const m of g.muc || []) {
      const block = m.hanh_dong === 'chặn';
      if (m.kieu === 'tu') {
        for (const v of [m.mau, ...(m.bien_the || [])]) {
          const vv = nfc(v.toLowerCase()).replace(/\*/g, '').replace(/(\p{L})\1{2,}/gu, '$1');
          const where = m.chi_khop_co_dau ? 'accented' : 'folded';
          const src = m.chi_khop_co_dau ? vv : fold(vv);
          rules.push({ id: m.id, block, where, rx: new RegExp(word(src), 'gu') });
        }
      } else {
        const where = m.kieu === 'regex_goc' ? 'original' : 'folded';
        rules.push({ id: m.id, block, where, rx: new RegExp(pythonRegexForJs(m.mau), 'gu') });
      }
    }
  }
  const white = (json.danh_sach_trang || []).map(nfc).map((w) => ({
    accented: new RegExp(word(w), 'gu'),
    folded: new RegExp(word(fold(w)), 'gu'),
  }));

  /** Every rule that matches `raw` ({ id, block }), empty when clean. */
  function hits(raw) {
    const original = nfc(raw).toLowerCase();
    const s = collapseRepeats(normalize(original)).join('');
    const f = fold(s);
    const guard = { accented: new Set(), folded: new Set() };
    for (const w of white) {
      for (const [key, src] of [['accented', s], ['folded', f]]) {
        for (const m of src.matchAll(w[key])) {
          for (let i = m.index; i < m.index + m[0].length; i++) guard[key].add(i);
        }
      }
    }
    const out = [];
    for (const r of rules) {
      if (r.where === 'original') {
        r.rx.lastIndex = 0;
        if (r.rx.test(original)) out.push({ id: r.id, block: r.block });
        r.rx.lastIndex = 0;
        continue;
      }
      const src = r.where === 'accented' ? s : f;
      for (const m of src.matchAll(r.rx)) {
        const end = m.index + m[0].length;
        if (end <= m.index) continue;
        let safe = false;
        for (let i = m.index; i < end && !safe; i++) safe = guard[r.where].has(i);
        if (!safe) { out.push({ id: r.id, block: r.block }); break; }
      }
    }
    return out;
  }

  /** A shop name is refused on any hit (block or mask) or a staff name. */
  function allowsShopName(name) {
    if (hits(name).length) return false;
    const f = fold(collapseRepeats(normalize(nfc(name).toLowerCase())).join(''));
    return !STAFF.some((rx) => rx.test(f));
  }

  return { hits, allowsShopName };
}

let shared;
let sharedList;
/** functions/tu_cam.json (or the app's copy in a checkout), parsed. */
function defaultWordList() {
  if (!sharedList) {
    const here = path.join(__dirname, 'tu_cam.json');
    const file = fs.existsSync(here) ? here : path.join(__dirname, '..', 'assets', 'data', 'tu_cam.json');
    sharedList = JSON.parse(fs.readFileSync(file, 'utf8'));
  }
  return sharedList;
}

/** The filter over defaultWordList(). */
function defaultFilter() {
  if (!shared) shared = createFilter(defaultWordList());
  return shared;
}

module.exports = { createFilter, defaultFilter, defaultWordList, pythonRegexForJs, fold, STAFF_NAMES };
