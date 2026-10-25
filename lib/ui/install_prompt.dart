import 'install_prompt_stub.dart'
    if (dart.library.html) 'install_prompt_web.dart'
    as impl;

/// True when this window was opened from the home-screen icon.
bool get homeScreenInstalled => impl.homeScreenInstalled;

/// True when Chrome is ready to show its install dialog.
bool get homeScreenCanPrompt => impl.homeScreenCanPrompt;

/// `ios`, `android`, or `other`.
String get homeScreenPlatform => impl.homeScreenPlatform;

/// `accepted`, `dismissed`, or `unavailable`. Must run inside a tap.
Future<String> promptHomeScreen() => impl.promptHomeScreen();

void listenHomeScreenInstall(void Function() onChange) =>
    impl.listenHomeScreenInstall(onChange);

void cancelHomeScreenInstallListener() =>
    impl.cancelHomeScreenInstallListener();
