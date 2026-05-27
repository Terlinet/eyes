import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('setPoseCallback')
external set _setPoseCallback(void Function(String landmarksJson) f);

void setPoseCallback(void Function(String landmarksJson) f) {
  _setPoseCallback = allowInterop(f);
}

@JS('initPoseDetector')
external void initPoseDetector();

@JS('captureFrame')
external String captureFrame();
