'use strict';
// Pha le top-up is closed for good (An, 26/10/2026: no Vietnamese game
// licence). Server side, whatever the app or config/phaleShop says:
//   - topup.js createOrder refuses every new bank-transfer order;
//   - topup.js handlePayment credits only an order created before this moment
//     (money for an older pending order that lands late is still credited);
//   - apple_iap.js creditApplePurchase credits only an App Store transaction
//     whose Apple-signed purchaseDate is before this moment.
// 2026-10-26 23:45 UTC+7.
const PHALE_SHUTDOWN_AT = new Date('2026-10-26T16:45:00Z');

module.exports = { PHALE_SHUTDOWN_AT };
