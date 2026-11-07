import 'dart:js_interop';

@JS('setPoseCallback')
external void _setPoseCallback(JSFunction callback);

void setPoseCallback(void Function(String landmarksJson) f) {
  // Converte a closure Dart para JSFunction compatível com dart:js_interop
  _setPoseCallback(f.toJS);
}

@JS('initPoseDetector')
external void initPoseDetector();

@JS('captureFrame')
external String captureFrame();

@JS('downloadImage')
external void downloadImage(String dataUrl, String filename);
