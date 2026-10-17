// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void removeSplashFromWeb() {
  try {
    if (js.context.hasProperty('removeSplashFromWeb')) {
      js.context.callMethod('removeSplashFromWeb');
    }
  } catch (_) {}
}
