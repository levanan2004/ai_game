# Server-side Mị lực check (Cloud Functions)

**Not deployed.** Nothing here runs until someone deploys it. The game and
`firestore.rules` work exactly as before without it.

## What it does

The app computes a player's Mị lực on the device and publishes it to
`charm_board/{period}/entries/{uid}` (rules cap it at 600 and limit writes to
once per 30 s). A hacked client can still publish a number it does not
deserve. These functions recompute the score from the player's cloud save
(`users/{uid}.progress`) with the same arithmetic as the app and compare:

| function            | when                                   | does                                   |
|---------------------|----------------------------------------|----------------------------------------|
| `verifyCharmEntry`  | a board row is created or updated      | recompute, compare, log / fix          |
| `sweepCharmBoard`   | every 30 minutes (Asia/Ho_Chi_Minh)    | the same for the top 100 of the period |

`CHARM_MODE=log` (default) only writes a warning to Cloud Logging
(`charm board mismatch`, with stored and recomputed values). `CHARM_MODE=fix`
lowers a row to what the save backs, or deletes it when the save is under the
minimum (20) or has no pet in the Mị lực slot. A row below what the save
backs is never touched.

The admin review in `/quan-tri` > Xếp hạng Mị lực already shows the recomputed
number next to the stored one for every ranked player and lets the admin skip
a row before "Duyệt thưởng", so rewards are safe even with these functions off.

## Why `log` first

The cloud save is written at the morning checkpoint and when a pet changes; a
player who equips something and goes offline can be ahead of their cloud save
for a while. In `fix` mode that player's row would be lowered, and the app
will not republish it until its content changes. Watch the logs for a season
(`log`), see how many legitimate mismatches there are, then switch to `fix`.

## Deploy (when you decide to)

Needs the Blaze plan, the Firebase CLI logged in as an owner of
`tiem-hoa-som-mai`, Node 20.

```bash
cd functions && npm install
npm test                      # syncs economy.json, runs the parity tests
cd .. && firebase deploy --only functions --project tiem-hoa-som-mai
# to enforce later, put CHARM_MODE=fix in functions/.env and redeploy
```

`firebase.json` has no `functions` block on purpose (so a normal
`firebase deploy` cannot deploy this by accident). Add this when deploying:

```json
"functions": [{
  "source": "functions",
  "codebase": "default",
  "predeploy": ["node functions/sync-economy.js"]
}]
```

`economy.json` is copied from `assets/data/economy.json` by
`sync-economy.js`; re-deploy after every economy change that touches pets,
stage multipliers or item tiers.

## Permissions

* The functions run as the default App Engine / compute service account,
  which already has Firestore access; no extra role is needed.
* The deployer needs `roles/cloudfunctions.admin`, `roles/iam.serviceAccountUser`
  and `roles/artifactregistry.writer` (Owner has all three).
* Enable APIs once: Cloud Functions, Cloud Build, Cloud Scheduler, Eventarc,
  Artifact Registry, Cloud Run.

## Stricter option (later)

To make the board fully server-authoritative, change `charm_board` rules to
`allow write: if false` for clients and have a callable function write the row
after recomputing from the save. That needs the app to call the function
instead of writing, and the cloud save to be current at that moment; it is a
bigger change and not part of this step.
