import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
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

    Future.delayed(const Duration(milliseconds: 2800), () {
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 3.0,
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
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
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
                          if (_recentTitle != null) ...[
                            const Text("Recent",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RealVideoPlayer(
                                      videoUrl: _recentUrl!,
                                      title: _recentTitle!,
                                      startPosition: _recentPosition,
                                    ),
                                  ),
                                ).then((_) => _loadRecent());
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RealVideoPlayer(
                videoUrl: item['url']!,
                title: item['title']!,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 130,
                  height: 75,
                  decoration: BoxDecoration(
                  color: const Color(0xff2D8CFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item['res']} | ${item['size']}",
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  Text(
                    item['source']!,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon:
                  const Icon(Icons.more_vert, color: Colors.white60, size: 20),
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
  const RealVideoPlayer(
      {super.key,
      required this.videoUrl,
      required this.title,
      this.startPosition = 0});

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

 @override
  void initState() {
    super.initState();
    if (widget.videoUrl.startsWith('http')) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }
    _controller.initialize().then((_) {
      setState(() {
        _isInitialized = true;
      });
      if (widget.startPosition > 0) {
        _controller.seekTo(Duration(seconds: widget.startPosition));
      }
      _controller.play();
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
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  void _seekTo(double seconds) {
    _controller.seekTo(Duration(seconds: seconds.toInt()));
  }

  void _skipForward() {
    final newPos = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPos);
  }

  void _skipBackward() {
    var newPos = _controller.value.position - const Duration(seconds: 10);
    if (newPos < Duration.zero) newPos = Duration.zero;
    _controller.seekTo(newPos);
  }

  void _setSpeed(double speed) {
    _controller.setPlaybackSpeed(speed);
    setState(() => _speed = speed);
  }

  void _setVolume(double volume) {
    _controller.setVolume(volume);
    setState(() => _volume = volume);
  }

  void _setBrightness(double brightness) {
    setState(() => _brightness = brightness);
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Playback Speed',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: speeds.map((s) {
                    final selected = s == _speed;
                    return ChoiceChip(
                      label: Text('${s}x'),
                      selected: selected,
                      selectedColor: const Color(0xff2D8CFF),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70),
                      onSelected: (_) {
                        _setSpeed(s);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _saveProgress();
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_title', widget.title);
    await prefs.setString('recent_url', widget.videoUrl);
    await prefs.setInt(
        'recent_position', _controller.value.position.inSeconds);
    await prefs.setInt(
        'recent_duration', _controller.value.duration.inSeconds);
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
              onTap: _toggleControls,
              // ऊपर-नीचे swipe: left = brightness, right = volume
              onVerticalDragUpdate: (details) {
                final screenWidth = MediaQuery.of(context).size.width;
                final dx = details.globalPosition.dx;
                final delta = -details.delta.dy / 200;
                if (dx < screenWidth / 2) {
                  _setBrightness((_brightness + delta).clamp(0.0, 1.0));
                } else {
                  _setVolume((_volume + delta).clamp(0.0, 1.0));
                }
              },
              child: Stack(
                children: [
                  // ----- वीडियो -----
                   Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  // ब्राइटनेस ओवरले
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(1.0 - _brightness),
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
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
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
                            icon: const Icon(Icons.cast, color: Colors.white),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.closed_caption,
                                color: Colors.white),
                            onPressed: () {},
                          ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 1, child: Text('Share')),
                              PopupMenuItem(
                                  value: 2, child: Text('Download')),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // ----- साइड पैनल (स्पीड) -----
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

                  // ----- नीचे कंट्रोल बार -----
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
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
                            // सीक बार
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
                                          const Color(0xff2D8CFF),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xff2D8CFF),
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
                                      max: _controller.value.duration.inSeconds
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
                            // प्ले कंट्रोल्स
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay_10,
                                      color: Colors.white, size: 30),
                                  onPressed: _skipBackward,
                                ),
                                const SizedBox(width: 24),
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
                                      _controller.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                IconButton(
                                  icon: const Icon(Icons.forward_10,
                                      color: Colors.white, size: 30),
                                  onPressed: _skipForward,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // वॉल्यूम स्लाइडर
                            Row(
                              children: [
                                const Icon(Icons.volume_up,
                                    color: Colors.white70, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: _volume,
                                    min: 0,
                                    max: 1,
                                    activeColor: const Color(0xff2D8CFF),
                                    onChanged: _setVolume,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
