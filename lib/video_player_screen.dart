part of 'main.dart';

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

class _RealVideoPlayerState extends State<RealVideoPlayer> {
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
  bool _autoPlayNext = true;   // 👈 यह जोड़ो

  @override
  void initState() {
    super.initState();
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
      if (mounted) setState(() => _volume = v);
    }).catchError((_) {});

    try {
      ScreenBrightness().current.then((b) {
        if (mounted) setState(() => _brightness = b);
      }).catchError((_) {});
    } catch (_) {}

    WakelockPlus.enable();

    SharedPreferences.getInstance().then((p) {
            final mode = p.getInt('video_loop_mode') ?? 0;
      _autoPlayNext = p.getBool('auto_play_next') ?? true;   // 👈 जोड़ो
      if (mounted) {
        setState(() {
          _loopMode = mode;
          _isLooping = (mode == 1);
        });
      }
      if (_isInitialized) _controller.setLooping(mode == 1);
    });

    if (widget.videoUrl.startsWith('http')) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
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
        if (saved > 0 && mounted) {
          await _controller.seekTo(Duration(seconds: saved));
        }
      }
      if (!mounted) return;
      _controller.setPlaybackSpeed(_speed);
      _controller.setLooping(_isLooping);
      _controller.play();
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
      if (!_isLooping &&
          !_autoNextTriggered &&
          val.isInitialized &&
          val.duration > Duration.zero &&
          val.position >= val.duration - const Duration(milliseconds: 800)) {
        _autoNextTriggered = true;
                if (_hasNext) {
          if (_autoPlayNext) _playNext();   // 👈 सिर्फ़ यह लाइन बदली
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
              ListTile(
                dense: true,
                leading: const Icon(Icons.vertical_split, color: Colors.amber),
                title: const Text(
                  'Dual Video',
                  style: TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'दो वीडियो एक साथ',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: _openDual,
              ),
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

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      builder: (context) {
        return SafeArea(
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
                                style: TextStyle(
                                    color: AppTheme.textPrimary)),
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
        );
      },
    );
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) {
        _controller.pause();
        Navigator.pop(context);
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
      await Share.share(
        '${widget.title}\n${widget.videoUrl}',
        subject: widget.title,
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
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

  void _onPipAction(PipAction action) {
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
        if (_hasNext) _playNext();
        break;
      case PipAction.previous:
        if (_hasPrevious) _playPrevious();
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
                            double newVol =
                                (_volume + delta).clamp(0.0, 2.0);
                            if (newVol <= 1.0) {
                              VolumeController().setVolume(newVol);
                              _controller.setVolume(1.0);
                            } else {
                              VolumeController().setVolume(1.0);
                              _controller.setVolume(newVol);
                            }
                            setState(() {
                              _volume = newVol;
                              _muted = false;
                              _showGestureFor(
                                  'Volume ${(newVol * 100).toInt()}%');
                            });
                          }
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
                                icon: const Icon(Icons.closed_caption,
                                    color: Colors.white),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Subtitles (CC) जल्द आएँगे'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                                  PopupMenuButton<int>(
                                color: AppTheme.card,
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white),
                                onSelected: (value) {
                                  switch (value) {
                                    case 1:
                                      _shareVideo();
                                      break;
                                    case 2:
                                      _showSleepTimerDialog();
                                      break;
                                    case 3:
                                      break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 1,
                                      child: Text('Share',
                                          style: TextStyle(
                                              color: AppTheme.textPrimary))),
                                  PopupMenuItem(
                                      value: 2,
                                      child: Text('Sleep timer',
                                          style: TextStyle(
                                              color: AppTheme.textPrimary))),
                                  PopupMenuItem(
                                      value: 3,
                                      child: Text('Play as audio',
                                          style: TextStyle(
                                              color: AppTheme.textPrimary))),
                                ],
                              ),
                            ],
                          ),
                        ),

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
                                          value: _controller
                                              .value.position.inSeconds
                                              .toDouble()
                                              .clamp(
                                                  0,
                                                  _controller.value.duration
                                                      .inSeconds
                                                      .toDouble()),
                                          min: 0,
                                          max: _controller
                                              .value.duration.inSeconds
                                              .toDouble(),
                                          onChanged: _seekTo,
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
                                            MainAxisAlignment.spaceEvenly,
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
                                            MainAxisAlignment.spaceEvenly,
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

                      if (_showVideoList) _buildVideoListPanel(),
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
                                      
