part of 'main.dart';

// 👇👇👇 Subtitle Line क्लास 👇👇👇
class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;
  SubtitleLine({required this.start, required this.end, required this.text});
}
// 👆👆👆 यहाँ तक 👆👆👆

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
  late VideoPlayerController _controller;
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
int _subtitleOffsetMs = 0;          // 👈 NAYA
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

    SharedPreferences.getInstance().then((p) async {
  // Pehle saved volume try karo
  final savedVol = p.getDouble('last_volume');
  if (savedVol != null && mounted) {
    setState(() => _volume = savedVol.clamp(0.0, 2.0));
    _applyVolume(savedVol.clamp(0.0, 2.0));
  } else {
    // Warna system volume
    try {
      final v = await VolumeController().getVolume();
      if (mounted) setState(() => _volume = v);
    } catch (_) {}
  }
});
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

    // 👇 URL सपोर्ट (content:// भी)
    if (widget.videoUrl.startsWith('http')) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else if (widget.videoUrl.startsWith('content://')) {
      _controller =
          VideoPlayerController.contentUri(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(
          File(widget.videoUrl.replaceFirst('file://', '')));
    }

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
      setState(() {});
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
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        timeMs: _controller.value.position.inMilliseconds,
        quality: 100,
      );
      if (bytes == null) {
        _snack('Screenshot नहीं बन पाया');
        return;
      }
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.hasAccess) {
        _snack('Gallery की permission दो');
        return;
      }
      final name = 'VeoPlay_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await PhotoManager.editor.saveImage(
        bytes,
        filename: name,
        title: name,
      );
      _snack('Screenshot Gallery में सेव हो गया');
    } catch (e) {
      debugPrint('Screenshot error: $e');
      _snack('Screenshot में दिक्कत आई');
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
                        child: Text('कोई वीडियो लिस्ट नहीं है',
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

  void _cycleFit() {
    setState(() => _fitMode = (_fitMode + 1) % 3);
    _snack(_fitMode == 0
        ? 'Fit'
        : (_fitMode == 1 ? 'Zoom (Fill)' : 'Stretch'));
  }

  void _playFirst() => _playAt(0);

  void _openDual() {
    final list = widget.playlist;
    if (list == null || list.length < 2) {
      _snack('Dual के लिए लिस्ट में कम से कम 2 वीडियो चाहिए');
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
    _controller.setVolume(_muted ? 0.0 : 1.0);
  }

  void _applyVolume(double newVol) {
  if (newVol <= 1.0) {
    VolumeController().setVolume(newVol, showSystemUI: false);
    _controller.setVolume(1.0);
  } else {
    VolumeController().setVolume(1.0, showSystemUI: false);
    _controller.setVolume(newVol);
  }
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

  bool get _hasNext {
    if (widget.playlist == null || widget.currentIndex == null) return false;
    return widget.currentIndex! < widget.playlist!.length - 1;
  }

  bool get _hasPrevious {
    if (widget.playlist == null || widget.currentIndex == null) return false;
    return widget.currentIndex! > 0;
  }

  void _playNext() {
    if (!_hasNext) return;
    final nextItem = widget.playlist![widget.currentIndex! + 1];
    _replacing = true;
    final goLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RealVideoPlayer(
          videoUrl: nextItem['url']!,
          title: nextItem['title']!,
          playlist: widget.playlist,
          currentIndex: widget.currentIndex! + 1,
          startLandscape: goLandscape,
        ),
      ),
    );
  }

  void _playPrevious() {
    if (!_hasPrevious) return;
    final prevItem = widget.playlist![widget.currentIndex! - 1];
    _replacing = true;
    final goLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RealVideoPlayer(
          videoUrl: prevItem['url']!,
          title: prevItem['title']!,
          playlist: widget.playlist,
          currentIndex: widget.currentIndex! - 1,
          startLandscape: goLandscape,
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
        backgroundColor: AppTheme.card,
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
      backgroundColor: AppTheme.card,
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
                        Text('$min मिनट',
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
                  const SnackBar(content: Text('Sleep timer हटाया')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Sleep Timer हटाओ',
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
      _snack('😴 Sleep timer: video रुक गया');
    }
  });
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$minutes मिनट बाद video रुकेगा')),
  );
}

Future<void> _enterPip() async {
  final available = await SimplePip.isPipAvailable;
  if (!available) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('इस device पर PiP support नहीं है'),
        ),
      );
    }
    return;
  }
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
      allowedExtensions: ['srt', 'vtt'],
    );

    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final content = await File(filePath).readAsString();

    final parsed = _parseSrt(content);
    if (parsed.isEmpty) {
      _snack('Subtitle फाइल खाली है या पढ़ी नहीं जा सकी');
      return;
    }

    setState(() {
      _subtitles = parsed;
      _subtitleFileName = result.files.single.name;
      _subtitlesEnabled = true;
    });

    _snack('✅ ${parsed.length} subtitles लोड हो गए');
  } catch (e) {
    debugPrint('Subtitle load error: $e');
    _snack('Subtitle लोड नहीं हो पाया');
  }
}

// 👇👇👇 SRT/VTT Parser 👇👇👇
List<SubtitleLine> _parseSrt(String content) {
  final result = <SubtitleLine>[];
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  int i = 0;

  Duration? parseTime(String s) {
    // Format: 00:00:01,000 या 00:00:01.000
    final clean = s.trim().replaceAll(',', '.');
    final parts = clean.split(':');
    if (parts.length != 3) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final sec = int.tryParse(secParts[0]) ?? 0;
    final ms = secParts.length > 1
        ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
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
        text: textLines.join('\n'),
      ));
    }
  }
  return result;
}

// 👇👇👇 Current Subtitle ढूंढो 👇👇👇
String? _getCurrentSubtitle() {
  if (!_subtitlesEnabled || _subtitles.isEmpty) return null;
  final pos = _controller.value.position +
      Duration(milliseconds: _subtitleOffsetMs);   // 👈 offset apply
  for (final s in _subtitles) {
    if (pos >= s.start && pos <= s.end) {
      return s.text;
    }
  }
  return null;
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
          content: Text('🎵 "${widget.title}" ऑडियो मोड में चल रहा है'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    debugPrint('Play as audio error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ऑडियो मोड में नहीं चल पाया'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

Future<void> _showAudioTrackPicker() async {
  List<VideoAudioTrack> tracks = [];
  try {
    tracks = await _controller.getAudioTracks();
  } catch (e) {
    debugPrint('Audio tracks error: $e');
  }
  if (!mounted) return;
  if (tracks.length < 2) {
    _snack(tracks.isEmpty
        ? 'इस वीडियो में audio track की जानकारी नहीं मिली'
        : 'इस वीडियो में सिर्फ़ एक audio track है');
    return;
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
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
              title: Text(
                  (tracks[i].label != null && tracks[i].label!.isNotEmpty)
                      ? tracks[i].label!
                      : (tracks[i].language != null &&
                              tracks[i].language != 'und'
                          ? tracks[i].language!
                          : 'Track ${i + 1}'),
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(
                  [
                    if (tracks[i].codec != null) tracks[i].codec!,
                    if (tracks[i].channelCount != null)
                      '${tracks[i].channelCount} ch',
                  ].join(' • '),
                  style: TextStyle(color: AppTheme.textSecondary)),
              trailing: tracks[i].isSelected
                  ? Icon(Icons.check, color: AppTheme.primaryBlue)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await _controller.selectAudioTrack(tracks[i].id);
                  _snack('Audio track बदल गया');
                } catch (e) {
                  debugPrint('Select audio track error: $e');
                  _snack('Audio track नहीं बदल पाया');
                }
              },
            ),
        ],
      ),
    ),
  );
}

// 👇 नया More Options Menu (Bottom Sheet)
void _showMoreOptionsMenu() {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
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
// 👆👆👆 यहाँ तक 👆👆👆
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
void dispose() {
  final title = widget.title;
  final url = widget.videoUrl;
  final position = _controller.value.position.inSeconds;
  final duration = _controller.value.duration.inSeconds;

  _hideTimer?.cancel();
  _sleepTimer?.cancel();
  _skipIndicatorTimer?.cancel();
  _gestureTimer?.cancel();
  _thumbnailDebounce?.cancel(); // 👈 ये नई लाइन
  // Save current volume for next video
SharedPreferences.getInstance().then((p) {
  p.setDouble('last_volume', _volume);
});
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
    _saveProgressData(title, url, position, duration);
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
        await SimplePip().exitPipMode();
        if (mounted) _playNext();
      }
      break;
    case PipAction.previous:
      if (_hasPrevious) {
        await SimplePip().exitPipMode();
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
    child: Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
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
    return Scaffold(
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
                      "वीडियो नहीं खुल पाया",
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
                      child: const Text("वापस जाएँ"),
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
              : GestureDetector(
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
                          setState(() {
                            _dragSeekSeconds += details.delta.dx / 5;
                          });
                        },
                  onHorizontalDragEnd: _locked
                      ? null
                      : (details) {
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
                        child: ClipRect(
                          child: FittedBox(
                            fit: _fitMode == 0
                                ? BoxFit.contain
                                : (_fitMode == 1
                                    ? BoxFit.cover
                                    : BoxFit.fill),
                            child: SizedBox(
                              width: _controller.value.size.width,
                              height: _controller.value.size.height,
                              child: VideoPlayer(_controller),
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
                            child: Builder(builder: (context) {
                              final text = _getCurrentSubtitle();
                              if (text == null || text.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
  text,
  textAlign: TextAlign.center,
  style: TextStyle(
    color: Colors.white,
    fontSize: _subtitleFontSize,          // 👈 variable
    fontWeight: FontWeight.w500,
    shadows: const [
      Shadow(
        color: Colors.black,
        blurRadius: 4,
        offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
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
                            child: Column(
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
                            ),
                          ),
                        ),

                      // ----- Video List Panel -----
                      if (_showVideoList) _buildVideoListPanel(),

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
                        ),
                    ],
                  ),
                ),
    );
  }
}
