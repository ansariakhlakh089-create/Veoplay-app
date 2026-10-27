import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';   // 👈 यहाँ जोड़ें
import 'package:photo_manager/photo_manager.dart';
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
import 'package:simple_pip_mode/simple_pip.dart';   // 👈 यह नई line
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ---- Split files (same library, code unchanged) ----
part 'splash_screen.dart';
part 'home_screen.dart';
part 'video_player_screen.dart';
part 'dual_video_screen.dart';
part 'media_widgets.dart';
part 'audio_player_screen.dart';
part 'video_search_screen.dart';   // 👈 नई line
part 'profile_screen.dart';        // 👈 नई line
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

// App version (pubspec.yaml से अपने-आप पढ़ा जाता है)
String appVersionName = '1.0.0';
String appVersionFull = '1.0.0 (Build 1)';

// ऊपर का खाली बॉक्स विज्ञापन (Ad) की जगह है। AdMob जुड़ने पर इसे true करें।
const bool kShowAdSlot = false;

// ---- Music Sleep Timer (स्क्रीन बंद होने पर भी चलता रहता है) ----
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.aucyos.veoplay.channel.audio',
      androidNotificationChannelName: 'VeoPlay Audio',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/launcher_icon', // 👈 यहाँ आइकॉन का सही नाम जोड़ा गया है
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
  
  runApp(const VeoPlay());

  try {
    ReceiveIntent.receivedIntentStream.listen(openFromIntent);
  } catch (e) {
    debugPrint('Intent stream error: $e');
  }
}

// बाहर से (File Manager / Gallery से "Open with") आया वीडियो खोलो
bool _initialIntentHandled = false;

void openFromIntent(Intent? intent) {
  if (intent == null) return;
  if (intent.action != 'android.intent.action.VIEW') return;
  final uri = intent.data?.toString() ?? '';
  if (uri.isEmpty) return;

  String title;
  try {
    title = Uri.decodeFull(uri).split('/').last;
  } catch (_) {
    title = uri.split('/').last;
  }
  if (title.isEmpty) title = 'Video';

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => RealVideoPlayer(videoUrl: uri, title: title),
    ),
  );
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

