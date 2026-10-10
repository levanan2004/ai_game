import 'package:web/web.dart';

import 'site_route.dart';

SiteArea currentSiteArea() => areaForPath(window.location.pathname);

void leaveTo(String path) {
  window.location.assign(path);
}
