import 'dart:async';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart' hide MediaItem;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'video_cache_db.dart';
import 'crash_log.dart';

// ---- Split files (same library, code unchanged) ----
part 'splash_screen.dart';
part 'home_screen.dart';
part 'video_player_screen.dart';
part 'dual_video_screen.dart';
part 'media_widgets.dart';
part 'audio_handler.dart';
part 'audio_player_screen.dart';
part 'video_search_screen.dart';
part 'profile_screen.dart';
part 'music_screens.dart';
part 'theme_helper.dart';
part 'settings_screen.dart';
part 'video_playlist_screen.dart';

final ValueNotifier<int> recentChangedNotifier = ValueNotifier<int>(0);
final AndroidEqualizer globalEqualizer = AndroidEqualizer();
final AudioPlayer globalAudioPlayer = AudioPlayer(
  audioPipeline: AudioPipeline(androidAudioEffects: [globalEqualizer]),
);
final ValueNotifier<int> rescanRequestNotifier = ValueNotifier<int>(0);

// App version (read automatically from pubspec.yaml)
String appVersionName = '1.0.0';
String appVersionFull = '1.0.0 (Build 1)';

// Placeholder for an ad slot on the Home screen. Keep false (the app has no ads).
const bool kShowAdSlot = false;

// ---- Music Sleep Timer (keeps running when the screen is off) ----
final ValueNotifier<int> musicSleepRemaining = ValueNotifier<int>(0);
Timer? _musicSleepOnce;
Timer? _musicSleepTick;

void startGlobalSleepTimer(int minutes) {
  cancelGlobalSleepTimer();
  musicSleepRemaining.value = minutes;
  _musicSleepOnce = Timer(Duration(minutes: minutes), () {
    globalAudioPlayer.pause();
    musicSleepRemaining.value = 0;
    _musicSleepTick?.cancel();
  });
  _musicSleepTick = Timer.periodic(const Duration(minutes: 1), (t) {
    if (musicSleepRemaining.value > 0) musicSleepRemaining.value--;
    if (musicSleepRemaining.value <= 0) t.cancel();
  });
}

void cancelGlobalSleepTimer() {
  _musicSleepOnce?.cancel();
  _musicSleepOnce = null;
  _musicSleepTick?.cancel();
  _musicSleepTick = null;
  musicSleepRemaining.value = 0;
}
final Map<int, String> globalSongNames = {};
final ValueNotifier<int> musicDataNotifier = ValueNotifier<int>(0);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ---- Video opened from outside the app (File Manager / Share) ----
// A video received while the app was closed waits here and opens after the Splash screen
String? pendingLaunchUri;
// Whether Splash has finished and Home is showing
bool appReadyForIntents = false;

String? _uriFromIntent(dynamic intent) {
  try {
    if (intent == null) return null;
    final action = intent.action;
    if (action == 'android.intent.action.VIEW') {
      final d = intent.data;
      if (d != null && d.toString().isNotEmpty) return d.toString();
    } else if (action == 'android.intent.action.SEND') {
      final extra = intent.extra;
      final st = extra == null ? null : extra['android.intent.extra.STREAM'];
      if (st != null && st.toString().isNotEmpty) return st.toString();
    }
  } catch (_) {}
  return null;
}

String titleFromUri(String uri) {
  try {
    var last = uri.split('/').last;
    if (last.contains('?')) last = last.split('?').first;
    last = Uri.decodeComponent(last);
    if (last.isEmpty) return 'Video';
    return last;
  } catch (_) {
    return 'Video';
  }
}

void openExternalVideo(String uri) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => RealVideoPlayer(
        videoUrl: uri,
        title: titleFromUri(uri),
      ),
    ),
  );
}

// Ask for notification permission on Android 13+
Future<void> askNotificationPermission() async {
  try {
    await const MethodChannel('veoplay/orientation')
        .invokeMethod('requestNotifications');
  } catch (e) {
    debugPrint('Notification permission error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashLog.install();
  mk.MediaKit.ensureInitialized();

    try {
  await AudioService.init(
    builder: () => VeoAudioHandler(globalAudioPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.aucyos.veoplay.channel.audio',
      androidNotificationChannelName: 'VeoPlay Audio',
      androidNotificationOngoing: true, 
      androidStopForegroundOnPause: true, 
      androidNotificationIcon: 'mipmap/launcher_icon',
    ),
  );
} catch (e) {
  debugPrint('Audio background init error: $e');
    }

  try {
    final info = await PackageInfo.fromPlatform();
    appVersionName = info.version;
    appVersionFull = '${info.version} (Build ${info.buildNumber})';
  } catch (e) {
    debugPrint('Version read error: $e');
  }

  try {
    await AppTheme.load();
  } catch (e) {
    debugPrint('Theme load error: $e');
  }
  
  // If the app was closed and a video was opened with "Open with", catch it here
  try {
    final first = await ReceiveIntent.getInitialIntent()
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    final u = _uriFromIntent(first);
    if (u != null) pendingLaunchUri = u;
  } catch (e) {
    debugPrint('Initial intent error: $e');
  }

  runApp(const VeoPlay());

  try {
    ReceiveIntent.receivedIntentStream.listen((intent) {
      final u = _uriFromIntent(intent);
      if (u == null) return;
      if (appReadyForIntents) {
        openExternalVideo(u);
      } else {
        // Splash is still running: pushing now would be replaced by Splash
        pendingLaunchUri = u;
      }
    });
  } catch (e) {
    debugPrint('Intent stream error: $e');
  }
}

// ---------- Main App ----------
class VeoPlay extends StatelessWidget {
  const VeoPlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          navigatorKey: navigatorKey, 
          debugShowCheckedModeBanner: false,
          title: "VeoPlay",
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppTheme.bg,
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
