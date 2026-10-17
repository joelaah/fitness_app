import 'web_splash_stub.dart'
    if (dart.library.js) 'web_splash_web.dart'
    if (dart.library.html) 'web_splash_web.dart' as platform;

void dismissWebSplash() {
  platform.removeSplashFromWeb();
}
