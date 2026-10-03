{{flutter_js}}
{{flutter_build_config}}
(function () {
  // New URL each build, so a browser that cached main.dart.js for hours
  // still downloads the game that was just deployed.
  var stamp = {{flutter_service_worker_version}};
  if (stamp == null) stamp = 'dev';
  var builds = (_flutter.buildConfig && _flutter.buildConfig.builds) || [];
  for (var i = 0; i < builds.length; i++) {
    var path = builds[i].mainJsPath;
    if (path && path.indexOf('?') === -1) {
      builds[i].mainJsPath = path + '?v=' + encodeURIComponent(stamp);
    }
  }
})();
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
