# Server side of the Mị lực board (Cloud Functions)

**Not deployed.** Nothing here runs until someone deploys it. The app and
`firestore.rules` work without it, but season rewards are then NOT paid.

## What it does

| function            | when                                      | does                                                             |
|---------------------|-------------------------------------------|------------------------------------------------------------------|
| `verifyCharmEntry`  | a board row is created or updated         | recompute from the save, compare, **fix** (default) or log      |
| `sweepCharmBoard`   | every 30 minutes                          | the same for the top 100 of the live period                      |
| `payoutCharmBoard`  | every 10 minutes                          | season meta docs, then the automatic season payout (below)       |

All of them use the Admin SDK, so they are not bound by `firestore.rules`.

### Live check (`verifyCharmEntry`, `sweepCharmBoard`): default mode is `fix`

The app computes Mị lực on the device and publishes it to
`charm_board/{period}/entries/{uid}`. The functions recompute it from the cloud
save (`users/{uid}.progress`) with the same arithmetic as the app
(`charm.js`, `charm.test.js` mirrors `test/logic/charm_rewards_test.dart`):

* every mismatch is logged: `charm board mismatch` with `stored`, `recomputed`,
  `verdict`, `mode` (Cloud Logging, for the admin to read);
* `CHARM_MODE` unset or `fix` (**default from the first season**): a row above
  what the save backs is overwritten with the recomputed value (pet, stage,
  worn too, and `reachedAt` moves to now); a row whose save gives under 20, no
  pet in the Mị lực slot, or no readable save is **deleted**;
* `CHARM_MODE=log`: only the log line, nothing is changed. Put it in
  `functions/.env` and redeploy to switch back.
* A row **below** what the save backs is never raised: the cloud save is
  written at the morning checkpoint, so it can lag behind what the device
  published (raising it would give a legitimate player a score they no longer
  have). The final payout does recompute from the save (see HELD below).

### Season payout (`payoutCharmBoard`)

Runs every 10 minutes and is safe to run any number of times.

1. **Season meta docs.** If missing, creates `charm_board/{periodKey}`
   (`startsAt`, `endsAt`, `createdBy: "function"`) for the live season from
   `economy.json` (`leaderboard.seasonStart` + `cycleDays`, a day in Vietnam
   time), and the same for the **next** season (`season-N+1`, starting when
   this one ends). Existing docs are never touched, so an admin can edit
   `endsAt` and it sticks. Nobody creates these by hand.
2. **Kill switch.** `config/charmPayout` `{ autoPayout: false }` stops the
   payout (step 3). Missing doc or `true` = pay. Season docs are still created.
3. **Payout** of every period whose `endsAt` + **5 minutes** has passed and whose
   `charm_board/{period}.payout.status` is not `done` (4-week season ends
   Sunday 23:59 Vietnam time, i.e. Monday 00:00; the first payout is 00:05):
   * recompute Mị lực of **every** board row from its save;
   * **dropped** (row deleted, review line `skipped`, no reward): no readable
     save (`no_save`), no pet in the Mị lực slot (`no_pet`), under 20
     (`under_min`);
   * the rest are **ranked** by recomputed charm, tie: who reached the score
     first (`reachedAt`), then uid; their board rows are overwritten with the
     recomputed values; top 100 get a reward;
   * **HELD** (no mail, review line `held` with `flags`, left for the admin):
     `mismatch` (the board value is HIGHER than the recomputed charm; a board
     value at or below it is not held: the row is overwritten and paid by the
     recomputed value),
     `over_cap` (board value above 600), `new_account` (account created on or
     after the season start). Account creation time = **Firebase Auth
     `metadata.creationTime`** (`admin.auth().getUsers`), falling back to
     `users/{uid}.joinedAt`; if neither is known the row is not held for that
     reason. A held row keeps its rank, so nobody else's rank moves;
   * every other ranked row gets **one mail** `mails/bxh_{period}_{uid}`,
     created only if absent (`create()` fails with ALREADY_EXISTS on a rerun):
     Pha lê, Giọt hoa and one random item inside the tier, **picked now and
     stored in the mail**. Same table and same mail text as the app
     (`leaderboard.rewards` in `economy.json`;
     `test/fixtures/charm_rewards_fixture.json` is the golden table checked by
     both `payout.test.js` and `test/logic/charm_reward_parity_test.dart`);
   * review lines: `charm_board/{period}/review/{uid}` (`sent`, `held`,
     `skipped`, `failed`); a row the admin **released** stays released;
   * meta `payout` = `{ status: done | partial, at, rows, ranked, sent,
     created, held, skipped, failed }`. `partial` (a mail write failed) is
     retried on the next tick.

The admin page `/quan-tri` > Xếp hạng Mị lực shows sent / skipped / held, the
kill-switch toggle, and **Duyệt thưởng** for held rows only (it writes the same
`bxh_{period}_{uid}` mail, create-only, and marks the line `released`).

## Firestore rules that go with it (`firestore.rules`)

* `charm_board/{period}` (season meta, `endsAt`): signed-in read, admin write.
* Entry writes (create / update / delete) are refused once server time
  (`request.time`) is past `endsAt` + 5 minutes (`boardOpen`).
  **Missing meta doc, or a meta doc without `endsAt` = the period stays open**
  (fail-open, so the board does not stop before the function has ever run).
  The function creates the doc at its first tick; until then there is no end.
* `charm_board/{period}/review/{uid}`: admin only.
* `config/charmPayout`: admin writes `{ autoPayout: bool }`; anyone reads.
* `mails/bxh_*`: admin create only, never edited; a player cannot write any mail.

## First-deploy checklist (An)

1. Blaze plan on `tiem-hoa-som-mai`; Firebase CLI logged in as owner; Node 20.
2. Enable APIs once: Cloud Functions, Cloud Build, Cloud Scheduler, Eventarc,
   Artifact Registry, Cloud Run, Identity Toolkit (for the Auth lookup).
3. Add the `functions` block to `firebase.json` (below). It is absent on purpose
   so a normal `firebase deploy` cannot deploy this by accident.
4. `cd functions && npm install && npm test` (syncs `economy.json`, runs 26 tests).
5. Deploy the **rules first**: `firebase deploy --only firestore:rules`.
6. `firebase deploy --only functions --project tiem-hoa-som-mai`.
7. Check in Cloud Scheduler that `payoutCharmBoard` exists, run it once
   ("Force run"), then check Firestore: `charm_board/season-1` and
   `charm_board/season-2` exist with `endsAt` (season-1: 2026-11-09 00:00
   Vietnam time = `2026-11-08T17:00:00Z`).
8. Leave `config/charmPayout` alone (default = pay) or set `autoPayout: false`
   from `/quan-tri` to hold everything.
9. After each season: read `charm_board/{period}.payout` and the held list in
   `/quan-tri`.
10. A new season needs a new build: `leaderboard.periodKey` and `seasonStart` in
   `economy.json` are read by the app and the function; change both, release the
   app, then re-run `npm run sync` and redeploy the functions.

```json
"functions": [{
  "source": "functions",
  "codebase": "default",
  "predeploy": ["node functions/sync-economy.js"]
}]
```

`economy.json` is copied from `assets/data/economy.json` by `sync-economy.js`;
redeploy after every economy change that touches pets, stage multipliers, item
tiers or the reward table.

## Permissions

* The functions run as the default compute service account, which already has
  Firestore access; it also needs **Firebase Authentication Viewer** (or
  `roles/firebaseauth.viewer`) for `getUsers`.
* The deployer needs `roles/cloudfunctions.admin`, `roles/iam.serviceAccountUser`
  and `roles/artifactregistry.writer` (Owner has all three).

## Cost and limits

The payout reads every board row and the save of each (one `getAll` per 100),
once per season, plus two small reads every 10 minutes. A board of a few
thousand players is well inside the free tier; it is not meant for hundreds of
thousands of rows in one run (540 s timeout).

## Tests

`npm test` (from `functions/`): `charm.test.js` (arithmetic, mirrors the Dart
test), `verify.test.js` (fix / log, default mode), `payout.test.js` (scheduler
against `fake_firestore.js`: grace, ranking, ties, drops, held, idempotency,
kill switch, partial failure, parity fixture). Rules: `tool/charm_season_rules_test.cjs`,
`tool/charm_board_rules_test.cjs`, `tool/mail_rules_test.cjs`,
`tool/gift_rules_test.cjs` (Firestore emulator, JDK 21).

# Pha lê top-up by bank transfer (SePay)

Code: `topup.js` (rules of the money), `sepay.js` (header checks, payload
readers), `topup_http.js` (the HTTP layer), `index.js` (binds them to secrets
and Cloud Functions). **Nothing here is deployed by the repo; An deploys.**

## Which SePay product is this?

SePay has two "tell my server about a payment" features:

| | Cổng thanh toán **IPN** | **Webhook** giao dịch ngân hàng |
|---|---|---|
| Dashboard asks for | IPN URL, Content Type, **Mã đơn vị**, **Secret Key** | Webhook URL, kiểu chứng thực (API Key / OAuth2 / không), Content-Type |
| Header SePay sends | `X-Secret-Key: <Secret Key>` | `Authorization: Apikey <API key>` (or `X-SePay-Signature`) |
| Fires when | a payer pays an order made through SePay's hosted checkout (`order_invoice_number` = our code) | **any** money arriving in the linked bank account whose content holds our code |
| Function here | `sepayIpn` | `sepayBankWebhook` |

The four fields An named (IPN URL, Content Type, Mã đơn vị, Secret Key) are
the **Cổng thanh toán IPN** screen, so `sepayIpn` is the endpoint for them.

**Important, please read:** the app shows its own VietQR (`qr.sepay.vn/img`
with our account, amount and `THSM...` content) instead of sending the player
to SePay's checkout page. A transfer made from that QR is a plain bank
transfer; SePay reports it through the **bank webhook**, not through the
Payment Gateway IPN. So for the screen as designed, **set up the bank webhook
(`sepayBankWebhook`)**. `sepayIpn` is ready and tested for the day orders are
created through SePay's checkout API instead (then `order_invoice_number` must
be the code our `phaleCreateOrder` made); until then the IPN screen can stay
empty. Both endpoints credit through the same code, so nothing else changes.

## The flow

1. App: `POST phaleCreateOrder {packId}` (Firebase ID token) -> an order doc
   `phale_orders/{code}` and a pointer `phale_pending/{uid}`. The pack
   (amount, Pha lê) is read from `economy.json` (`phaLeShop.packs`) on the
   server, never from the client. One open order per account: asking again
   returns the same order. It expires after 15 minutes (the app countdown).
   Needs `config/phaleShop.open == true` or it answers 503 `closed`.
2. The player pays the QR. The transfer content is the code
   (`THSM` + 10 characters from `A-HJ-NP-Z2-9`, `crypto.randomInt`, about 5e14
   combinations; it is also the order id).
3. SePay calls our endpoint. We check the header (constant-time compare, 401
   on mismatch, nothing is read from the body before that), then in ONE
   Firestore transaction: record `sepay_txns/{id}` (create-only: this is the
   idempotency key), mark the order `paid`, create the mail
   `mails/phale_{code}` and free the pointer. SePay's retries and two parallel
   calls cannot pay twice; if any write fails nothing lands and we answer 500
   so SePay retries.
4. App: `GET phaleOrderStatus?orderId=` (only reads the order doc and the
   clock; "Tôi đã chuyển" just calls this again). When it says `paid` the app
   claims the mail like any reward.

### Credit rules

- Pha lê = the pack whose price equals the **amount SePay reports**
  (`pack_50k` -> 550 ...). Paying the price of another pack pays that pack.
  The client sends nothing that decides money.
Hà Phương's rule: **time is never a cutoff.** If the money arrives with a
correct order code AND an amount equal to a pack, the Pha lê is credited, however
late the order expired and even if the order was cancelled.

| Case | Credited? | Result / what is recorded |
|---|---|---|
| Code = an order, amount = a pack, order pending | **yes** | `credited`, order `paid` |
| Same, but money came after expiry + grace (late) | **yes** | `credited`, order `late: true` (and `late: true` on the `sepay_txns` row) |
| Same, but the order was cancelled | **yes** | `credited`, order `afterCancel: true` (and on the txn row) |
| Same, order in `lech_goi` (an earlier wrong amount) | **yes** | `credited`, `statusBefore: lech_goi` |
| Code = an order, amount equals **no** pack | no | `lech_goi`, order `mismatch` with `receivedAmount`; admin resolves by hand. If the right amount arrives later it credits |
| No order has this code (or no code in the transfer) | no | `unmatched` row in `sepay_txns` for An |
| A **different** transaction on an order that is already paid | no | `duplicate_payment`: txn row + `duplicatePayment: true` and `extraTxnIds` on the order, admin refunds or decides |
| The same SePay transaction id again (retry, parallel) | no (once only) | `duplicate`: no-op, nothing written |

- The Pha lê is the pack whose price equals the **amount SePay reports**: paying
  another pack's price pays that pack (`orderedPackId` keeps what was asked).
- `late` means more than 2 minutes (`graceSeconds`) after `expiresAt`. The 2
  minutes only decide the flag, never whether to pay.
- Why `duplicate_payment` is not credited: the first transaction already paid the
  order and the mail `phale_{code}` exists once per code. A second payment
  with the same code is most likely the player sending twice; paying it would
  need a second mail, and the player can ask for a refund. It is flagged so the
  admin sees it.
- A paid order always shows `paid` to the app, even when it had been shown as
  expired. While the order screen is open the app keeps asking, so a late
  payment appears there; if the screen was closed (or the order cancelled) the
  mail is simply waiting in the player's mailbox (Hộp thư).
- Admin lists to look at: orders with `late == true`, `afterCancel == true`,
  `duplicatePayment == true`, `status == 'lech_goi'`, and `sepay_txns` rows
  with `result in ('unmatched','duplicate_payment','lech_goi')`.
- Statuses: `pending | paid | expired | cancelled | lech_goi` (the app maps
  `lech_goi` to its `mismatch` screen). `expired` is shown by the clock for a
  pending order past `expiresAt`; `expired` and `cancelled` can become `paid`.
- `TRANSACTION_VOID` is only logged; a refund is never undone automatically.

### Why a mail, not the save blob

The balance lives inside the player's save (`users/{uid}`, written by the app).
Editing it from a function would race the app's own saves (last write wins, a
payment could vanish) and would not work while the app is closed. A mail is a
new document nobody else writes: it lands atomically with the order, waits
until the player opens the game, is claimed once (the claimed mark is keyed
by the mail id, so it cannot be claimed twice, even after a delete) and goes
through the same `grantRewards` path as every other Pha lê. Players cannot
create or edit mails (rules), and `phale_*` mails are never updated.

## Firestore (rules in `firestore.rules`)

| Doc | Written by | Readable by |
|---|---|---|
| `phale_orders/{code}`: uid, packId, amount, crystals, status, transferContent, bank, createdAt, expiresAt, sepayTxnId, paidAt, crystalsGranted, receivedAmount, late, afterCancel, statusBefore, duplicatePayment, extraTxnIds | Functions only | the owner (`get`), admin (`list`) |
| `phale_pending/{uid}`: open order pointer | Functions only | admin |
| `sepay_txns/{id}`: one row per SePay transaction (`ipn_<id>` / `bank_<id>`), result (credited, duplicate_payment, lech_goi, unmatched), late, afterCancel | Functions only | admin |
| `mails/phale_{code}`: the credit | Functions only | the target player |
| `config/phaleShop`: `{open: bool}` | admin | everyone |

Resolving a `lech_goi` order: look at `phale_orders/{code}` (receivedAmount,
sepayTxnId), decide, then either send a normal mail with the Pha lê from
`/quan-tri` -> Thư, or refund by bank. There is no screen for it yet.

## Secrets and settings (An, once, on your PC)

Project id `tiem-hoa-som-mai`, **2nd gen** functions, region
**`asia-southeast1`** (same as the leaderboard functions). Never put these in
the repo or in chat.

```
firebase functions:secrets:set SEPAY_SECRET_KEY --project tiem-hoa-som-mai
firebase functions:secrets:set SEPAY_API_KEY --project tiem-hoa-som-mai
firebase functions:secrets:set SEPAY_MERCHANT_ID --project tiem-hoa-som-mai
```

(each command asks for the value; paste it)

- `SEPAY_SECRET_KEY` = the **Secret Key** of the IPN screen. Checked against
  `X-Secret-Key`. It is also the HMAC key if you turn on SePay's signature.
- `SEPAY_API_KEY` = the API key you type in the bank-webhook screen
  (kiểu chứng thực "API Key"). Checked against `Authorization: Apikey ...`.
- `SEPAY_MERCHANT_ID` = the **Mã đơn vị**. Stored for later API calls; today's
  code does not read it (the checks are the two keys above).

Non-secret settings, in `functions/.env.tiem-hoa-som-mai` (create the file; it
is git-ignored with the other `.env*`):

```
SEPAY_BANK_NAME=Vietcombank
SEPAY_BANK_CODE=VCB
SEPAY_ACCOUNT_NO=<your account number>
SEPAY_ACCOUNT_NAME=<account holder>
SEPAY_CODE_PREFIX=THSM
```

In the SePay dashboard set the payment-code prefix to the same `THSM`
(Cấu hình công ty -> Cấu hình chung -> Cấu trúc mã thanh toán) so it also
fills the webhook `code` field; our code also finds it inside `content`.

## Endpoints and URLs

Deploy: `firebase deploy --only functions --project tiem-hoa-som-mai`
(or only these: `--only functions:sepayIpn,functions:sepayBankWebhook,functions:phaleCreateOrder,functions:phaleOrderStatus,functions:phaleCancelOrder`).

| Function | URL | Who calls it |
|---|---|---|
| `sepayBankWebhook` | `https://asia-southeast1-tiem-hoa-som-mai.cloudfunctions.net/sepayBankWebhook` | SePay **Webhooks**: Content-Type `application/json`, auth "API Key" |
| `sepayIpn` | `https://asia-southeast1-tiem-hoa-som-mai.cloudfunctions.net/sepayIpn` | SePay **Cổng thanh toán IPN**: Content Type `application/json` (not form) |
| `phaleCreateOrder`, `phaleOrderStatus`, `phaleCancelOrder` | same pattern | the app (Bearer ID token) |

(2nd-gen functions also have a `*.run.app` URL; either works. SePay needs the
public https URL, so the function is public; every call is checked by header.)

## First-deploy checklist (top-up)

1. Create the 3 secrets and the `.env` file above.
2. `cd functions && npm install && npm test` (all green).
3. `firebase deploy --only firestore:rules --project tiem-hoa-som-mai` (new
   rules: orders, pending, txns, `phale_*` mails, `config/phaleShop`).
4. Deploy the functions.
5. In SePay: add the bank webhook with the URL above, API-key auth, JSON.
6. Test with 10.000đ: `config/phaleShop` still closed -> app shows
   "Chưa mở bán". Set `config/phaleShop` = `{open:true}` (and
   `phaLeShop.open` in the app's `economy.json`), make an order from a test
   account, pay it, watch `sepay_txns` and the mail arrive.
7. Check `firebase functions:log --only sepayBankWebhook` for the line
   `sepay notification` (every authenticated call is logged; keys never are).

## Tests

`npm test` (fake Firestore, no emulator): `topup.test.js` covers order
creation (pack from the server table, unique code, one open order, expiry,
cancel), exact / other-pack / wrong amount, duplicate and parallel
notifications, late-after-grace, long-expired and cancelled orders (all credit,
flagged), unmatched codes, bad and missing secrets, HMAC,
void, a failing write (nothing half-lands) and that secrets never reach a log.
Rules: `tool/phale_rules_test.cjs` (emulator, 28 checks).