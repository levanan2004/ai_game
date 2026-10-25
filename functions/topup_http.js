'use strict';
// The HTTP layer of the top-up, with everything it needs passed in so it can be
// tested with a fake request/response and a fake Firestore. index.js binds it
// to real secrets, the Admin SDK and Cloud Functions.

const topup = require('./topup');
const sepay = require('./sepay');

const send = (res, code, body) => res.status(code).json(body);

/** Money-in calls: always 200 once the sender is proven, 401 before. */
function paymentHandler({ kind, db, eco, getSecrets, now, cfg, logger }) {
  return async (req, res) => {
    if (req.method !== 'POST') return send(res, 405, { error: 'method' });
    const headers = req.headers || {};
    const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(req.body || {});
    const secrets = getSecrets();
    const nowDate = now();
    const ok = kind === 'ipn'
      ? sepay.verifyIpn(headers, secrets.secretKey)
      : sepay.verifyBankWebhook(headers, raw, {
        apiKey: secrets.apiKey, hmacSecret: secrets.secretKey,
        nowSec: Math.floor(nowDate.getTime() / 1000),
      });
    if (!ok) {
      logger.warn('sepay rejected', { kind, ip: headers['x-forwarded-for'] || null });
      return send(res, 401, { success: false, error: 'unauthorized' });
    }
    const prefix = (cfg && cfg.codePrefix) || undefined;
    const read = kind === 'ipn' ? sepay.readIpn(req.body, prefix) : sepay.readBankWebhook(req.body, prefix);
    // Every authenticated notification is logged, whatever happens next.
    logger.info('sepay notification', { kind, read: read.kind, event: read.event || null });
    if (read.kind === 'ignore') return send(res, 200, { success: true, ignored: true });
    if (read.kind === 'void') {
      logger.warn('sepay VOID: the admin must look at this order', read.event);
      return send(res, 200, { success: true, void: true });
    }
    try {
      const result = await topup.handlePayment({ db, eco, event: read.event, now: nowDate, cfg, logger });
      return send(res, 200, { success: true, result });
    } catch (e) {
      if (e instanceof topup.TopupError) {
        logger.warn('sepay bad event', { code: e.code, event: read.event });
        return send(res, 200, { success: true, ignored: true }); // retrying cannot fix it
      }
      logger.error('sepay payment failed', { message: String(e && e.message) });
      return send(res, 500, { success: false }); // SePay retries; the txn doc keeps it safe
    }
  };
}

/** Player calls: Bearer Firebase ID token -> uid. [verify] returns the uid or throws. */
function playerHandler({ action, db, eco, verify, now, cfg, bank, isOpen, logger }) {
  return async (req, res) => {
    const m = /^Bearer (.+)$/.exec(String((req.headers || {}).authorization || ''));
    let uid;
    try {
      if (!m) throw new Error('no token');
      uid = await verify(m[1]);
    } catch (_) {
      return send(res, 401, { error: 'unauthorized' });
    }
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const orderId = String(req.query && req.query.orderId ? req.query.orderId : body.orderId || '');
    try {
      const t = now();
      if (action === 'create') {
        if (req.method !== 'POST') return send(res, 405, { error: 'method' });
        const order = await topup.createOrder({
          db, eco, uid, packId: String(body.packId || ''), bank, now: t, cfg, open: await isOpen(),
        });
        return send(res, 200, order);
      }
      if (!orderId) return send(res, 400, { error: 'bad_order' });
      if (action === 'status') return send(res, 200, await topup.orderStatus({ db, uid, orderId, now: t }));
      return send(res, 200, await topup.cancelOrder({ db, uid, orderId, now: t }));
    } catch (e) {
      if (e instanceof topup.TopupError) return send(res, e.http, { error: e.code });
      logger.error('phale call failed', { action, message: String(e && e.message) });
      return send(res, 500, { error: 'server' });
    }
  };
}

module.exports = { paymentHandler, playerHandler };