part of 'main.dart';

// 👇👇👇 Subtitle Line क्लास 👇👇👇
class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;
  SubtitleLine({required this.start, required this.end, required this.text});
}
// 👆👆👆 यहाँ तक 👆👆👆


// ==================== media_kit (mpv) इंजन का wrapper ====================
// पुराना UI जैसा था वैसा ही रहता है, अंदर का इंजन media_kit है:
// असली 200% volume boost, AC3/DTS/MKV आवाज़, embedded subtitle, ज़्यादा formats
class _MkValue {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isInitialized;
  final Size size;
  const _MkValue({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isInitialized,
    required this.size,
  });
  double get aspectRatio =>
      (size.width > 0 && size.height > 0) ? size.width / size.height : 16 / 9;
}

class _MkController extends ChangeNotifier {
  final String url;
  late final mk.Player player;
  late final mkv.VideoController video;
  final List<StreamSubscription> _subs = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _initialized = false;
  int _w = 0;
  int _h = 0;
  Duration _lastNotified = Duration.zero;
  bool _disposed = false;
  List<mk.AudioTrack> audioTracks = [];
  List<mk.SubtitleTrack> subtitleTracks = [];
  bool isExternalSubtitle = false;

  _MkController(this.url) {
    player = mk.Player();
    video = mkv.VideoController(player);
    try {
      // 100% से ऊपर असली boost (mpv volume-max)
      (player.platform as mk.NativePlayer).setProperty('volume-max', '200');
    } catch (_) {}
  }

  _MkValue get value => _MkValue(
        position: _position,
        duration: _duration,
        isPlaying: _playing,
        isInitialized: _initialized,
        size: Size(_w.toDouble(), _h.toDouble()),
      );

  List<mk.AudioTrack> get realAudioTracks => player.state.tracks.audio
      .where((t) => t.id != 'auto' && t.id != 'no')
      .toList();

  List<mk.SubtitleTrack> get realSubtitleTracks => player.state.tracks.subtitle
      .where((t) => t.id != 'auto' && t.id != 'no')
      .toList();

  void _notify({bool force = false}) {
    if (_disposed) return;
    final diff = (_position - _lastNotified).inMilliseconds.abs();
    if (force || diff >= 250) {
      _lastNotified = _position;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    final done = Completer<void>();

    _subs.add(player.stream.duration.listen((d) {
      _duration = d;
      if (d > Duration.zero && !_initialized) {
        _initialized = true;
        if (!done.isCompleted) done.complete();
      }
      _notify(force: true);
    }));
    _subs.add(player.stream.position.listen((p) {
      _position = p;
      _notify();
    }));
    _subs.add(player.stream.playing.listen((p) {
      _playing = p;
      _notify(force: true);
    }));
    _subs.add(player.stream.width.listen((w) {
      _w = w ?? 0;
      _notify(force: true);
    }));
    _subs.add(player.stream.height.listen((h) {
      _h = h ?? 0;
      _notify(force: true);
    }));
    _subs.add(player.stream.tracks.listen((t) {
      audioTracks = t.audio;
      subtitleTracks = t.subtitle;
      _notify(force: true);
    }));
    _subs.add(player.stream.error.listen((e) {
      debugPrint('mpv error: $e');
      if (!_initialized && !done.isCompleted) done.completeError(e);
    }));

    final source = url.startsWith('file://')
        ? Uri.parse(url).toFilePath()
        : url;
    await player.open(mk.Media(source), play: false);

    return done.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw 'Video took too long to load',
    );
  }

  Future<void> seekTo(Duration d) async {
    var t = d;
    if (t < Duration.zero) t = Duration.zero;
    _position = t;
    await player.seek(t);
    _notify(force: true);
  }

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();

  Future<void> setLooping(bool loop) => player.setPlaylistMode(
      loop ? mk.PlaylistMode.single : mk.PlaylistMode.none);

  Future<void> setPlaybackSpeed(double speed) => player.setRate(speed);

  // v: 0.0 – 2.0  (1.0 = 100%, 2.0 = 200% असली boost)
  Future<void> setVolume(double v) async {
    final pct = (v.clamp(0.0, 2.0) * 100).round();
    try {
      await (player.platform as mk.NativePlayer)
          .setProperty('volume', pct.toString());
    } catch (_) {
      await player.setVolume(pct.toDouble());
    }
  }

  Future<void> setSubtitleDelay(double seconds) async {
    try {
      await (player.platform as mk.NativePlayer)
          .setProperty('sub-delay', seconds.toStringAsFixed(2));
    } catch (_) {}
  }

 Future<void> setAudioDelay(double seconds) async {
  try {
    await (player.platform as mk.NativePlayer)
        .setProperty('audio-delay', seconds.toStringAsFixed(2));
  } catch (_) {}
 }
  
  Future<void> setAudioTrack(mk.AudioTrack t) => player.setAudioTrack(t);
  Future<void> setSubtitleTrack(mk.SubtitleTrack t) =>
      player.setSubtitleTrack(t);

  mk.AudioTrack get currentAudio => player.state.track.audio;
  mk.SubtitleTrack get currentSubtitle => player.state.track.subtitle;

  Future<Uint8List?> screenshot() =>
      player.screenshot(format: 'image/jpeg');

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    player.dispose();
    super.dispose();
  }
}

// ==================== असली वीडियो प्लेयर ====================
class RealVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int startPosition;
  final List<Map<String, String>>? playlist;
  final int? currentIndex;
  final bool startLandscape;

  const RealVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.startPosition = 0,
    this.playlist,
    this.currentIndex,
    this.startLandscape = false,
  }) : super(key: key);

  @override
  State<RealVideoPlayer> createState() => _RealVideoPlayerState();
}

class _RealVideoPlayerState extends State<RealVideoPlayer>
    with WidgetsBindingObserver {
  late _MkController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _hasError = false;
  String _errorMessage = '';

  double _speed = 1.0;
  double _volume = 1.0;
  double _brightness = 0.8;
  double _dragSeekSeconds = 0;
  bool _isDraggingSeek = false;
  bool _isFullscreen = false;
  bool _replacing = false;
  bool _showGestureIndicator = false;
  String _gestureText = '';
  bool _isLooping = false;
  bool _autoNextTriggered = false;
  bool _locked = false;
  Timer? _sleepTimer;
  String _skipIndicator = '';
  Timer? _skipIndicatorTimer;
  Timer? _gestureTimer;
  bool _muted = false;
  bool _showVideoList = false;
  int _loopMode = 0;
  int _fitMode = 0;
  bool _autoPlayNext = true;

  // 👇👇👇 Subtitle के लिए नए वेरिएबल्स 👇👇👇
List<SubtitleLine> _subtitles = [];
bool _subtitlesEnabled = true;
String? _subtitleFileName;
int _subtitleOffsetMs = 0;
  // PiP में गए तो background में pause मत करो
  bool _pipRequested = false;
  // Pinch-to-zoom
  final Map<int, Offset> _pointers = {};
  double _pinchStartDist = 0;
  double _zoomBase = 1.0;
  double _zoomScale = 1.0;
  bool _pinching = false;
  DateTime _lastPinchAt = DateTime.fromMillisecondsSinceEpoch(0);
  // Video Equalizer (5 band)
  bool _eqEnabled = false;
  List<double> _eqGains = [0, 0, 0, 0, 0];
  static const List<String> _eqLabels = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];
  static const List<int> _eqFreqs = [60, 230, 910, 3600, 14000];
  static const Map<String, List<double>> _eqPresets = {
    'Flat': [0, 0, 0, 0, 0],
    'Bass': [6, 4, 0, -1, -2],
    'Treble': [-2, -1, 0, 4, 6],
    'Vocal': [-2, 0, 4, 3, 0],
    'Rock': [4, 2, -2, 3, 4],
  };
  // A-B repeat
  Duration? _abA;
  Duration? _abB;
  // Rotation lock
  bool _rotationLocked = false;
  // Headphone / call handling
  StreamSubscription? _noisySub;
  StreamSubscription? _interruptSub;
double _subtitleFontSize = 16.0;    // 👈 NAYA
// 👇👇👇 Long-Press 2x Speed के लिए नए वेरिएबल्स 👇👇👇
bool _isLongPressSpeed = false;
double _speedBeforeLongPress = 1.0;
// 👆👆👆 यहाँ तक 👆👆👆
// 👇👇👇 Seek Thumbnail Preview के लिए नए वेरिएबल्स 👇👇👇
Uint8List? _previewThumbnail;
double? _previewSeekPosition;
bool _isSeeking = false;
Timer? _thumbnailDebounce;
// 👆👆👆 यहाँ तक 👆👆👆
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedSpeed();
    if (widget.startLandscape) {
      _isFullscreen = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }

    VolumeController().getVolume().then((v) {
      if (mounted) setState(() => _volume = v.clamp(0.0, 2.0));
    }).catchError((_) {});

    // गाना चल रहा हो तो वीडियो शुरू होते ही उसे रोको (दो आवाज़ें न हों)
    try {
      globalAudioPlayer.pause();
    } catch (_) {}

    // 👇 Default Brightness लोड करो (Settings से)
SharedPreferences.getInstance().then((p) {
  final savedBrightness = p.getDouble('default_brightness');
  if (savedBrightness != null && mounted) {
    setState(() => _brightness = savedBrightness);
    try {
      ScreenBrightness().setScreenBrightness(savedBrightness);
    } catch (_) {}
  } else {
    // अगर सेटिंग नहीं है तो सिस्टम ब्राइटनेस लो
    try {
      ScreenBrightness().current.then((b) {
        if (mounted) setState(() => _brightness = b);
      }).catchError((_) {});
    } catch (_) {}
  }
});
    WakelockPlus.enable();

    SharedPreferences.getInstance().then((p) {
      final mode = p.getInt('video_loop_mode') ?? 0;
      _autoPlayNext = p.getBool('auto_play_next') ?? true;
      if (mounted) {
        setState(() {
          _loopMode = mode;
          _isLooping = (mode == 1);
        });
      }
      if (_isInitialized) _controller.setLooping(mode == 1);
    });

    _controller = _MkController(widget.videoUrl);
    _setupAudioSession();

    _controller.initialize().then((_) async {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      if (widget.startPosition > 0) {
        _controller.seekTo(Duration(seconds: widget.startPosition));
      } else {
        final p = await SharedPreferences.getInstance();
        final saved = p.getInt('resume_${widget.videoUrl}') ?? 0;
        final resumeOn = p.getBool('resume_playback') ?? true;
        if (resumeOn && saved > 0 && mounted) {
          await _controller.seekTo(Duration(seconds: saved));
        }
      }
      if (!mounted) return;
      _controller.setPlaybackSpeed(_speed);
      _controller.setLooping(_isLooping);
      _controller.play();
      _autoLoadSubtitle();              // 👈 NAYA
      await _loadVideoEq();
      _applyVideoEq();
    }).catchError((error) {
      debugPrint('Video initialize error: $error');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
      });
    });

    _controller.addListener(() {
      if (!mounted) return;
      final val = _controller.value;
      // A-B repeat
      if (_abA != null && _abB != null && val.position >= _abB!) {
        _controller.seekTo(_abA!);
      }
      // Reset trigger jab user peeche seek kare
if (_autoNextTriggered &&
    val.isInitialized &&
    val.duration > Duration.zero &&
    val.position < val.duration - const Duration(seconds: 2)) {
  _autoNextTriggered = false;
}
      if (!_isLooping &&
          !_autoNextTriggered &&
          val.isInitialized &&
          val.duration > Duration.zero &&
          val.position >= val.duration - const Duration(milliseconds: 800)) {
        _autoNextTriggered = true;
        if (_hasNext) {
          if (_autoPlayNext) _playNext();
        } else if (_loopMode == 2) {
          if (widget.playlist != null && widget.playlist!.length > 1) {
            _playFirst();
          } else {
            _controller.seekTo(Duration.zero);
            _controller.play();
            _autoNextTriggered = false;
          }
        }
      }
    });
    _startHideTimer();
  }

  Future<void> _loadSavedSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getDouble('video_speed') ?? 1.0;
    if (mounted) setState(() => _speed = s);
    if (_isInitialized) {
      _controller.setPlaybackSpeed(s);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Widget _verticalIndicator({
    required IconData icon,
    required double value,
    required Color color,
    double maxValue = 1.0,
  }) {
    final percent = (value * 100).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: TextStyle(
              color: percent > 100 ? Colors.amber : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 6,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: (value / maxValue).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Icon(icon, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  void _toggleControls() {
    if (_showVideoList) {
      setState(() => _showVideoList = false);
      return;
    }
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  void _togglePlay() {
    if (!_isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  void _seekTo(double seconds) {
    if (!_isInitialized) return;
    _controller.seekTo(Duration(seconds: seconds.toInt()));
  }

  void _showSkipIndicator(String text) {
    _skipIndicatorTimer?.cancel();
    setState(() => _skipIndicator = text);
    _skipIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _skipIndicator = '');
    });
  }

  void _showGestureFor(String text) {
    _gestureTimer?.cancel();
    setState(() {
      _showGestureIndicator = true;
      _gestureText = text;
    });
    _gestureTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showGestureIndicator = false);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _takeScreenshot() async {
    if (!_isInitialized) return;
    try {
      final bytes = await _controller.screenshot();
      if (bytes == null) {
        _snack('Could not take screenshot');
        return;
      }
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.hasAccess) {
        _snack('Gallery permission required');
        return;
      }
      final name = 'VeoPlay_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await PhotoManager.editor.saveImage(
        bytes,
        filename: name,
        title: name,
      );
      _snack('Screenshot saved to Gallery');
    } catch (e) {
      debugPrint('Screenshot error: $e');
      _snack('Error taking screenshot');
    }
  }

  void _playAt(int index) {
    final item = widget.playlist![index];
    _replacing = true;
    final goLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RealVideoPlayer(
          videoUrl: item['url']!,
          title: item['title']!,
          playlist: widget.playlist,
          currentIndex: index,
          startLandscape: goLandscape,
        ),
      ),
    );
  }

  Widget _buildVideoListPanel() {
    final list = widget.playlist;
    final panelWidth =
        (MediaQuery.of(context).size.width * 0.6).clamp(220.0, 320.0).toDouble();
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: panelWidth,
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        list == null ? 'Videos' : 'Videos (${list.length})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _showVideoList = false),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: (list == null || list.isEmpty)
                    ? const Center(
                        child: Text('No video list',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final isCurrent = i == widget.currentIndex;
                          return ListTile(
                            dense: true,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 80,
                                height: 46,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.primaryBlue
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  clipBehavior: Clip.hardEdge,
                                  child: VideoThumbnailWidget(
                                      videoPath: list[i]['url']!),
                                ),
                              ),
                            ),
                            title: Text(
                              list[i]['title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? AppTheme.primaryBlue
                                    : Colors.white,
                              ),
                            ),
                            onTap: isCurrent ? null : () => _playAt(i),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cycleLoop() async {
    final next = (_loopMode + 1) % 3;
    setState(() {
      _loopMode = next;
      _isLooping = (next == 1);
    });
    _controller.setLooping(next == 1);
    _snack(next == 0 ? 'Loop: Off' : (next == 1 ? 'Loop: One' : 'Loop: All'));
    final p = await SharedPreferences.getInstance();
    await p.setInt('video_loop_mode', next);
  }

  // ---------- Pinch-to-zoom ----------
  bool get _pinchBusy =>
      _pinching ||
      DateTime.now().difference(_lastPinchAt) <
          const Duration(milliseconds: 350);

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _pinchStartDist = (pts[0] - pts[1]).distance;
      _zoomBase = _zoomScale;
      _pinching = true;
      _lastPinchAt = DateTime.now();
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pinching && _pointers.length >= 2 && _pinchStartDist > 0) {
      final pts = _pointers.values.toList();
      final dist = (pts[0] - pts[1]).distance;
      final next = (_zoomBase * dist / _pinchStartDist).clamp(1.0, 4.0);
      _lastPinchAt = DateTime.now();
      if ((next - _zoomScale).abs() > 0.01) {
        setState(() => _zoomScale = next);
        _showGestureFor('Zoom ${(next * 100).round()}%');
      }
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      if (_pinching) _lastPinchAt = DateTime.now();
      _pinching = false;
    }
  }

  // ---------- Video Equalizer ----------
  Future<void> _loadVideoEq() async {
    try {
      final p = await SharedPreferences.getInstance();
      _eqEnabled = p.getBool('veq_enabled') ?? false;
      final saved = p.getStringList('veq_gains');
      if (saved != null && saved.length == 5) {
        _eqGains = saved.map((e) => double.tryParse(e) ?? 0.0).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveVideoEq() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('veq_enabled', _eqEnabled);
      await p.setStringList(
          'veq_gains', _eqGains.map((e) => e.toStringAsFixed(1)).toList());
    } catch (_) {}
  }

  Future<void> _applyVideoEq() async {
  try {
    final np = _controller.player.platform as mk.NativePlayer;
    final eqActive = _eqEnabled && _eqGains.any((g) => g.abs() > 0.1);
    final volBoosted = _volume > 1.0; // 👈 NAYA: Check agar volume 100% se zyada hai

    // Agar na EQ on hai, aur na hi volume 100% se zyada hai, toh filter hatao
    if (!eqActive && !volBoosted) {
      await np.setProperty('af', '');
      return;
    }

    final parts = <String>[];
    // 1. Equalizer part
    if (eqActive) {
      for (int i = 0; i < 5; i++) {
        if (_eqGains[i].abs() < 0.1) continue;
        parts.add('equalizer=f=${_eqFreqs[i]}:width_type=o:w=1.5:g=${_eqGains[i].toStringAsFixed(1)}');
      }
    }
    
    // 2. Limiter part (Awaaz faatne se rokne ke liye)
    if (volBoosted) {
      // acompressor ek pro-level limiter hai jo volume ko smooth karta hai
      parts.add('acompressor=threshold=-10dB:ratio=4:attack=5:release=50');
    }

    if (parts.isEmpty) {
      await np.setProperty('af', '');
    } else {
      await np.setProperty('af', 'lavfi=[${parts.join(',')}]');
    }
  } catch (e) {
    debugPrint('Video EQ/Limiter error: $e');
  }
  }
  void _showVideoEqualizer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Equalizer',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Switch(
                        value: _eqEnabled,
                        activeColor: AppTheme.primaryBlue,
                        onChanged: (v) {
                          setSheet(() => _eqEnabled = v);
                          _applyVideoEq();
                          _saveVideoEq();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eqPresets.entries.map((e) {
                      return GestureDetector(
                        onTap: () {
                          setSheet(() {
                            _eqGains = List<double>.of(e.value);
                            _eqEnabled = true;
                          });
                          _applyVideoEq();
                          _saveVideoEq();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(e.key,
                              style: TextStyle(color: AppTheme.textPrimary)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < 5; i++)
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(_eqLabels[i],
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ),
                        Expanded(
                          child: Slider(
                            value: _eqGains[i],
                            min: -12,
                            max: 12,
                            divisions: 24,
                            activeColor: AppTheme.primaryBlue,
                            onChanged: _eqEnabled
                                ? (v) => setSheet(() => _eqGains[i] = v)
                                : null,
                            onChangeEnd: (v) {
                              _applyVideoEq();
                              _saveVideoEq();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text('${_eqGains[i].round()} dB',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setSheet(() => _eqGains = [0, 0, 0, 0, 0]);
                        _applyVideoEq();
                        _saveVideoEq();
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Bookmarks ----------
  String get _bmKey => 'bookmarks_${widget.videoUrl}';

  Future<List<int>> _readBookmarks() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = (p.getStringList(_bmKey) ?? [])
          .map((e) => int.tryParse(e) ?? -1)
          .where((e) => e >= 0)
          .toSet()
          .toList();
      list.sort();
      return list;
    } catch (_) {
      return <int>[];
    }
  }

  Future<void> _writeBookmarks(List<int> list) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_bmKey, list.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  Future<void> _showBookmarks() async {
    final marks = await _readBookmarks();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Bookmarks',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final now = _controller.value.position.inSeconds;
                          if (marks.any((m) => (m - now).abs() < 2)) {
                            _snack('This bookmark already exists');
                            return;
                          }
                          setSheet(() {
                            marks.add(now);
                            marks.sort();
                          });
                          await _writeBookmarks(marks);
                        },
                        icon: const Icon(Icons.bookmark_add),
                        label: const Text('Add here'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (marks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No bookmarks yet.\nTap "Add here" at the point in the video you want to save.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: marks.length,
                        itemBuilder: (_, i) {
                          final sec = marks[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.bookmark,
                                color: AppTheme.primaryBlue),
                            title: Text(
                              _formatDuration(Duration(seconds: sec)),
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: AppTheme.iconColor),
                              onPressed: () async {
                                setSheet(() => marks.removeAt(i));
                                await _writeBookmarks(marks);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _controller.seekTo(Duration(seconds: sec));
                              _showGestureFor(
                                  '🔖 ${_formatDuration(Duration(seconds: sec))}');
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _cycleFit() {
    setState(() {
      _fitMode = (_fitMode + 1) % 3;
      _zoomScale = 1.0;
    });
    _snack(_fitMode == 0
        ? 'Fit'
        : (_fitMode == 1 ? 'Zoom (Fill)' : 'Stretch'));
  }

  void _playFirst() => _playAt(0);

  void _openDual() {
    final list = widget.playlist;
    if (list == null || list.length < 2) {
      _snack('Need at least 2 videos in the list for Dual mode');
      return;
    }
    final i1 = widget.currentIndex ?? 0;
    final i2 = (i1 + 1 < list.length) ? i1 + 1 : 0;
    final pos = _controller.value.position.inSeconds;
    _controller.pause();
    _replacing = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DualVideoScreen(
          playlist: list,
          index1: i1,
          index2: i2,
          startPosition1: pos,
        ),
      ),
    );
  }

  Future<void> _saveResume(String url, int pos, int dur) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'resume_$url';
    if (pos >= 5 && (dur <= 0 || pos < dur - 3)) {
      await prefs.setInt(key, pos);
    } else {
      await prefs.remove(key);
    }
  }

  Widget _sideBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0.0 : (_volume > 1.0 ? _volume : 1.0));
  }

  // 0–100%: phone की volume, 100–200%: असली software boost (mpv)
  void _applyVolume(double newVol) {
  final v = newVol.clamp(0.0, 2.0);
  if (v <= 1.0) {
    VolumeController().setVolume(v, showSystemUI: false);
    _controller.setVolume(1.0);
  } else {
    VolumeController().setVolume(1.0, showSystemUI: false);
    _controller.setVolume(v);
  }
  
  // 👇 NAYA: Jab bhi volume change ho, limiter ko update karo
  _applyVideoEq(); 
  }
  void _skipForward() {
    if (!_isInitialized) return;
    final newPos = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPos);
    _showSkipIndicator('+10s');
  }

  void _skipBackward() {
    if (!_isInitialized) return;
    var newPos = _controller.value.position - const Duration(seconds: 10);
    if (newPos < Duration.zero) newPos = Duration.zero;
    _controller.seekTo(newPos);
    _showSkipIndicator('-10s');
  }

  // 👇 NAYA FIXED CODE: URL ke basis par next/prev dhundhega
bool get _hasNext {
  if (widget.playlist == null || widget.videoUrl.isEmpty) return false;
  final idx = widget.playlist!.indexWhere((v) => v['url'] == widget.videoUrl);
  return idx != -1 && idx < widget.playlist!.length - 1;
}

bool get _hasPrevious {
  if (widget.playlist == null || widget.videoUrl.isEmpty) return false;
  final idx = widget.playlist!.indexWhere((v) => v['url'] == widget.videoUrl);
  return idx > 0;
}

void _playNext() {
  if (!_hasNext) return;
  final currentUrl = widget.videoUrl;
  final currentIndex = widget.playlist!.indexWhere((v) => v['url'] == currentUrl);
  final nextIndex = currentIndex + 1;
  final nextItem = widget.playlist![nextIndex];
  
  _replacing = true;
  final goLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => RealVideoPlayer(
        videoUrl: nextItem['url']!,
        title: nextItem['title']!,
        playlist: widget.playlist,
        currentIndex: nextIndex, 
        startLandscape: goLandscape,
      ),
    ),
  );
}

void _playPrevious() {
  if (!_hasPrevious) return;
  final currentUrl = widget.videoUrl;
  final currentIndex = widget.playlist!.indexWhere((v) => v['url'] == currentUrl);
  final prevIndex = currentIndex - 1;
  final prevItem = widget.playlist![prevIndex];
  
  _replacing = true;
  final goLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => RealVideoPlayer(
        videoUrl: prevItem['url']!,
        title: prevItem['title']!,
        playlist: widget.playlist,
        currentIndex: prevIndex,
        startLandscape: goLandscape,
      ),
    ),
  );
}

double _audioDelay = 0.0; // Class variables me isko add kar lena

void _showSyncDialog() {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Audio / Video Sync', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Audio Delay: ${_audioDelay.toStringAsFixed(1)}s',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Slider(
              value: _audioDelay,
              min: -5.0,
              max: 5.0,
              divisions: 50,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setDialogState(() => _audioDelay = v);
                _controller.setAudioDelay(v);
              },
            ),
            Text(
  'If audio is ahead of video, use + to delay it.\nIf audio is behind video, use - to advance it.',
  textAlign: TextAlign.center,
  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setDialogState(() => _audioDelay = 0.0);
              _controller.setAudioDelay(0.0);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}
  
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Playback Speed',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                  final selected = speed == _speed;
                  return GestureDetector(
                    onTap: () async {
                      _controller.setPlaybackSpeed(speed);
                      setState(() => _speed = speed);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('video_speed', speed);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryBlue
                            : AppTheme.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
          if (_locked) {
      _showControls = false;
    } else {
      _startHideTimer();
    }
  });
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_locked ? "🔒 Locked" : "🔓 Unlocked"),
      duration: const Duration(seconds: 1),
    ),
  );
}

// 👇 नया Sleep Timer Dialog (Playback Speed जैसा)
void _showSleepTimerDialog() {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Sleep Timer",
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [5, 10, 15, 30, 60].map((min) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _startSleepTimer(min);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer,
                            color: AppTheme.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text('$min min',
                            style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _sleepTimer?.cancel();
                _sleepTimer = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sleep timer removed')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Remove Sleep Timer',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _startSleepTimer(int minutes) {
  _sleepTimer?.cancel();
  _sleepTimer = Timer(Duration(minutes: minutes), () {
    if (mounted) {
      _controller.pause();
      setState(() {});  // UI update for play icon
      _snack('😴 Sleep timer: video paused');
    }
  });
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Video will pause in $minutes minutes')),
  );
}

Future<void> _enterPip() async {
  final available = await SimplePip.isPipAvailable;
  if (!available) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PiP is not supported on this device'),
        ),
      );
    }
    return;
  }
  _pipRequested = true;
  await SimplePip().enterPipMode();
}

Future<void> _shareVideo() async {
  try {
    final path = widget.videoUrl.replaceFirst('file://', '');
    if (!path.startsWith('http') &&
        !path.startsWith('content://') &&
        await File(path).exists()) {
      await Share.shareXFiles([XFile(path)], subject: widget.title);
    } else {
      await Share.share(
        '${widget.title}\n${widget.videoUrl}',
        subject: widget.title,
      );
    }
  } catch (e) {
    debugPrint('Share error: $e');
  }
}

// 👇👇👇 Seek के दौरान Thumbnail Generate करो 👇👇👇
Future<void> _generatePreviewThumbnail(double seconds) async {
  // पुराना debounce cancel करो
  _thumbnailDebounce?.cancel();
  
  // 200ms का debounce लगाओ ताकि बार-बार generate न हो
  _thumbnailDebounce = Timer(const Duration(milliseconds: 200), () async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        timeMs: (seconds * 1000).toInt(),
        maxWidth: 160,
        quality: 50,
      );
      if (mounted && _isSeeking) {
        setState(() {
          _previewThumbnail = bytes;
        });
      }
    } catch (e) {
      debugPrint('Preview thumbnail error: $e');
    }
  });
}
  
Future<void> _loadSubtitle() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
    );

    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final content = utf8.decode(
      await File(filePath).readAsBytes(),
      allowMalformed: true,
    );
    final ext = filePath.split('.').last.toLowerCase();

    if (ext == 'ass' || ext == 'ssa') {
      await _controller.setSubtitleTrack(
        mk.SubtitleTrack.data(content, title: result.files.single.name),
      );
      if (!mounted) return;
      setState(() {
        _subtitles = [];
        _subtitleFileName = result.files.single.name;
        _subtitlesEnabled = true;
        _controller.isExternalSubtitle = true;
      });
      _snack('✅ ASS/SSA subtitle loaded');
      return;
    }

    // SRT/VTT के लिए मौजूदा parser
    final parsed = _parseSrt(content);
    if (parsed.isEmpty) {
      _snack('Subtitle file is empty or unreadable');
      return;
    }

    setState(() {
      _subtitles = parsed;
      _subtitleFileName = result.files.single.name;
      _subtitlesEnabled = true;
      _controller.isExternalSubtitle = true;
    });
    await _controller.setSubtitleTrack(mk.SubtitleTrack.no());

    _snack('✅ ${parsed.length} subtitles loaded');
  } catch (e) {
    debugPrint('Subtitle load error: $e');
    _snack('Could not load subtitle');
  }
}

Future<void> _autoLoadSubtitle() async {
  try {
    final url = widget.videoUrl;
    // content:// और network URLs के लिए sibling file path उपलब्ध नहीं होता
    if (url.startsWith('content://') || url.startsWith('http')) return;
    if (!url.contains('.')) return;

    final videoPath = url.replaceFirst('file://', '');
    final dotIdx = videoPath.lastIndexOf('.');
    if (dotIdx < 0) return;
    final basePath = videoPath.substring(0, dotIdx);

    // Same folder में SRT, VTT, ASS और SSA formats खोजें
    for (final ext in [
      '.srt', '.SRT', '.vtt', '.VTT',
      '.ass', '.ASS', '.ssa', '.SSA',
    ]) {
      final subtitlePath = '$basePath$ext';
      final file = File(subtitlePath);
      if (!await file.exists()) continue;

      final content = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      final fileName = subtitlePath.split('/').last;
      final lowerExt = ext.toLowerCase();

      if (lowerExt == '.ass' || lowerExt == '.ssa') {
        await _controller.setSubtitleTrack(
          mk.SubtitleTrack.data(content, title: fileName),
        );
        if (!mounted) return;
        setState(() {
          _subtitles = [];
          _subtitleFileName = fileName;
          _subtitlesEnabled = true;
          _controller.isExternalSubtitle = true;
        });
      } else {
        final parsed = _parseSrt(content);
        if (parsed.isEmpty) return;
        if (!mounted) return;
        setState(() {
          _subtitles = parsed;
          _subtitleFileName = fileName;
          _subtitlesEnabled = true;
          _controller.isExternalSubtitle = true;
        });
        await _controller.setSubtitleTrack(mk.SubtitleTrack.no());
      }

      _snack('✅ Subtitle auto-loaded: $fileName');
      return; // पहला matching subtitle load करके रुकें
    }
  } catch (e) {
    debugPrint('Auto subtitle error: $e');
  }
}

// 👇👇👇 SRT/VTT Parser 👇👇👇
List<SubtitleLine> _parseSrt(String content) {
  final result = <SubtitleLine>[];
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  int i = 0;

  Duration? parseTime(String s) {
    // SRT: 00:00:01,000   VTT: 00:01.000 या 00:00:01.000 (+ settings)
    final clean = s.trim().split(RegExp(r'\s+')).first.replaceAll(',', '.');
    final parts = clean.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final h = parts.length == 3 ? (int.tryParse(parts[0]) ?? 0) : 0;
    final m = int.tryParse(parts[parts.length - 2]) ?? 0;
    final sp = parts.last.split('.');
    final sec = int.tryParse(sp[0]) ?? 0;
    final ms = sp.length > 1
        ? int.tryParse(sp[1].padRight(3, '0').substring(0, 3)) ?? 0
        : 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
  }

  while (i < lines.length) {
    // खाली लाइन्स स्किप करो
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) break;

    // इंडेक्स नंबर स्किप करो (सिर्फ SRT में)
    if (int.tryParse(lines[i].trim()) != null) {
      i++;
    }
    if (i >= lines.length) break;

    // टाइम लाइन पार्स करो
    final timeLine = lines[i].trim();
    if (!timeLine.contains('-->')) {
      i++;
      continue;
    }
    final timeParts = timeLine.split('-->');
    final start = parseTime(timeParts[0]);
    final end = parseTime(timeParts[1]);
    i++;

    // टेक्स्ट लाइन्स इकट्ठा करो
    final textLines = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      textLines.add(lines[i].trim());
      i++;
    }

    if (start != null && end != null && textLines.isNotEmpty) {
      result.add(SubtitleLine(
        start: start,
        end: end,
        text: textLines.join('\n').replaceAll(RegExp(r'<[^>]*>'), ''),
      ));
    }
  }
  return result;
}

// 👇👇👇 Current Subtitle ढूंढो 👇👇👇
String? _getCurrentSubtitle() {
  if (!_subtitlesEnabled || _subtitles.isEmpty) return null;
  final offset = _controller.isExternalSubtitle
      ? Duration(milliseconds: _subtitleOffsetMs)
      : Duration(milliseconds: -_subtitleOffsetMs);
  final pos = _controller.value.position + offset;
  for (final s in _subtitles) {
    if (pos >= s.start && pos <= s.end) {
      return s.text;
    }
  }
  return null;
}

void _showSubtitleSettingsDialog() {
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Subtitle Settings',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Font Size ---
              Text('Font Size: ${_subtitleFontSize.toInt()}',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              Row(
                children: [
                  Text('A',
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _subtitleFontSize,
                      min: 12,
                      max: 28,
                      divisions: 16,
                      activeColor: AppTheme.primaryBlue,
                      onChanged: (v) {
                        setDialogState(() => _subtitleFontSize = v);
                        setState(() {});
                      },
                    ),
                  ),
                  Text('A',
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 22)),
                ],
              ),
              const Divider(height: 24),

              // --- Timing Offset ---
              Text(
                'Timing Offset: ${_subtitleOffsetMs > 0 ? "+" : ""}${(_subtitleOffsetMs / 1000).toStringAsFixed(1)}s',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _offsetBtn('-1s', () {
                    setDialogState(() => _subtitleOffsetMs -= 1000);
                    _controller.setSubtitleDelay(_subtitleOffsetMs / 1000);
                    setState(() {});
                  }),
                  const SizedBox(width: 6),
                  _offsetBtn('-0.5s', () {
                    setDialogState(() => _subtitleOffsetMs -= 500);
                    _controller.setSubtitleDelay(_subtitleOffsetMs / 1000);
                    setState(() {});
                  }),
                  const SizedBox(width: 6),
                  _offsetBtn('Reset', () {
                    setDialogState(() => _subtitleOffsetMs = 0);
                    _controller.setSubtitleDelay(_subtitleOffsetMs / 1000);
                    setState(() {});
                  }),
                  const SizedBox(width: 6),
                  _offsetBtn('+0.5s', () {
                    setDialogState(() => _subtitleOffsetMs += 500);
                    _controller.setSubtitleDelay(_subtitleOffsetMs / 1000);
                    setState(() {});
                  }),
                  const SizedBox(width: 6),
                  _offsetBtn('+1s', () {
                    setDialogState(() => _subtitleOffsetMs += 1000);
                    _controller.setSubtitleDelay(_subtitleOffsetMs / 1000);
                    setState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 16),
              if (_subtitleFileName != null)
                Text('File: $_subtitleFileName',
                    style: TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadSubtitle();
            },
            child: Text('Load New',
                style: TextStyle(color: AppTheme.primaryBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done'),
          ),
        ],
      ),
    ),
  );
}

Widget _offsetBtn(String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text(label,
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    ),
  );
}
  
// 👇 Play as audio का असली लॉजिक
Future<void> _playAsAudio() async {
  if (!_isInitialized) return;

  try {
    final currentPos = _controller.value.position;

    await _controller.pause();

    Uri audioUri;
    if (widget.videoUrl.startsWith('http') ||
        widget.videoUrl.startsWith('content://') ||
        widget.videoUrl.startsWith('file://')) {
      audioUri = Uri.parse(widget.videoUrl);
    } else {
      audioUri = Uri.file(widget.videoUrl);
    }

    final source = AudioSource.uri(
      audioUri,
      tag: MediaItem(
        id: widget.videoUrl,
        album: 'VeoPlay',
        title: widget.title,
        artist: 'Audio Mode',
      ),
    );

    await globalAudioPlayer.setAudioSource(source);
    if (currentPos > Duration.zero) {
      await globalAudioPlayer.seek(currentPos);
    }
    await globalAudioPlayer.play();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 "${widget.title}" is playing in audio mode'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    debugPrint('Play as audio error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not play in audio mode'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

Future<void> _showAudioTrackPicker() async {
  final tracks = _controller.realAudioTracks;
  if (tracks.length < 2) {
    _snack(tracks.isEmpty
        ? 'No audio track information found for this video'
        : 'This video has only one audio track');
    return;
  }
  final current = _controller.currentAudio.id;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Audio Track',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          for (int i = 0; i < tracks.length; i++)
            ListTile(
              leading: Icon(Icons.audiotrack, color: AppTheme.iconColor),
              title: Text(_trackName(tracks[i].title, tracks[i].language, i),
                  style: TextStyle(color: AppTheme.textPrimary)),
              trailing: tracks[i].id == current
                  ? Icon(Icons.check, color: AppTheme.primaryBlue)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await _controller.setAudioTrack(tracks[i]);
                  _snack('Audio track changed');
                } catch (e) {
                  _snack('Could not change audio track');
                }
              },
            ),
        ],
      ),
    ),
  );
}

String _trackName(String? title, String? language, int i) {
  if (title != null && title.isNotEmpty) return title;
  if (language != null && language.isNotEmpty && language != 'und') {
    return language;
  }
  return 'Track ${i + 1}';
}

// वीडियो के अंदर वाले subtitle tracks
void _showSubtitleTrackPicker() {
  final tracks = _controller.realSubtitleTracks;
  final current = _controller.currentSubtitle.id;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Subtitle Track',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(Icons.subtitles_off, color: AppTheme.iconColor),
            title: Text('Off', style: TextStyle(color: AppTheme.textPrimary)),
            trailing: (current == 'no' && _subtitles.isEmpty)
                ? Icon(Icons.check, color: AppTheme.primaryBlue)
                : null,
            onTap: () async {
              Navigator.pop(sheetContext);
              await _controller.setSubtitleTrack(mk.SubtitleTrack.no());
              if (mounted) {
                setState(() {
                  _subtitles = [];
                  _subtitleFileName = null;
                  _controller.isExternalSubtitle = false;
                });
              }
            },
          ),
          for (int i = 0; i < tracks.length; i++)
            ListTile(
              leading: Icon(Icons.subtitles, color: AppTheme.iconColor),
              title: Text(_trackName(tracks[i].title, tracks[i].language, i),
                  style: TextStyle(color: AppTheme.textPrimary)),
              trailing: (tracks[i].id == current && _subtitles.isEmpty)
                  ? Icon(Icons.check, color: AppTheme.primaryBlue)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                await _controller.setSubtitleTrack(tracks[i]);
                if (mounted) {
                  setState(() {
                    _subtitles = [];
                    _subtitleFileName = null;
                    _subtitlesEnabled = true;
                    _controller.isExternalSubtitle = false;
                  });
                }
              },
            ),
          ListTile(
            leading: Icon(Icons.folder_open, color: AppTheme.iconColor),
            title: Text('Load from file (.srt / .vtt / .ass / .ssa)',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(sheetContext);
              _loadSubtitle();
            },
          ),
        ],
      ),
    ),
  );
}

// A-B repeat: पहला tap = A, दूसरा = B, तीसरा = बंद
void _toggleAbRepeat() {
  final pos = _controller.value.position;
  setState(() {
    if (_abA == null) {
      _abA = pos;
      _snack('A set: ${_formatDuration(pos)}');
    } else if (_abB == null) {
      if (pos <= _abA!) {
        _snack('B must be after A');
      } else {
        _abB = pos;
        _snack('B set: A-B repeat on');
      }
    } else {
      _abA = null;
      _abB = null;
      _snack('A-B repeat off');
    }
  });
}

// Video info dialog
void _showVideoInfo() {
  final v = _controller.value;
  final audio = _controller.currentAudio;
  String row(String k, String val) => '$k: $val';
  final lines = <String>[
    row('Name', widget.title),
    row('Resolution',
        v.size.width > 0 ? '${v.size.width.toInt()}x${v.size.height.toInt()}' : '—'),
    row('Duration', _formatDuration(v.duration)),
    row('Audio tracks', '${_controller.realAudioTracks.length}'),
    row('Embedded subtitles', '${_controller.realSubtitleTracks.length}'),
    row('Speed', '${_speed}x'),
    row('Audio', _trackName(audio.title, audio.language, 0)),
    row('Path', widget.videoUrl),
  ];
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text('Video Info', style: TextStyle(color: AppTheme.textPrimary)),
      content: SingleChildScrollView(
        child: SelectableText(lines.join('\n\n'),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

// Rotation lock
void _toggleRotationLock() {
  final landscape =
      MediaQuery.of(context).orientation == Orientation.landscape;
  setState(() => _rotationLocked = !_rotationLocked);
  if (_rotationLocked) {
    SystemChrome.setPreferredOrientations(landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    _snack('Rotation locked');
  } else {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _snack('Rotation unlocked');
  }
}

// Headphone निकलने / call आने पर pause
Future<void> _setupAudioSession() async {
  try {
    final session = await AudioSession.instance;
    await session.setActive(true);
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      if (_isInitialized) _controller.pause();
    });
    _interruptSub = session.interruptionEventStream.listen((event) {
      if (event.begin && _isInitialized) _controller.pause();
    });
  } catch (e) {
    debugPrint('Audio session error: $e');
  }
}

void _showMoreOptionsMenu() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 👇👇👇 Load Subtitle वाला नया ListTile 👇👇👇
ListTile(
  leading: Icon(
    _subtitles.isNotEmpty
        ? Icons.subtitles
        : Icons.subtitles_off,
    color: AppTheme.iconColor,
  ),
  title: Text(
    _subtitles.isEmpty
        ? 'Load Subtitle (.srt)'
        : (_subtitlesEnabled
            ? 'Subtitles ON'
            : 'Subtitles OFF'),
    style: TextStyle(color: AppTheme.textPrimary),
  ),
  onTap: () {
    Navigator.pop(context);
    if (_subtitles.isEmpty) {
      _loadSubtitle();
    } else {
      setState(() {
        _subtitlesEnabled = !_subtitlesEnabled;
      });
      _snack(_subtitlesEnabled
          ? 'Subtitles ON'
          : 'Subtitles OFF');
    }
  },
),
// 👇 Subtitle Settings (sirf jab subtitle loaded ho)
if (_subtitles.isNotEmpty || _controller.realSubtitleTracks.isNotEmpty)
  ListTile(
    leading: Icon(Icons.tune, color: AppTheme.iconColor),
    title: Text('Subtitle Settings',
        style: TextStyle(color: AppTheme.textPrimary)),
    subtitle: Text(
      'Size: ${_subtitleFontSize.toInt()} • Offset: ${_subtitleOffsetMs > 0 ? "+" : ""}${(_subtitleOffsetMs / 1000).toStringAsFixed(1)}s',
      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
    ),
    onTap: () {
      Navigator.pop(context);
      _showSubtitleSettingsDialog();
    },
  ),

         ListTile(
  leading: Icon(Icons.sync, color: AppTheme.iconColor),
  title: Text('Audio/Video Sync', style: TextStyle(color: AppTheme.textPrimary)),
  onTap: () {
    Navigator.pop(context);
    _showSyncDialog();
  },
),
          
          ListTile(
            leading: Icon(Icons.closed_caption, color: AppTheme.iconColor),
            title: Text('Subtitle Track',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showSubtitleTrackPicker();
            },
          ),
          ListTile(
            leading: Icon(Icons.repeat_one, color: AppTheme.iconColor),
            title: Text(
                _abA == null
                    ? 'A-B Repeat'
                    : (_abB == null ? 'A-B Repeat (set B)' : 'Turn off A-B Repeat'),
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _toggleAbRepeat();
            },
          ),
          ListTile(
            leading: Icon(
                _rotationLocked ? Icons.screen_lock_rotation : Icons.screen_rotation,
                color: AppTheme.iconColor),
            title: Text(_rotationLocked ? 'Unlock Rotation' : 'Lock Rotation',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _toggleRotationLock();
            },
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: AppTheme.iconColor),
            title: Text('Video Info',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showVideoInfo();
            },
          ),
          ListTile(
            leading: Icon(Icons.audiotrack, color: AppTheme.iconColor),
            title: Text('Audio Track',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showAudioTrackPicker();
            },
          ),
          ListTile(
            leading: Icon(Icons.share, color: AppTheme.iconColor),
            title: Text('Share',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _shareVideo();
            },
          ),
          ListTile(
            leading: Icon(Icons.bookmark_border, color: AppTheme.iconColor),
            title: Text('Bookmarks',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showBookmarks();
            },
          ),
          ListTile(
            leading: Icon(Icons.equalizer, color: AppTheme.iconColor),
            title: Text('Equalizer',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showVideoEqualizer();
            },
          ),
          ListTile(
            leading: Icon(Icons.timer, color: AppTheme.iconColor),
            title: Text('Sleep Timer',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showSleepTimerDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.music_note, color: AppTheme.iconColor),
            title: Text('Play as audio',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _playAsAudio();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    ),
  );
}

Future<void> _saveProgress() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('recent_title', widget.title);
  await prefs.setString('recent_url', widget.videoUrl);
  await prefs.setInt('recent_position', _controller.value.position.inSeconds);
  await prefs.setInt('recent_duration', _controller.value.duration.inSeconds);
  recentChangedNotifier.value++;
}

Future<void> _saveProgressData(
    String title, String url, int pos, int dur) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('recent_title', title);
  await prefs.setString('recent_url', url);
  await prefs.setInt('recent_position', pos);
  await prefs.setInt('recent_duration', dur);
  recentChangedNotifier.value++;
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _pipRequested = false;
  }
  
  // 👇 NAYA FIX: Jab app background me jaye toh Auto-PiP chalu ho jaye
  if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
    if (_isInitialized && !_locked && _controller.value.isPlaying) {
      _enterPip(); // Ye function pehle se aapke paas hai
    } else if (_isInitialized && !_pipRequested) {
      _controller.pause(); // Agar PiP support nahi hai toh pause ho jaye
    }
  }
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _noisySub?.cancel();
  _interruptSub?.cancel();
  final title = widget.title;
  final url = widget.videoUrl;
  final position = _controller.value.position.inSeconds;
  final duration = _controller.value.duration.inSeconds;

  _hideTimer?.cancel();
  _sleepTimer?.cancel();
  _skipIndicatorTimer?.cancel();
  _gestureTimer?.cancel();
  _thumbnailDebounce?.cancel(); // 👈 ये नई लाइन
  _controller.dispose();
  if (!_replacing) {
    WakelockPlus.disable();
    try {
      ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  if (position >= 5) {
    final finished = duration > 0 && position >= duration - 3;
    _saveProgressData(title, url, finished ? 0 : position, duration);
  }
  _saveResume(url, position, duration);
  super.dispose();
}

Future<void> _onPipAction(PipAction action) async {
  switch (action) {
    case PipAction.play:
      _controller.play();
      setState(() {});
      break;
    case PipAction.pause:
      _controller.pause();
      setState(() {});
      break;
    case PipAction.next:
      if (_hasNext) {
        if (mounted) _playNext();
      }
      break;
    case PipAction.previous:
      if (_hasPrevious) {
        if (mounted) _playPrevious();
      }
      break;
    default:
      break;
  }
}

Widget _buildPipView() {
  if (!_isInitialized) {
    return const ColoredBox(color: Colors.black);
  }
  return Container(
    color: Colors.black,
    child: Center( // 👈 Yahan Center add kiya
      child: mkv.Video(
        controller: _controller.video,
        alignment: Alignment.center, // 👈 Ye line add ki
        fit: BoxFit.contain,         // 👈 Ye line add ki
        controls: mkv.NoVideoControls,
        fill: Colors.black,
        wakelock: false,
        subtitleViewConfiguration:
            const mkv.SubtitleViewConfiguration(visible: false),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  return PipWidget(
    pipLayout: PipActionsLayout.media,
    onPipAction: _onPipAction,
    pipChild: _buildPipView(),
    child: _buildPlayer(context),
  );
}

  Widget _buildPlayer(BuildContext context) {
    // 👇 NAYA FIX: System back button ko intercept karne ke liye PopScope
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final position = _controller.value.position.inSeconds;
        final duration = _controller.value.duration.inSeconds;
        if (position >= 5) {
          _saveProgress();
          Navigator.pop(context, {
            'title': widget.title,
            'url': widget.videoUrl,
            'position': position,
            'duration': duration,
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold( // 👈 Yahan se purana Scaffold shuru hota hai
        backgroundColor: Colors.black,
        body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      "Could not open video",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Go Back"),
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue),
                )
                                 : Stack( // 👈 Video aur Spinner ko ek saath rakhne ke liye Stack
                    children: [
                      // 1. Video ka main hissa (Listener)
                      Listener( // 👈 Yahan jo extra colon (:) tha, wo hata diya gaya hai
                        behavior: HitTestBehavior.translucent,
                  onPointerDown: _locked ? null : _onPointerDown,
                  onPointerMove: _locked ? null : _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerUp,
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _locked ? null : _toggleControls,
                  onLongPressStart: _locked
                      ? null
                      : (details) {
                          setState(() {
                            _speedBeforeLongPress = _speed;
                            _isLongPressSpeed = true;
                          });
                          _controller.setPlaybackSpeed(2.0);
                        },
                  onLongPressEnd: _locked
                      ? null
                      : (details) {
                          setState(() {
                            _isLongPressSpeed = false;
                          });
                          _controller.setPlaybackSpeed(_speedBeforeLongPress);
                        },
                  onLongPressCancel: _locked
                      ? null
                      : () {
                          setState(() {
                            _isLongPressSpeed = false;
                          });
                          _controller.setPlaybackSpeed(_speedBeforeLongPress);
                        },
                  onDoubleTapDown: _locked
                      ? null
                      : (details) {
                          final w = MediaQuery.of(context).size.width;
                          final x = details.globalPosition.dx;
                          if (x < w / 3) {
                            _skipBackward();
                          } else if (x > w * 2 / 3) {
                            _skipForward();
                          } else {
                            _togglePlay();
                          }
                        },
                  onVerticalDragUpdate: _locked
                      ? null
                      : (details) {
                          if (_pinchBusy) return;
                          final screenWidth =
                              MediaQuery.of(context).size.width;
                          final dx = details.globalPosition.dx;
                          final delta = -details.delta.dy / 200;
                          if (dx < screenWidth / 2) {
                            final newBrightness =
                                (_brightness + delta).clamp(0.0, 1.0);
                            ScreenBrightness()
                                .setScreenBrightness(newBrightness);
                            setState(() => _brightness = newBrightness);
                            _showGestureFor(
                                'Brightness ${(newBrightness * 100).toInt()}%');
                          } else {
                            double newVol = (_volume + delta).clamp(0.0, 2.0);
_applyVolume(newVol);
                            setState(() {
                              _volume = newVol;
                              _muted = false;
                              _showGestureFor(
                                  'Volume ${(newVol * 100).toInt()}%');
                            });
                          }
                        },
                  onHorizontalDragStart: _locked
                      ? null
                      : (details) {
                          setState(() {
                            _isDraggingSeek = true;
                          });
                        },
                  onHorizontalDragUpdate: _locked
                      ? null
                      : (details) {
                          if (_pinchBusy) return;
                          setState(() {
                            _dragSeekSeconds += details.delta.dx / 5;
                          });
                        },
                  onHorizontalDragEnd: _locked
                      ? null
                      : (details) {
                          if (_pinchBusy) {
                            setState(() {
                              _isDraggingSeek = false;
                              _dragSeekSeconds = 0;
                            });
                            return;
                          }
                          final newPos = _controller.value.position +
                              Duration(seconds: _dragSeekSeconds.toInt());
                          var target = newPos;
                          if (target < Duration.zero) target = Duration.zero;
                          if (target > _controller.value.duration) {
                            target = _controller.value.duration;
                          }
                          _controller.seekTo(target);
                          setState(() {
                            _isDraggingSeek = false;
                            _dragSeekSeconds = 0;
                          });
                        },
                  child: Stack(
                    children: [
                      // ----- वीडियो -----
Positioned.fill(
  child: Transform.scale(
    scale: _zoomScale,
    // 👇 NAYA FIX: Center aur FittedBox taaki video ekdum beech me rahe
    child: Center(
      child: FittedBox(
        fit: _fitMode == 0
            ? BoxFit.contain
            : (_fitMode == 1 ? BoxFit.cover : BoxFit.fill),
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: mkv.Video(
            controller: _controller.video,
            alignment: Alignment.center, // 👈 Bas ye line add kar do
            controls: mkv.NoVideoControls,
            fill: Colors.black,
            wakelock: false,
            // fit yahan nahi dena hai, FittedBox handle karega
            subtitleViewConfiguration:
                mkv.SubtitleViewConfiguration(
              visible: _subtitlesEnabled && _subtitles.isEmpty,
              style: TextStyle(
                color: Colors.white,
                fontSize: _subtitleFontSize,
                fontWeight: FontWeight.w500,
                backgroundColor: const Color(0xB3000000),
              ),
              textAlign: TextAlign.center,
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, _showControls ? 130 : 40),
            ),
          ),
        ),
      ),
    ),
  ),
),
                      
                      // ----- Skip Indicator -----
                      if (_skipIndicator.isNotEmpty)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _skipIndicator.startsWith('+')
                                      ? Icons.fast_forward
                                      : Icons.fast_rewind,
                                  color: AppTheme.primaryBlue,
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _skipIndicator,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ----- Gesture Indicator (Volume/Brightness) -----
                      if (_showGestureIndicator)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_gestureText.contains('Brightness'))
                                  _verticalIndicator(
                                    icon: Icons.brightness_6,
                                    value: _brightness,
                                    color: AppTheme.primaryBlue,
                                  ),
                                if (_gestureText.contains('Volume'))
                                  _verticalIndicator(
                                    icon: Icons.volume_up,
                                    value: _volume,
                                    color: AppTheme.primaryBlue,
                                    maxValue: 2.0,
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // ----- Drag Seek Indicator -----
                      if (_isDraggingSeek)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _dragSeekSeconds >= 0
                                      ? Icons.fast_forward
                                      : Icons.fast_rewind,
                                  color: AppTheme.primaryBlue,
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dragSeekSeconds >= 0
                                      ? '+${_formatDuration(Duration(seconds: _dragSeekSeconds.toInt()))}'
                                      : '-${_formatDuration(Duration(seconds: _dragSeekSeconds.abs().toInt()))}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ----- 2x Speed Indicator -----
                      if (_isLongPressSpeed)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 60,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fast_forward,
                                      color: AppTheme.primaryBlue, size: 20),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '2x Speed',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ----- Seek Thumbnail Preview -----
                      if (_isSeeking && _previewThumbnail != null)
                        Positioned(
                          bottom: _showControls ? 140 : 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryBlue,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      _previewThumbnail!,
                                      width: 160,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                  if (_previewSeekPosition != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDuration(Duration(
                                          seconds:
                                              _previewSeekPosition!.toInt())),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ----- Subtitle Display Overlay -----
if (_subtitlesEnabled && _subtitles.isNotEmpty)
  Positioned(
    left: 20,
    right: 20,
    bottom: _showControls ? 130 : 40,
    child: IgnorePointer(
      // 👇 AnimatedBuilder use karo taaki sirf ye part update ho
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final text = _getCurrentSubtitle();
          if (text == null || text.isEmpty) {
            return const SizedBox.shrink();
          }
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _subtitleFontSize,
                  fontWeight: FontWeight.w500,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ),
                      // ----- टॉप बार -----
                      if (_showControls && !_locked)
                        Positioned(
                          top: MediaQuery.of(context).padding.top,
                          left: 8,
                          right: 8,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                onPressed: () {
                                  final position =
                                      _controller.value.position.inSeconds;
                                  final duration =
                                      _controller.value.duration.inSeconds;
                                  if (position >= 5) {
                                    _saveProgress();
                                    Navigator.pop(context, {
                                      'title': widget.title,
                                      'url': widget.videoUrl,
                                      'position': position,
                                      'duration': duration,
                                    });
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              Expanded(
                                child: Text(
                                 widget.title,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _subtitlesEnabled && _subtitles.isNotEmpty
                                      ? Icons.closed_caption
                                      : Icons.closed_caption_off,
                                  color: _subtitlesEnabled &&
                                          _subtitles.isNotEmpty
                                      ? Colors.amber
                                      : Colors.white,
                                ),
                                onPressed: () {
                                  if (_subtitles.isEmpty) {
                                    _loadSubtitle();
                                  } else {
                                    setState(() {
                                      _subtitlesEnabled =
                                          !_subtitlesEnabled;
                                    });
                                    _snack(_subtitlesEnabled
                                        ? 'Subtitles ON'
                                        : 'Subtitles OFF');
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white),
                                onPressed: _showMoreOptionsMenu,
                              ),
                            ],
                          ),
                        ),

                     // ----- नीचे कंट्रोल बार -----
if (_showControls)
  Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      padding:
          const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.transparent
          ],
        ),
      ),
      // 👇 NAYA FIX: AnimatedBuilder use kiya hai
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _sideBtn(Icons.content_cut, Colors.white,
                      _takeScreenshot),
                  const SizedBox(width: 10),
                  _sideBtn(
                    _muted
                        ? Icons.volume_off
                        : Icons.volume_up,
                    _muted
                        ? Colors.redAccent
                        : Colors.white,
                    _toggleMute,
                  ),
                  const SizedBox(width: 10),
                  _sideBtn(
                    _locked
                        ? Icons.lock
                        : Icons.lock_open,
                    _locked ? Colors.amber : Colors.white,
                    _toggleLock,
                  ),
                  const Spacer(),
                  _sideBtn(
                    Icons.vertical_split,
                    Colors.white,
                    _openDual,
                  ),
                  const SizedBox(width: 6),
                  _sideBtn(
                    Icons.playlist_play,
                    _showVideoList
                        ? AppTheme.primaryBlue
                        : Colors.white,
                    () => setState(() =>
                        _showVideoList = !_showVideoList),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(),
                    icon: Icon(
                        _isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.screen_rotation,
                        color: Colors.white,
                        size: 20),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                      _formatDuration(
                          _controller.value.position),
                      style: const TextStyle(
                          color: Colors.white70)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                        activeTrackColor:
                            AppTheme.primaryBlue,
                        inactiveTrackColor:
                            Colors.white24,
                        thumbColor: AppTheme.primaryBlue,
                      ),
                      child: Slider(
                        value: (_isSeeking &&
                                    _previewSeekPosition !=
                                        null
                                ? _previewSeekPosition!
                                : _controller.value
                                    .position.inSeconds
                                    .toDouble())
                            .clamp(
                                0,
                                _controller.value.duration
                                    .inSeconds
                                    .toDouble()),
                        min: 0,
                        max: _controller
                            .value.duration.inSeconds
                            .toDouble(),
                        onChangeStart: (value) {
                          setState(() {
                            _isSeeking = true;
                            _previewSeekPosition = value;
                          });
                          _generatePreviewThumbnail(value);
                        },
                        onChanged: (value) {
                          setState(() {
                            _previewSeekPosition = value;
                          });
                          _generatePreviewThumbnail(value);
                        },
                        onChangeEnd: (value) {
                          _seekTo(value);
                          setState(() {
                            _isSeeking = false;
                            _previewSeekPosition = null;
                            _previewThumbnail = null;
                          });
                        },
                      ),
                    ),
                  ),
                  Text(
                      _formatDuration(
                          _controller.value.duration),
                      style: const TextStyle(
                          color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(),
                          icon: Icon(
                            _loopMode == 1
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: _loopMode == 0
                                ? Colors.white54
                                : AppTheme.primaryBlue,
                            size: 18,
                          ),
                          onPressed: _cycleLoop,
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(),
                          icon: Icon(
                            _fitMode == 0
                                ? Icons.aspect_ratio
                                : (_fitMode == 1
                                    ? Icons.zoom_out_map
                                    : Icons.fullscreen),
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: _cycleFit,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(),
                        icon: Icon(Icons.skip_previous,
                            color: _hasPrevious
                                ? Colors.white
                                : Colors.white24,
                            size: 24),
                        onPressed: _hasPrevious
                            ? _playPrevious
                            : null,
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(),
                        icon: Icon(Icons.skip_next,
                            color: _hasNext
                                ? Colors.white
                                : Colors.white24,
                                size: 24),
                        onPressed:
                            _hasNext ? _playNext : null,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(),
                          icon: const Icon(Icons.speed,
                              color: Colors.white70,
                              size: 20),
                          onPressed: _showSpeedDialog,
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(),
                          icon: const Icon(
                              Icons.picture_in_picture_alt,
                              color: Colors.white70,
                              size: 18),
                          onPressed: _enterPip,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  ),

                   // ----- Lock Button -----
                      if (_locked)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: _toggleLock,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock,
                                color: Colors.amber,
                                size: 22,
                                                      ),
                      ),
                    ),
                  ], // 👈 Inner Stack ke children band hue
                ), // 👈 Inner Stack band hua
              ), // 👈 GestureDetector band hua
            ), // 👈 Listener close band hua
            
          ], // ✅ YEH NAYA ADD KAREIN (Outer Stack ke children band karne ke liye)
        ), // ✅ YEH NAYA ADD KAREIN (Outer Stack ko band karne ke liye)
        
      ), // ✅ Ab yeh sahi tareeqe se Scaffold close karega
    ); // ✅ Ab yeh sahi tareeqe se PopScope close karega
  } // _buildPlayer close
} // Class close
