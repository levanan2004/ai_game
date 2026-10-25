/// VM and tests: there is no browser install dialog.
bool get homeScreenInstalled => false;

bool get homeScreenCanPrompt => false;

String get homeScreenPlatform => 'other';

Future<String> promptHomeScreen() async => 'unavailable';

void listenHomeScreenInstall(void Function() onChange) {}

void cancelHomeScreenInstallListener() {}
