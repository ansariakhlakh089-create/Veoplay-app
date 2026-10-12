part of 'main.dart';

// ===================== DUAL VIDEO SCREEN =====================
class DualVideoScreen extends StatefulWidget {
  final List<Map<String, String>> playlist;
  final int index1;
  final int index2;
  final int startPosition1;

  const DualVideoScreen({
    Key? key,
    required this.playlist,
    required this.index1,
    required this.index2,
    this.startPosition1 = 0,
  }) : super(key: key);

  @override
  State<DualVideoScreen> createState() => _DualVideoScreenState();
}

class _DualVideoScreenState extends State<DualVideoScreen> {
  VideoPlayerController? _c1;
  VideoPlayerController? _c2;
  late int _i1;
  late int _i2;
  bool _ready1 = false;
  bool _ready2 = false;
  bool _showList = false;
bool _showCtrl1 = true;   // C-1: हर panel के controls
bool _showCtrl2 = true;
bool _leaving = false;
// 👇 skip indicators (per-panel)
String _skip1 = '';
String _skip2 = '';
Timer? _skipTimer1;
Timer? _skipTimer2;
// 👇 drag seek (per-panel)
double _dragSec1 = 0;
double _dragSec2 = 0;
bool _dragging1 = false;
bool _dragging2 = false;
// 👇 function buttons (per-panel)
double _speed1 = 1.0;
double _speed2 = 1.0;
int _loop1 = 0;
int _loop2 = 0;
bool _mute1 = false;
bool _mute2 = false;
bool _lock1 = false;
bool _lock2 = false;
  
  @override
  void initState() {
    super.initState();
    _i1 = widget.index1;
    _i2 = widget.index2;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _load(0, _i1, startSec: widget.startPosition1);
    _load(1, _i2);
  }

  VideoPlayerController? _ctrl(int slot) => slot == 0 ? _c1 : _c2;

  VideoPlayerController _make(String url) {
    if (url.startsWith('http')) {
      return VideoPlayerController.networkUrl(Uri.parse(url));
    }
    return VideoPlayerController.file(File(url));
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _saveResumeFor(String url, VideoPlayerController? c) async {
    if (c == null) return;
    final pos = c.value.position.inSeconds;
    final dur = c.value.duration.inSeconds;
    final prefs = await SharedPreferences.getInstance();
    final key = 'resume_$url';
    if (pos >= 5 && (dur <= 0 || pos < dur - 3)) {
      await prefs.setInt(key, pos);
    } else {
      await prefs.remove(key);
    }
  }

  // किसी भी हिस्से (0 या 1) में नया वीडियो लगाना
  Future<void> _load(int slot, int index, {int startSec = 0}) async {
    final old = _ctrl(slot);
    if (old != null) {
      old.removeListener(_onTick);
      final oldIndex = slot == 0 ? _i1 : _i2;
      _saveResumeFor(widget.playlist[oldIndex]['url']!, old);
    }
    if (mounted) {
      setState(() {
        if (slot == 0) {
          _c1 = null;
          _ready1 = false;
          _i1 = index;
        } else {
          _c2 = null;
          _ready2 = false;
          _i2 = index;
        }
      });
    }
    await Future.delayed(const Duration(milliseconds: 80));
    await old?.dispose();

    final url = widget.playlist[index]['url']!;
    final c = _make(url);
    try {
      await c.initialize();
    } catch (e) {
      await c.dispose();
      if (mounted) _snack('वीडियो नहीं खुल पाया');
      return;
    }
    if (!mounted || _leaving) {
      await c.dispose();
      return;
    }
    var start = startSec;
    if (start <= 0) {
      final prefs = await SharedPreferences.getInstance();
      start = prefs.getInt('resume_$url') ?? 0;
    }
    if (start > 0) await c.seekTo(Duration(seconds: start));
    if (!mounted || _leaving) {
      await c.dispose();
      return;
    }
      c.addListener(_onTick);
  setState(() {
    if (slot == 0) {
      _c1 = c;
      _ready1 = true;
    } else {
      _c2 = c;
      _ready2 = true;
    }
  });
  await c.play();
  }

// 👇 Skip ±10s (per-panel)
void _skipSlot(int slot, int seconds) {
  final c = _ctrl(slot);
  if (c == null) return;
  final newPos = c.value.position + Duration(seconds: seconds);
  Duration target = newPos;
  if (target < Duration.zero) target = Duration.zero;
  if (target > c.value.duration) target = c.value.duration;
  c.seekTo(target);
  _showSkipInd(slot, seconds > 0 ? '+${seconds}s' : '${seconds}s');
}

void _showSkipInd(int slot, String text) {
  if (slot == 0) {
    _skipTimer1?.cancel();
    setState(() => _skip1 = text);
    _skipTimer1 = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _skip1 = '');
    });
  } else {
    _skipTimer2?.cancel();
    setState(() => _skip2 = text);
    _skipTimer2 = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _skip2 = '');
    });
  }
}

// 👇 Drag seek (per-panel)
void _onDragStart(int slot) {
  if (slot == 0) {
    setState(() => _dragging1 = true);
  } else {
    setState(() => _dragging2 = true);
  }
}

void _onDragUpdate(int slot, double deltaX) {
  if (slot == 0) {
    setState(() => _dragSec1 += deltaX / 5);
  } else {
    setState(() => _dragSec2 += deltaX / 5);
  }
}

void _onDragEnd(int slot) {
  final c = _ctrl(slot);
  final sec = slot == 0 ? _dragSec1 : _dragSec2;
  if (c != null) {
    final newPos = c.value.position + Duration(seconds: sec.toInt());
    Duration target = newPos;
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
  }
  if (slot == 0) {
    setState(() {
      _dragging1 = false;
      _dragSec1 = 0;
    });
  } else {
    setState(() {
      _dragging2 = false;
      _dragSec2 = 0;
    });
  }
}

// 👇 Center indicator (skip/drag दोनों के लिए)
Widget _centerIndicator({required IconData icon, required String label}) {
  return Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xff2D8CFF), size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

// 👇 Speed cycle (per-panel)
static const List<double> _speedList = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
void _cycleSpeed(int slot) {
  final c = _ctrl(slot);
  if (c == null) return;
  final cur = slot == 0 ? _speed1 : _speed2;
  final idx = _speedList.indexOf(cur);
  final next = _speedList[(idx + 1) % _speedList.length];
  c.setPlaybackSpeed(next);
  setState(() {
    if (slot == 0) {
      _speed1 = next;
    } else {
      _speed2 = next;
    }
  });
  _snack('Video ${slot + 1}: ${next}x');
}

// 👇 Loop cycle (per-panel)
void _cycleLoopSlot(int slot) {
  final c = _ctrl(slot);
  if (c == null) return;
  final cur = slot == 0 ? _loop1 : _loop2;
  final next = (cur + 1) % 3;
  c.setLooping(next == 1);
  setState(() {
    if (slot == 0) {
      _loop1 = next;
    } else {
      _loop2 = next;
    }
  });
  _snack(next == 0
      ? 'Video ${slot + 1}: Loop Off'
      : (next == 1
          ? 'Video ${slot + 1}: Loop One'
          : 'Video ${slot + 1}: Loop All'));
}

// 👇 Mute toggle (per-panel)
void _toggleMuteSlot(int slot) {
  final c = _ctrl(slot);
  if (c == null) return;
  final muted = slot == 0 ? _mute1 : _mute2;
  c.setVolume(muted ? 1.0 : 0.0);
  setState(() {
    if (slot == 0) {
      _mute1 = !muted;
    } else {
      _mute2 = !muted;
    }
  });
}

// 👇 Screenshot (per-panel)
Future<void> _takeScreenshotSlot(int slot) async {
  final c = _ctrl(slot);
  if (c == null || !c.value.isInitialized) return;
  try {
    final idx = slot == 0 ? _i1 : _i2;
    final url = widget.playlist[idx]['url']!;
    final bytes = await VideoThumbnail.thumbnailData(
      video: url,
      imageFormat: ImageFormat.JPEG,
      timeMs: c.value.position.inMilliseconds,
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
    _snack('Video ${slot + 1} का screenshot सेव हो गया');
  } catch (e) {
    debugPrint('Screenshot error: $e');
    _snack('Screenshot में दिक्कत आई');
  }
}

// 👇 Lock toggle (per-panel)
void _toggleLockSlot(int slot) {
  setState(() {
    if (slot == 0) {
      _lock1 = !_lock1;
    } else {
      _lock2 = !_lock2;
    }
  });
  final locked = slot == 0 ? _lock1 : _lock2;
  _snack(locked
      ? 'Video ${slot + 1}: 🔒 Locked'
      : 'Video ${slot + 1}: 🔓 Unlocked');
}

// 👇 Function buttons row (per-panel)
Widget _buildSlotButtons(int slot) {
  final c = _ctrl(slot);
  if (c == null) return const SizedBox.shrink();
  final speed = slot == 0 ? _speed1 : _speed2;
  final loop = slot == 0 ? _loop1 : _loop2;
  final mute = slot == 0 ? _mute1 : _mute2;
  final lock = slot == 0 ? _lock1 : _lock2;

  Widget btn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xff2D8CFF).withOpacity(0.3)
              : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: active
              ? Border.all(color: const Color(0xff2D8CFF), width: 1)
              : null,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 16),
      ),
    );
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      btn(
        icon: Icons.speed,
        onTap: () => _cycleSpeed(slot),
        active: speed != 1.0,
        color: speed != 1.0 ? const Color(0xff2D8CFF) : Colors.white70,
      ),
      btn(
        icon: loop == 1 ? Icons.repeat_one : Icons.repeat,
        onTap: () => _cycleLoopSlot(slot),
        active: loop != 0,
        color: loop != 0 ? const Color(0xff2D8CFF) : Colors.white70,
      ),
      btn(
        icon: Icons.content_cut,
        onTap: () => _takeScreenshotSlot(slot),
      ),
      btn(
        icon: mute ? Icons.volume_off : Icons.volume_up,
        onTap: () => _toggleMuteSlot(slot),
        color: mute ? Colors.redAccent : Colors.white70,
      ),
      btn(
        icon: lock ? Icons.lock : Icons.lock_open,
        onTap: () => _toggleLockSlot(slot),
        color: lock ? Colors.amber : Colors.white70,
      ),
    ],
  );
}

  // 👇 हर panel का अपना play/pause
void _togglePlaySlot(int slot) {
  final c = _ctrl(slot);
  if (c == null) return;
  if (c.value.isPlaying) {
    c.pause();
  } else {
    c.play();
  }
  setState(() {});
}

// 👇 हर panel का अपना seek
void _seekToSlot(int slot, double sec) {
  _ctrl(slot)?.seekTo(Duration(seconds: sec.toInt()));
}

  // वापस पुराने (अकेले वीडियो वाले) प्लेयर पर
  void _exitToSingle() {
    final ac = _ctrl(0);
    if (ac == null) {
      Navigator.pop(context);
      return;
    }
    final idx = _i1;
    final pos = ac.value.position.inSeconds;
    final item = widget.playlist[idx];
    _leaving = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RealVideoPlayer(
          videoUrl: item['url']!,
          title: item['title']!,
          startPosition: pos,
          playlist: widget.playlist,
          currentIndex: idx,
          startLandscape: true,
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    final c1 = _c1;
    final c2 = _c2;
    c1?.removeListener(_onTick);
    c2?.removeListener(_onTick);
    if (c1 != null) _saveResumeFor(widget.playlist[_i1]['url']!, c1);
    if (c2 != null) _saveResumeFor(widget.playlist[_i2]['url']!, c2);
    c1?.dispose();
    c2?.dispose();
    if (!_leaving) {
      WakelockPlus.disable();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

    // ---------------- UI ----------------

  Widget _panel(int slot) {
    final c = _ctrl(slot);
    final ready = slot == 0 ? _ready1 : _ready2;
    final showCtrl = slot == 0 ? _showCtrl1 : _showCtrl2;
    final muted = slot == 0 ? _mute1 : _mute2;
    final skipText = slot == 0 ? _skip1 : _skip2;
    final dragging = slot == 0 ? _dragging1 : _dragging2;
    final dragSec = slot == 0 ? _dragSec1 : _dragSec2;
    final ok = ready && c != null;
    final playing = ok ? c!.value.isPlaying : false;
    final pos = ok ? c!.value.position : Duration.zero;
    final dur = ok ? c!.value.duration : Duration.zero;
    final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
    final curSec = pos.inSeconds.toDouble().clamp(0.0, maxSec).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (slot == 0) {
          _showCtrl1 = !_showCtrl1;
        } else {
          _showCtrl2 = !_showCtrl2;
        }
      }),
      onDoubleTapDown: (details) {
        final panelW = MediaQuery.of(context).size.width / 2;
        if (details.localPosition.dx < panelW / 3) {
          _skipSlot(slot, -10);
        } else if (details.localPosition.dx > panelW * 2 / 3) {
          _skipSlot(slot, 10);
        } else {
          _togglePlaySlot(slot);
        }
      },
      onHorizontalDragStart: (_) => _onDragStart(slot),
      onHorizontalDragUpdate: (details) =>
          _onDragUpdate(slot, details.delta.dx),
      onHorizontalDragEnd: (_) => _onDragEnd(slot),
      child: Stack(
        children: [
          // वीडियो
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: ok
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: c!.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    ),
            ),
          ),

          // 👇 Skip indicator (बीच में)
          if (skipText.isNotEmpty)
            _centerIndicator(
              icon: skipText.startsWith('+')
                  ? Icons.fast_forward
                  : Icons.fast_rewind,
              label: skipText,
            ),

          // 👇 Drag seek indicator (बीच में)
          if (dragging)
            _centerIndicator(
              icon: dragSec >= 0 ? Icons.fast_forward : Icons.fast_rewind,
              label: dragSec >= 0
                  ? '+${_fmt(Duration(seconds: dragSec.toInt()))}'
                  : '-${_fmt(Duration(seconds: dragSec.abs().toInt()))}',
            ),

          // Video 1 / Video 2 का नाम
          Positioned(
            left: 8,
            bottom: showCtrl ? 56 : 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    muted ? Icons.volume_off : Icons.volume_up,
                    color: muted ? Colors.white54 : Colors.amber,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Text('Video ${slot + 1}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),

          // 👇 C-1: नीचे time + seek bar + play/pause (हर panel का अपना)
          if (showCtrl)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Text(_fmt(pos),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12),
                          activeTrackColor: const Color(0xff2D8CFF),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xff2D8CFF),
                        ),
                        child: Slider(
                          value: curSec,
                          min: 0,
                          max: maxSec,
                          onChanged: ok ? (v) => _seekToSlot(slot, v) : null,
                        ),
                      ),
                    ),
                    Text(_fmt(dur),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _togglePlaySlot(slot),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xff2D8CFF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
  onPressed: () => Navigator.pop(context),
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(),
),
const SizedBox(width: 8),
const Expanded(
  child: Text(
    'Dual Video',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
  icon: Icon(Icons.playlist_play,
      color: _showList ? Colors.amber : Colors.white),
  onPressed: () => setState(() => _showList = !_showList),
),
              TextButton.icon(
                onPressed: _exitToSingle,
                icon: const Icon(Icons.crop_square,
                    color: Colors.white, size: 18),
                label: const Text('Single',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSlot(int i) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: Text(
          widget.playlist[i]['title'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _load(0, i);
            },
            child: const Text('Video 1 में लगाओ',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _load(1, i);
            },
            child: const Text('Video 2 में लगाओ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(int slot) {
    final idx = slot == 0 ? _i1 : _i2;
    final active = !(slot == 0 ? _mute1 : _mute2);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active ? Colors.amber : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.volume_up : Icons.volume_off,
              color: active ? Colors.amber : Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Video ${slot + 1}: ${widget.playlist[idx]['title'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListPanel() {
    final list = widget.playlist;
    final panelWidth =
        (MediaQuery.of(context).size.width * 0.5).clamp(260.0, 380.0).toDouble();
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: panelWidth,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Videos (${list.length})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _showList = false),
                    ),
                  ],
                ),
              ),
              _slotCard(0),
              _slotCard(1),
              const SizedBox(height: 4),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final inSlot = i == _i1 ? '1' : (i == _i2 ? '2' : '');
                    return ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 80,
                          height: 46,
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
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: inSlot.isEmpty
                          ? null
                          : CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.amber,
                              child: Text(inSlot,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                      onTap: () => _pickSlot(i),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(child: _panel(0)),
              Container(width: 2, color: Colors.white24),
              Expanded(child: _panel(1)),
            ],
          ),
          if (_showCtrl1 || _showCtrl2) _buildTopBar(),
          if (_showList) _buildListPanel(),
        ],
      ),
    );
  }
}
