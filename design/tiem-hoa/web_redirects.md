# Web redirects (Cloudflare Pages)

Files: `web/_redirects`, `web/_headers`. `flutter build web` copies both to the
root of `build/web`, and the deploy zip is that folder, so they sit at the root
of the deployed assets (the only place Pages reads them).

## `/site` -> `/` (in `_redirects`)

The home page is `web/site.html`. `/` reaches it through the last rule,
`/ /site 200` (a rewrite, the browser URL stays `/`). Pages also serves the file
at `/site` (pretty URLs), which was a second copy of the home page.

Rules at the top now 301 `/site`, `/site/` and `/site.html` to `/`. A rewrite
target is not redirected again, so `/` still answers 200 with the home page.
The play route works the same way already (`/index.html` 301s to
`/play-tiem-hoa-som-mai/`, which is a 200 rewrite of `/index.html`).
Checked with `wrangler pages dev` (3.114.17): `/` 200, `/site`, `/site/`,
`/site.html` 301 to `/`, play route 200, guide pages unchanged.
Production runs the same asset code, but confirm after the next deploy with
`curl -sI https://tiemhoasommai.com/site` and `curl -sI https://tiemhoasommai.com/`.
If `/` ever loops, drop the three `/site` lines and the home page is back.

## `www` -> apex is NOT possible in `_redirects`

A rule such as `https://www.tiemhoasommai.com/* https://tiemhoasommai.com/:splat 301`
is silently ignored: the source side is matched against the path only, never the
host. The line has been removed. Do not use a `functions/_middleware.js` for it:
Pages skips `_redirects` for routes a Function matches, which would break the
rules above.

It needs one Cloudflare rule on the zone (dashboard, nothing in the repo):

* Rules > Redirect Rules > Create rule (template "Redirect from WWW to root").
* When: Hostname equals `www.tiemhoasommai.com`.
* Then: Dynamic, expression `concat("https://tiemhoasommai.com", http.request.uri.path)`,
  status 301, "Preserve query string" ON.
* The `www` DNS record must be proxied (orange cloud). It already exists: the
  Pages project lists `www.tiemhoasommai.com` as an active custom domain.
* Alternative with the same result: Bulk Redirects, list item
  `www.tiemhoasommai.com` -> `https://tiemhoasommai.com`, 301, Preserve query
  string, Subpath matching, Preserve path suffix, Include subdomains.

API token that could create it: Zone > Single Redirect > Edit (Bulk Redirects
instead needs Account > Account Filter Lists > Edit and Account > Bulk URL
Redirects > Edit), plus Zone > Zone > Read for that zone. The token the deploy
uses today (Pages) cannot read the zone, so it cannot do this.
Verify: `curl -sI https://www.tiemhoasommai.com/huong-dan` returns 301 with
`location: https://tiemhoasommai.com/huong-dan`.
