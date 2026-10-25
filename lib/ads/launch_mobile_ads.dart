import 'launch_mobile_ads_stub.dart'
    if (dart.library.io) 'launch_mobile_ads_io.dart'
    as impl;

Future<void> launchMobileAds() => impl.launchMobileAds();
