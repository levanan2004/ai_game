/// Which surface the browser URL is asking for.
enum SiteArea { home, game, admin }

/// [path] is the pathname, with or without a trailing slash.
SiteArea areaForPath(String path) {
  var p = path;
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  return switch (p) {
    '/quan-tri' => SiteArea.admin,
    '/play-tiem-hoa-som-mai' => SiteArea.game,
    _ => SiteArea.home,
  };
}
