import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Dart के unhandled errors एक छोटी फ़ाइल में लिखता है.
/// Settings → "Problem report भेजो" से testers ये फ़ाइल share कर सकते हैं.
/// (नोट: native crash — जैसे mpv का — इसमें नहीं आते.)
class CrashLog {
  static File get _file => File('${Directory.systemTemp.path}/veoplay_log.txt');

  static Future<void> write(String kind, Object error, StackTrace? stack) async {
    try {
      final f = _file;
      final line =
          '[${DateTime.now().toIso8601String()}] $kind: $error\n${stack ?? ''}\n---\n';
      await f.writeAsString(line, mode: FileMode.append, flush: true);
      // फ़ाइल बहुत बड़ी न हो: 200 KB से ऊपर जाए तो पीछे का 100 KB रखो
      if (await f.length() > 200 * 1024) {
        final text = await f.readAsString();
        await f.writeAsString(text.substring(text.length - 100 * 1024));
      }
    } catch (_) {}
  }

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      write('FlutterError', details.exception, details.stack);
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      write('Unhandled', error, stack);
      return false;
    };
  }

  /// log फ़ाइल का path (फ़ाइल न हो तो null)
  static Future<String?> path() async {
    try {
      final f = _file;
      if (await f.exists() && await f.length() > 0) return f.path;
    } catch (_) {}
    return null;
  }

  static Future<void> clear() async {
    try {
      final f = _file;
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
