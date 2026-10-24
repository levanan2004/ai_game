'use strict';
// SePay request checks and payload readers. Pure functions: secrets are passed
// in (index.js reads them from Firebase Functions secrets), never imported.
//
// Two SePay products can call us, and both end in topup.handlePayment:
//  1. Cổng thanh toán IPN ("IPN URL, Content Type, Mã đơn vị, Secret Key" in
//     the dashboard). POST JSON, header `X-Secret-Key: <Secret Key>`,
//     notification_type ORDER_PAID. Function `sepayIpn`.
//  2. The older bank-transaction webhook (Webhooks menu). POST JSON, header
//     `Authorization: Apikey <API key>` or an HMAC-SHA256 signature
//     (`X-SePay-Signature: sha256=..` over `{X-SePay-Timestamp}.{raw body}`).
//     Function `sepayBankWebhook`.

const crypto = require('crypto');
const { findCode, DEFAULTS } = require('./topup');

/** Constant-time string compare (false for different lengths or empty). */
function safeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || !a || !b) return false;
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

/** IPN: the X-Secret-Key header must be the merchant Secret Key. */
function verifyIpn(headers, secretKey) {
  return safeEqual(String(headers['x-secret-key'] || ''), secretKey || '');
}

function hmacHex(secret, timestamp, rawBody) {
  return crypto.createHmac('sha256', secret).update(`${timestamp}.${rawBody}`).digest('hex');
}

/**
 * Bank webhook: `Authorization: Apikey K`, or the HMAC signature (timestamp
 * within [toleranceSec] of [nowSec], so an old request cannot be replayed).
 */
function verifyBankWebhook(headers, rawBody, { apiKey, hmacSecret, nowSec, toleranceSec = 300 }) {
  const sig = String(headers['x-sepay-signature'] || '');
  if (sig) {
    const ts = String(headers['x-sepay-timestamp'] || '');
    if (!hmacSecret || !/^\d+$/.test(ts)) return false;
    if (Math.abs(nowSec - Number(ts)) > toleranceSec) return false;
    return safeEqual(sig, `sha256=${hmacHex(hmacSecret, ts, rawBody)}`);
  }
  const m = /^apikey\s+(.+)$/i.exec(String(headers.authorization || '').trim());
  return !!m && safeEqual(m[1].trim(), apiKey || '');
}

/**
 * IPN body -> {kind, event}. kind: 'paid' (ORDER_PAID, approved payment),
 * 'void' (TRANSACTION_VOID: logged for the admin, never undone by itself) or
 * 'ignore'. The order code is the order_invoice_number; the Pha lê comes from
 * the transaction amount, never from anything else in the body.
 */
function readIpn(body, prefix = DEFAULTS.codePrefix) {
  const b = body && typeof body === 'object' ? body : {};
  const order = b.order || {};
  const txn = b.transaction || {};
  const code = findCode(order.order_invoice_number, prefix)
    || findCode(order.order_description, prefix);
  const rawId = txn.transaction_id || txn.id || null;
  const txnId = rawId ? `ipn_${rawId}` : null;
  const amount = Number(txn.transaction_amount !== undefined ? txn.transaction_amount : order.order_amount);
  if (b.notification_type === 'TRANSACTION_VOID') {
    return { kind: 'void', event: { txnId, amount, code, source: 'ipn' } };
  }
  const approved = !txn.transaction_status || txn.transaction_status === 'APPROVED';
  const payment = !txn.transaction_type || txn.transaction_type === 'PAYMENT';
  if (b.notification_type !== 'ORDER_PAID' || !approved || !payment) return { kind: 'ignore' };
  return { kind: 'paid', event: { txnId, amount, code, source: 'ipn' } };
}

/** Bank webhook body -> same shape. Only money IN is a payment. */
function readBankWebhook(body, prefix = DEFAULTS.codePrefix) {
  const b = body && typeof body === 'object' ? body : {};
  if (b.transferType !== 'in') return { kind: 'ignore' };
  const code = findCode(b.code, prefix) || findCode(b.content, prefix);
  return {
    kind: 'paid',
    event: { txnId: b.id !== undefined ? `bank_${b.id}` : null, amount: Number(b.transferAmount), code, source: 'bank' },
  };
}

module.exports = { safeEqual, verifyIpn, verifyBankWebhook, hmacHex, readIpn, readBankWebhook };