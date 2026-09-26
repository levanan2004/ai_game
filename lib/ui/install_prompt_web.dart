// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';

@JS('pwaIsInstalled')
external bool _pwaIsInstalled();

@JS('pwaCanPrompt')
external bool _pwaCanPrompt();

@JS('pwaPlatform')
external String _pwaPlatform();

@JS('pwaPromptInstall')
external JSPromise<JSString> _pwaPromptInstall();

bool get homeScreenInstalled => _pwaIsInstalled();

bool get homeScreenCanPrompt => _pwaCanPrompt();

String get homeScreenPlatform => _pwaPlatform();

Future<String> promptHomeScreen() {
  return _pwaPromptInstall().toDart.then((value) => value.toDart);
}

html.EventListener? _onReady;
html.EventListener? _onInstalled;

void listenHomeScreenInstall(void Function() onChange) {
  cancelHomeScreenInstallListener();
  _onReady = (_) => onChange();
  _onInstalled = (_) => onChange();
  html.window.addEventListener('pwa-install-ready', _onReady);
  html.window.addEventListener('pwa-installed', _onInstalled);
}

void cancelHomeScreenInstallListener() {
  if (_onReady != null) {
    html.window.removeEventListener('pwa-install-ready', _onReady);
    _onReady = null;
  }
  if (_onInstalled != null) {
    html.window.removeEventListener('pwa-installed', _onInstalled);
    _onInstalled = null;
  }
}
