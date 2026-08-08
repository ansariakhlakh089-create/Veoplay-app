import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
void main() {
  runApp(const VeoPlay());
}

// ---------- Main App ----------
class VeoPlay extends StatelessWidget {
  const VeoPlay({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "VeoPlay",
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff0B0D12),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== स्प्लैश स्क्रीन ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3100),
      vsync: this,
    );

    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );

    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1120), Color(0xFF1E1B4B)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Image.network(
                          'https://i.ibb.co/n8wgHnrd/file-000000009ae081fd902fa07284aa2583.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 100,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleOpacity,
                  child: const Text(
                    'Veoplay',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SlideTransition(
                position: _taglineSlide,
                child: FadeTransition(
                  opacity: _taglineOpacity,
                  child: const Text(
                    'PLAY·WATCH·ENJOY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB8C4D9),
                      letterSpacing: 3.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== होम स्क्रीन ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> videoList = [];
  bool _isLoading = true;
  bool _permissionDenied = false;

  String? _recentTitle;
  String? _recentUrl;
  int _recentPosition = 0;
  int _recentDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('recent_title');
    final url = prefs.getString('recent_url');
    final position = prefs.getInt('recent_position') ?? 0;
    final duration = prefs.getInt('recent_duration') ?? 0;
    if (title != null && url != null) {
      setState(() {
        _recentTitle = title;
        _recentUrl = url;
        _recentPosition = position;
        _recentDuration = duration;
      });
    }
  }
  
  Future<void> _loadVideos() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }
    PhotoManager.setIgnorePermissionCheck(true);

    final List<AssetPathEntity> albums =
        await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final int count = await albums[0].assetCountAsync;
    final List<AssetEntity> assets =
        await albums[0].getAssetListRange(start: 0, end: count);

    final List<Map<String, String>> loaded = [];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      final duration = asset.videoDuration;
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds =
          (duration.inSeconds % 60).toString().padLeft(2, '0');
      loaded.add({
        "title": asset.title ?? "Unknown",
        "res": "${asset.width}x${asset.height}",
        "size": "",
        "source": "Device",
        "duration": "$minutes:$seconds",
        "url": file.path,
        "isLocal": "true",
      });
    }

    setState(() {
      videoList = loaded;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xff2D8CFF), Color(0xff6B4DFF)],
                ),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text("VeoPlay",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          PopupMenuButton(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 1, child: Text("Settings")),
              PopupMenuItem(value: 2, child: Text("About")),
            ],
          ),
        ],
             ),
             body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 20),
                  Text(
                    "Discovering videos...",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          : _permissionDenied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_off,
                            color: Colors.white54, size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          "Video access permission चाहिए",
                          style: TextStyle(
                              color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => PhotoManager.openSetting(),
                          child: const Text("Settings खोलें"),
                        ),
                      ],
                    ),
                  ),
                )
              : videoList.isEmpty
                  ? const Center(
                      child: Text(
                        "कोई वीडियो नहीं मिला",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          const SizedBox(height: 25),
                          if (_recentTitle != null) ...[
                            const Text("Recent",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RealVideoPlayer(
                                      videoUrl: _recentUrl!,
                                      title: _recentTitle!,
                                      startPosition: _recentPosition,
                                    ),
                                  ),
                                );
                                if (result != null && result is Map) {
                                  setState(() {
                                    _recentTitle = result['title'];
                                    _recentUrl = result['url'];
                                    _recentPosition = result['position'];
                                    _recentDuration = result['duration'];
                                  });
                                } else {
                                  _loadRecent();
                                }
                              },
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff2D8CFF),
                                      Color(0xff6B4DFF)
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    const Center(
                                      child: Icon(Icons.play_circle_fill,
                                          color: Colors.white, size: 70),
                                    ),
                                    Positioned(
                                      left: 18,
                                      bottom: 18,
                                      right: 18,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text("Continue Watching",
                                              style: TextStyle(
                                                  color: Colors.white70)),
                                          const SizedBox(height: 5),
                                          Text(_recentTitle!,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                          const Text("Videos",
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: videoList.length,
                            itemBuilder: (context, index) {
                              final item = videoList[index];
                              return _buildVideoTile(context, item);
                            },
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.video_library), label: "Videos"),
          NavigationDestination(
              icon: Icon(Icons.play_circle_fill), label: "Play"),
          NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
  
  Widget _buildVideoTile(BuildContext context, Map<String, String> item) {
    final index = videoList.indexOf(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RealVideoPlayer(
                videoUrl: item['url']!,
                title: item['title']!,
                playlist: videoList,
                currentIndex: index,
              ),
            ),
          );
          if (result != null && result is Map) {
            setState(() {
              _recentTitle = result['title'];
              _recentUrl = result['url'];
              _recentPosition = result['position'];
              _recentDuration = result['duration'];
            });
          } else {
            _loadRecent();
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- थंबनेल भाग (बदला हुआ) ----
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 130,
                height: 75,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // असली वीडियो थंबनेल
                    VideoThumbnail(
                      videoUrl: item['url']!,
                      thumbnailPath: '',
                      imageFormat: ImageFormat.PNG,
                      maxHeight: 150,
                      quality: 75,
                      errorWidget: Container(
                        color: const Color(0xff2D8CFF).withOpacity(0.2),
                        child: const Icon(Icons.videocam, color: Colors.white54),
                      ),
                    ),
                    // प्ले आइकन
                    const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                    ),
                    // ड्यूरेशन बैज
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['duration']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // ---- जानकारी वाला भाग (टाइटल, res, size, source + more_vert) ----
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // वीडियो का टाइटल
                  Text(
                    item['title'] ?? 'No Title',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // रेज़ॉल्यूशन और साइज़
                  Text(
                    "${item['res'] ?? ''} | ${item['size'] ?? ''}",
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  // सोर्स और more_vert आइकन वाली Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['source'] ?? '',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert, color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== असली वीडियो प्लेयर ====================
class RealVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int startPosition;
  final List<Map<String, String>>? playlist;
  final int? currentIndex;

  const RealVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.startPosition = 0,
    this.playlist,
    this.currentIndex,
  }) : super(key: key);

  @override
  State<RealVideoPlayer> createState() => _RealVideoPlayerState();
}

class _RealVideoPlayerState extends State<RealVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  double _speed = 1.0;
  double _volume = 1.0;
  double _brightness = 0.8;
  double _dragSeekSeconds = 0;
  bool _isDraggingSeek = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    // वॉल्यूम लेना (एरर हैंडलिंग के साथ)
    VolumeController().getVolume().then((v) {
      if (mounted) setState(() => _volume = v);
    }).catchError((_) {});

    if (widget.videoUrl.startsWith('http')) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      if (widget.startPosition > 0) {
        _controller.seekTo(Duration(seconds: widget.startPosition));
      }
      _controller.play();
    }).catchError((error) {
      debugPrint('Video initialize error: $error');
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
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

  void _skipForward() {
    if (!_isInitialized) return;
    final newPos = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPos);
  }

  void _skipBackward() {
    if (!_isInitialized) return;
    var newPos = _controller.value.position - const Duration(seconds: 10);
    if (newPos < Duration.zero) newPos = Duration.zero;
    _controller.seekTo(newPos);
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RealVideoPlayer(
          videoUrl: nextItem['url']!,
          title: nextItem['title']!,
          playlist: widget.playlist,
          currentIndex: widget.currentIndex! + 1,
        ),
      ),
    );
  }

  void _playPrevious() {
    if (!_hasPrevious) return;
    final prevItem = widget.playlist![widget.currentIndex! - 1];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RealVideoPlayer(
          videoUrl: prevItem['url']!,
          title: prevItem['title']!,
          playlist: widget.playlist,
          currentIndex: widget.currentIndex! - 1,
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
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
      builder: (context) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              onTap: () {
                _controller.setSpeed(speed);
                setState(() => _speed = speed);
                Navigator.pop(context);
              },
            );
          }).toList(),
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
  }

  Future<void> _saveProgressData(String title, String url, int pos, int dur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_title', title);
    await prefs.setString('recent_url', url);
    await prefs.setInt('recent_position', pos);
    await prefs.setInt('recent_duration', dur);
  }

  @override
  void dispose() {
    final title = widget.title;
    final url = widget.videoUrl;
    final position = _controller.value.position.inSeconds;
    final duration = _controller.value.duration.inSeconds;

    _hideTimer?.cancel();
    _controller.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _saveProgressData(title, url, position, duration);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onVerticalDragUpdate: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                final dx = details.globalPosition.dx;
                final delta = -details.delta.dy / 200;
                if (dx < screenWidth / 2) {
                  // brightness (सिर्फ़ UI में दिखाने के लिए, असली ब्राइटनेस बदलने के लिए प्लगइन चाहिए)
                  setState(() {
                    _brightness = (_brightness + delta).clamp(0.0, 1.0);
                  });
                } else {
                  // volume
                  double newVol = (_volume + delta).clamp(0.0, 1.0);
                  VolumeController().setVolume(newVol);
                  setState(() => _volume = newVol);
                }
              },
              onHorizontalDragStart: (details) {
                setState(() {
                  _isDraggingSeek = true;
                  _dragSeekSeconds = 0;
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragSeekSeconds += details.delta.dx / 5;
                });
              },
              onHorizontalDragEnd: (details) {
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
                  // वीडियो डिस्प्ले
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),

                  // ड्रैग सीक इंडिकेटर
                  if (_isDraggingSeek)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _dragSeekSeconds >= 0
                              ? "+${_dragSeekSeconds.toInt()}s"
                              : "${_dragSeekSeconds.toInt()}s",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // ----- टॉप बार -----
                  if (_showControls)
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      left: 8,
                      right: 8,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () async {
                              await _saveProgress();
                              if (context.mounted) {
                                Navigator.pop(context, {
                                  'title': widget.title,
                                  'url': widget.videoUrl,
                                  'position': _controller.value.position.inSeconds,
                                  'duration': _controller.value.duration.inSeconds,
                                });
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cast, color: Colors.white),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.closed_caption, color: Colors.white),
                            onPressed: () {},
                          ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 1, child: Text('Share')),
                              PopupMenuItem(value: 2, child: Text('Download')),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // ----- स्पीड इंडिकेटर -----
                  if (_showControls)
                    Positioned(
                      right: 12,
                      top: MediaQuery.of(context).padding.top + 70,
                      child: GestureDetector(
                        onTap: _showSpeedDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_speed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),

                  // ----- प्ले कंट्रोल्स (नीचे) -----
                  if (_showControls)
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.skip_previous,
                                color: _hasPrevious ? Colors.white : Colors.white24, size: 28),
                            onPressed: _hasPrevious ? _playPrevious : null,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                            onPressed: _skipBackward,
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xff2D8CFF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                            onPressed: _skipForward,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.skip_next,
                                color: _hasNext ? Colors.white : Colors.white24, size: 28),
                            onPressed: _hasNext ? _playNext : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
