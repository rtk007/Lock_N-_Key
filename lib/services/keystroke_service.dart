import 'package:flutter/services.dart';

class KeystrokeService {
  static const MethodChannel _channel = MethodChannel('com.locknkey.app/keystroke');

  /// Injects the given text directly into the active window using native OS events.
  /// 
  /// This method:
  /// 1. Sends the text to the C++ layer.
  /// 2. C++ layer hides the Flutter window to restore focus to the previous app.
  /// 3. C++ layer injects keystrokes via SendInput.
  /// 4. C++ layer clears the memory immediately.
  static Future<void> typeText(String text) async {
    try {
      await _channel.invokeMethod('typeText', {'text': text});
    } on PlatformException catch (e) {
      print("Failed to inject text: '${e.message}'.");
      // Rethrow to handle UI feedback if needed
      rethrow; 
    }
  }
}
