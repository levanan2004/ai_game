'use strict';
// A small in-memory stand-in for the Admin SDK Firestore calls payout.js uses:
// doc().get/set/create/update/delete, collection().get/where, getAll.
class Snap {
  constructor(ref, data) { this.ref = ref; this.id = ref.id; this._d = data; this.exists = data !== undefined; }
  data() { return this._d === undefined ? undefined : structuredClone(this._d); }
}

class FakeFirestore {
  constructor() { this.docs = new Map(); this.failCreate = new Set(); this.log = []; this._tx = Promise.resolve(); }
  seed(path, data) { this.docs.set(path, structuredClone(data)); return this; }
  read(path) { return this.docs.get(path); }
  doc(path) {
    const db = this;
    const id = path.split('/').pop();
    return {
      path, id,
      async get() { return new Snap(this, db.docs.get(path)); },
      async set(data, opts) {
        const cur = db.docs.get(path);
        db.docs.set(path, opts && opts.merge && cur ? { ...cur, ...structuredClone(data) } : structuredClone(data));
        db.log.push(['set', path]);
      },
      async create(data) {
        if (db.failCreate.has(path)) throw Object.assign(new Error('boom'), { code: 14 });
        if (db.docs.has(path)) throw Object.assign(new Error('exists'), { code: 6 });
        db.docs.set(path, structuredClone(data));
        db.log.push(['create', path]);
      },
      async update(data) {
        if (!db.docs.has(path)) throw Object.assign(new Error('missing'), { code: 5 });
        db.docs.set(path, { ...db.docs.get(path), ...structuredClone(data) });
        db.log.push(['update', path]);
      },
      async delete() { db.docs.delete(path); db.log.push(['delete', path]); },
    };
  }
  collection(path) {
    const db = this;
    const list = (filters) => {
      const out = [];
      for (const [p, d] of db.docs) {
        if (!p.startsWith(`${path}/`)) continue;
        if (p.slice(path.length + 1).includes('/')) continue;
        if (filters.every(([f, op, v]) => op === '<=' ? d[f] instanceof Date && d[f] <= v : d[f] === v)) {
          out.push(new Snap(db.doc(p), d));
        }
      }
      return out;
    };
    const q = (filters) => ({
      where: (f, op, v) => q([...filters, [f, op, v]]),
      async get() { const docs = list(filters); return { docs, size: docs.length }; },
    });
    return q([]);
  }
  /**
   * Admin SDK runTransaction: reads see the store, writes are buffered and
   * applied together when [fn] returns. Transactions run one after the other
   * (a mutex), which is what Firestore's retry-on-contention amounts to, so a
   * test of two parallel calls checks the logic, not the database.
   */
  async runTransaction(fn) {
    const run = this._tx.then(async () => {
      const ops = [];
      const staged = new Map();
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, data, opts) => { ops.push(['set', ref, data, opts]); return tx; },
        create: (ref, data) => {
          if (this.docs.has(ref.path) || staged.has(ref.path)) {
            throw Object.assign(new Error('exists'), { code: 6 });
          }
          staged.set(ref.path, true);
          ops.push(['create', ref, data]);
          return tx;
        },
        update: (ref, data) => { ops.push(['update', ref, data]); return tx; },
        delete: (ref) => { ops.push(['delete', ref]); return tx; },
      };
      const out = await fn(tx);
      // Commit is all or nothing, like Firestore: undo everything on a failure.
      const backup = new Map(this.docs);
      try {
        for (const [kind, ref, data, opts] of ops) {
          if (kind === 'set') await ref.set(data, opts);
          else if (kind === 'create') await ref.create(data);
          else if (kind === 'update') await ref.update(data);
          else await ref.delete();
        }
      } catch (e) {
        this.docs = backup;
        throw e;
      }
      return out;
    });
    this._tx = run.catch(() => {});
    return run;
  }
  async getAll(...refs) { return refs.map((r) => new Snap(r, this.docs.get(r.path))); }
}

module.exports = { FakeFirestore };