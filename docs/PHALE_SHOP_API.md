# Pha lê shop: data the UI shows (SePay behind one interface)

The app talks to the payment server only through `PhaleGateway`
(`lib/data/phale_shop.dart`):

| call | what it does |
| --- | --- |
| `createOrder(packId)` | makes an order, returns a `PhaleOrder` |
| `orderStatus(orderId)` | returns the same order with its current `status` |
| `cancelOrder(orderId)` | third call, needed by "Hủy đơn": the server kills the QR |

Until the flag `phaLeShop.open` in `economy.json` is `true` the shop shows
"Sắp mở" and no order is made (`ClosedPhaleGateway`). With the flag on and no
real gateway set (`ShopSession.phaleGateway`), the labelled `DemoPhaleGateway`
answers: bank "Ngân hàng DEMO", account `0000000000`, the fake QR
`assets/images/phale/qr_gia.png`. A demo order never pays by itself.

**Pha lê is never credited by the app.** "Tôi đã chuyển" only calls
`orderStatus` again. When the server reports `paid`, the screen shows
`crystalsGranted` and `newBalance` as given; the player's balance changes only
when the server writes it to the account and the save syncs.

## Order fields (`PhaleOrder`)

| field | type | meaning |
| --- | --- | --- |
| `orderId` | string | unique; also the support reference |
| `amount` | int | dong, e.g. `50000` (shown "50.000đ", copied as digits) |
| `bank` | string | bank name |
| `accountNo` | string | account number (copied as is) |
| `accountName` | string | account holder |
| `transferContent` | string | the unique content the player must keep (order code) |
| `qrImageUrl` | string? | VietQR picture made by the server; null shows the fake QR |
| `expiresAt` | ISO time | end of the order, SERVER time |
| `status` | `pending` / `paid` / `expired` / `mismatch` / `cancelled` | server state |
| `crystalsGranted` | int? | with `paid`: Pha lê the server wrote |
| `newBalance` | int? | with `paid`: the balance after it |
| `packId`, `crystals`, `bonusPercent` | | the pack the order is for |
| `serverTime` | ISO time? | the server clock when it answered; the countdown is `expiresAt - serverTime`, never the device clock |
| `supportContact` | string? | URL for "Liên hệ hỗ trợ"; without it the order code is copied |

## Packs (`economy.json` → `phaLeShop`)

`packs[]` with `id`, `priceVnd`, `phaLe` (bonus included), `bonusPercent`;
`bestPackId` (the "Đáng giá nhất" tag), `pollSeconds` (status poll while the
transfer screen is up), `checkGapSeconds` (shortest gap between two taps of
"Tôi đã chuyển"), `open` (the flag).

## Not decided / open

- A restart of the app forgets a waiting order (S6g works within a session).
  Restoring it needs a server call that lists the player's pending order.
- "Đơn của tôi" (order history) is not built.
- The pill's `+` shares the main shop's top bar with the rating star, so the
  pill squeezes a 4-digit balance with `FittedBox`.
