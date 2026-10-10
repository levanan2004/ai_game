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
     `mismatch` (recomputed differs from the board value, higher or lower),
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