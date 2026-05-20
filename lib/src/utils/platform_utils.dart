import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

abstract class PlatformUtils {
  PlatformUtils._();

  static bool get isWeb => kIsWeb;

  static Future<bool> hasMicrophonePermission() async {
    final recorder = AudioRecorder();
    final result = await recorder.hasPermission();
    await recorder.dispose();
    return result;
  }
}
