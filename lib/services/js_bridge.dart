import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('setPoseCallback')
external set _setPoseCallback(void Function(String landmarksJson) f);

void setPoseCallback(void Function(String landmarksJson) f) {
  _setPoseCallback = allowInterop(f);
}

@JS('initMediaPipe')
external void initMediaPipe(String videoId);
