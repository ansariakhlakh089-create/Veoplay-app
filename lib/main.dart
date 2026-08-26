import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';   // 👈 यहाँ जोड़ें
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.aucyos.veoplay.channel.audio',
      androidNotificationChannelName: 'VeoPlay Audio',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Audio background init failed: $e');
  }
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
                        child: Image.asset(
                          'assets/logo.png',
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


class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  List<Map<String, String>> videoList = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
    bool _showPlaylist = false;
    int _currentTab = 0;
    List<SongModel> _songs = [];
    bool _audioLoaded = false;
  
  String? _recentTitle;
  String? _recentUrl;
  int _recentPosition = 0;
  int _recentDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
    _loadRecent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecent();
    }
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

  Future<void> _loadSongs() async {
    if (_audioLoaded) return;
    final OnAudioQuery audioQuery = OnAudioQuery();
    bool hasPermission = await audioQuery.checkAndRequest(retryRequest: true);
    if (!hasPermission) return;
    final songs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    setState(() {
      _songs = songs;
      _audioLoaded = true;
    });
  }

  Future<void> _loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('cached_videos');
    if (cached != null && cached.isNotEmpty) {
      final loadedCache = cached.map((s) {
        final parts = s.split('|||');
        return {
          "title": parts[0],
          "res": parts[1],
          "size": parts[2],
          "source": parts[3],
          "duration": parts[4],
          "url": parts[5],
          "isLocal": "true",
          "folder": parts.length > 6 ? parts[6] : "Unknown",
        };
      }).toList();
      setState(() {
        videoList = loadedCache;
        _isLoading = false;
      });
      _refreshVideosInBackground();
      return;
    }
    await _scanVideos();
  }

  Future<void> _refreshVideosInBackground() async {
    await _scanVideos(silent: true);
  }

  Future<void> _scanVideos({bool silent = false}) async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      if (!silent) {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
      return;
    }
    PhotoManager.setIgnorePermissionCheck(true);

    final List<AssetPathEntity> albums =
        await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      if (!silent) setState(() => _isLoading = false);
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
      final folderName = file.parent.path.split('/').last;
      loaded.add({
        "title": asset.title ?? "Unknown",
        "res": "${asset.width}x${asset.height}",
        "size": "",
        "source": "Device",
        "duration": "$minutes:$seconds",
        "url": file.path,
        "isLocal": "true",
        "folder": folderName,
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final toSave = loaded
        .map((m) =>
            "${m['title']}|||${m['res']}|||${m['size']}|||${m['source']}|||${m['duration']}|||${m['url']}|||${m['folder']}")
        .toList();
    await prefs.setStringList('cached_videos', toSave);

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
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                height: 31,
                width: 31,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 42,
                    width: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xff2D8CFF), Color(0xff6B4DFF)],
                      ),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Text("VeoPlay",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xff2D8CFF).withOpacity(0.2),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ],
             ),
             body: _currentTab == 2
          ? (_songs.isEmpty
              ? const Center(
                  child: Text(
                    "कोई गाना नहीं मिला",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AudioPlayerScreen(
                                songs: _songs,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xff2D8CFF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(song.artist ?? "Unknown",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ))
          : _isLoading
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
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _scanVideos(silent: true);
                        await _loadRecent();
                      },
                      child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  height: 150,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      VideoThumbnailWidget(
                                          videoPath: _recentUrl!),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.6),
                                            ],
                                          ),
                                        ),
                                      ),
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
                          ),
                            const SizedBox(height: 25),
                          ],
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showPlaylist = false),
                                child: Text("Videos",
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: !_showPlaylist
                                            ? Colors.white
                                            : Colors.white38)),
                              ),
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showPlaylist = true),
                                child: Text("Playlist",
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: _showPlaylist
                                            ? Colors.white
                                            : Colors.white38)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          if (!_showPlaylist)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: videoList.length,
                              itemBuilder: (context, index) {
                                final item = videoList[index];
                                return _buildVideoTile(context, item);
                              },
                            )
                          else
                            Builder(builder: (context) {
                              final Map<String, List<Map<String, String>>>
                                  grouped = {};
                              for (final video in videoList) {
                                final folder = video['folder'] ?? 'Unknown';
                                grouped
                                    .putIfAbsent(folder, () => [])
                                    .add(video);
                              }
                              final folderNames = grouped.keys.toList();
                              return ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: folderNames.length,
                                itemBuilder: (context, index) {
                                  final folderName = folderNames[index];
                                  final folderVideos = grouped[folderName]!;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                FolderVideosScreen(
                                              folderName: folderName,
                                              videos: folderVideos,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.folder,
                                                color: Color(0xff2D8CFF),
                                                size: 32),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(folderName,
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      "${folderVideos.length} videos",
                                                      style: const TextStyle(
                                                          color: Colors
                                                              .white54,
                                                          fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right,
                                                color: Colors.white38),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
          if (index == 2 && !_audioLoaded) {
            _loadSongs();
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.video_library), label: "Videos"),
          NavigationDestination(
              icon: Icon(Icons.play_circle_fill), label: "Play"),
          NavigationDestination(icon: Icon(Icons.music_note), label: "Music"),
        ],
      ),
    );
  }
        
  
  Widget _buildVideoTile(BuildContext context, Map<String, String> item) {
    final index = videoList.indexOf(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoThumbnailWidget(videoPath: item['url']!),
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
  bool _showGestureIndicator = false;
  String _gestureText = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
                _controller.setPlaybackSpeed(speed);
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
                  final newBrightness = (_brightness + delta).clamp(0.0, 1.0);
                  ScreenBrightness().setScreenBrightness(newBrightness);
                  setState(() {
                    _brightness = newBrightness;
                    _showGestureIndicator = true;
                    _gestureText = 'Brightness ${(newBrightness * 100).toInt()}%';
                  });
                } else {
                  double newVol = (_volume + delta).clamp(0.0, 1.0);
                  VolumeController().setVolume(newVol);
                  setState(() {
                    _volume = newVol;
                    _showGestureIndicator = true;
                    _gestureText = 'Volume ${(newVol * 100).toInt()}%';
                  });
                }
              },
              onVerticalDragEnd: (details) {
                setState(() => _showGestureIndicator = false);
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
                            onPressed: () {
                              final position = _controller.value.position.inSeconds;
                              final duration = _controller.value.duration.inSeconds;
                              _saveProgress();
                              Navigator.pop(context, {
                                'title': widget.title,
                                'url': widget.videoUrl,
                                'position': position,
                                'duration': duration,
                              });
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
                            // रोटेट बटन (सीक बार के ऊपर)
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                    _isFullscreen
                                        ? Icons.fullscreen_exit
                                        : Icons.screen_rotation,
                                    color: Colors.white,
                                    size: 20),
                                onPressed: _toggleFullscreen,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.skip_previous,
                                      color: _hasPrevious
                                          ? Colors.white
                                          : Colors.white24,
                                      size: 22),
                                  onPressed: _hasPrevious ? _playPrevious : null,
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.replay_10,
                                      color: Colors.white, size: 24),
                                  onPressed: _skipBackward,
                                ),
                                GestureDetector(
                                  onTap: _togglePlay,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: const BoxDecoration(
                                      color: Color(0xff2D8CFF),
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
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.forward_10,
                                      color: Colors.white, size: 24),
                                  onPressed: _skipForward,
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.skip_next,
                                      color: _hasNext
                                          ? Colors.white
                                          : Colors.white24,
                                      size: 22),
                                  onPressed: _hasNext ? _playNext : null,
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
// ==================== वीडियो थंबनेल विजेट ====================
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  const VideoThumbnailWidget({super.key, required this.videoPath});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailBytes;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateThumbnail();
  }

  String _getCacheFileName() {
    final hash = widget.videoPath.hashCode.toString();
    return 'thumb_$hash.jpg';
  }

  Future<void> _loadOrGenerateThumbnail() async {
    try {
      Uint8List? bytes;
      try {
        final tempDir = Directory.systemTemp;
        final cacheFile = File('${tempDir.path}/${_getCacheFileName()}');
        if (await cacheFile.exists()) {
          bytes = await cacheFile.readAsBytes();
        } else {
          bytes = await VideoThumbnail.thumbnailData(
            video: widget.videoPath,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200,
            quality: 50,
          );
          if (bytes != null) {
            try {
              await cacheFile.writeAsBytes(bytes);
            } catch (_) {}
          }
        }
      } catch (_) {
        bytes = await VideoThumbnail.thumbnailData(
          video: widget.videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 200,
          quality: 50,
        );
      }

      if (mounted && bytes != null) {
        setState(() {
          _thumbnailBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Thumbnail error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        width: 130,
        height: 75,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: 130,
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xff2D8CFF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }
}
class FolderVideosScreen extends StatelessWidget {
  final String folderName;
  final List<Map<String, String>> videos;
  const FolderVideosScreen(
      {super.key, required this.folderName, required this.videos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(folderName),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final item = videos[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RealVideoPlayer(
                      videoUrl: item['url']!,
                      title: item['title']!,
                      playlist: videos,
                      currentIndex: index,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: VideoThumbnailWidget(videoPath: item['url']!),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(item['duration'] ?? '',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13)),
                      ],
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
}
// ==================== ऑडियो स्क्रीन ====================
class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  Set<int> _favoriteIds = {};
  int _musicSubTab = 0;
  bool _isLoading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    bool hasPermission = await _audioQuery.checkAndRequest(
      retryRequest: true,
    );
    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Music"),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            )
          : _permissionDenied
              ? const Center(
                  child: Text(
                    "Audio access permission चाहिए",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : _songs.isEmpty
                  ? const Center(
                      child: Text(
                        "कोई गाना नहीं मिला",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(18),
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AudioPlayerScreen(
                                    songs: _songs,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff2D8CFF)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(song.artist ?? "Unknown",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                    ],
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
}
// ==================== ऑडियो प्लेयर स्क्रीन ====================
class AudioPlayerScreen extends StatefulWidget {
  final List<SongModel> songs;
  final int initialIndex;

  const AudioPlayerScreen({
    super.key,
    required this.songs,
    required this.initialIndex,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final AudioPlayer _player;
  late int _currentIndex;

  bool _isLoop = false;

  StreamSubscription<int?>? _currentIndexSubscription;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    _player = AudioPlayer();

    // Current song index बदलने पर UI update
    _currentIndexSubscription =
        _player.currentIndexStream.listen((index) {
      if (index != null && mounted) {
        setState(() {
          _currentIndex = index;
        });
      }
    });

    _setupPlaylist();
  }

  // ==================== PLAYLIST SETUP ====================
  Future<void> _setupPlaylist() async {
  try {
    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: widget.songs.map((song) {
        return AudioSource.uri(
          Uri.parse('content://media/external/audio/media/${song.id}'),
          tag: MediaItem(
            id: song.id.toString(),
            album: "VeoPlay",
            title: song.title,
            artist: song.artist ?? "Unknown",
          ),
        );
      }).toList(),
    );

    await _player.setAudioSource(
      playlist,
      initialIndex: _currentIndex,
    );

    await _player.play();
  } catch (e) {
    debugPrint("Audio setup error: $e");
  }
  }

  // ==================== PLAY / PAUSE ====================
  void _togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  // ==================== NEXT ====================
  Future<void> _playNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
        await _player.play();
      }
    } catch (e) {
      debugPrint("Next error: $e");
    }
  }

  // ==================== PREVIOUS ====================
  Future<void> _playPrevious() async {
    try {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
        await _player.play();
      }
    } catch (e) {
      debugPrint("Previous error: $e");
    }
  }

  // ==================== LOOP ====================
  Future<void> _toggleLoop() async {
    final newLoopState = !_isLoop;

    setState(() {
      _isLoop = newLoopState;
    });

    await _player.setLoopMode(
      newLoopState ? LoopMode.one : LoopMode.off,
    );
  }

  // ==================== DURATION FORMAT ====================
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    _currentIndexSubscription?.cancel();
    _player.dispose();

    super.dispose();
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    // Safety check
    if (widget.songs.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xff0B0D12),
        body: Center(
          child: Text(
            "No songs found",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final song = widget.songs[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            // ==================== ALBUM ART ====================
            Container(
              width: 250,
              height: 250,

              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff2D8CFF),
                    Color(0xff6B4DFF),
                  ],
                ),

                borderRadius: BorderRadius.circular(20),
              ),

              child: const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 100,
              ),
            ),

            const SizedBox(height: 40),

            // ==================== SONG TITLE ====================
            Text(
              song.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // ==================== ARTIST ====================
            Text(
              song.artist ?? "Unknown",

              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 30),

            // ==================== POSITION + DURATION ====================
            StreamBuilder<Duration>(
              stream: _player.positionStream,

              builder: (context, positionSnapshot) {
                final position =
                    positionSnapshot.data ?? Duration.zero;

                return StreamBuilder<Duration?>(
                  stream: _player.durationStream,

                  builder: (context, durationSnapshot) {
                    final duration =
                        durationSnapshot.data ?? Duration.zero;

                    final maxSeconds =
                        duration.inSeconds > 0
                            ? duration.inSeconds.toDouble()
                            : 1.0;

                    final currentSeconds =
                        position.inSeconds
                            .toDouble()
                            .clamp(0.0, maxSeconds);

                    return Column(
                      children: [

                        // ==================== SLIDER ====================
                        Slider(
                          value: currentSeconds,
                          min: 0,
                          max: maxSeconds,

                          activeColor:
                              const Color(0xff2D8CFF),

                          inactiveColor:
                              Colors.white24,

                          onChanged: duration.inSeconds > 0
                              ? (value) {
                                  _player.seek(
                                    Duration(
                                      seconds: value.toInt(),
                                    ),
                                  );
                                }
                              : null,
                        ),

                        // ==================== TIME ====================
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,

                          children: [

                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),

                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // ==================== CONTROLS ====================
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,

              children: [

                // ==================== LOOP ====================
                IconButton(
                  icon: Icon(
                    Icons.repeat,

                    color: _isLoop
                        ? const Color(0xff2D8CFF)
                        : Colors.white54,

                    size: 24,
                  ),

                  onPressed: _toggleLoop,
                ),

                // ==================== PREVIOUS ====================
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous,
                    color: Colors.white,
                    size: 32,
                  ),

                  onPressed: _playPrevious,
                ),

                // ==================== PLAY / PAUSE ====================
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,

                  builder: (context, snapshot) {
                    final playing =
                        snapshot.data?.playing ?? false;

                    return GestureDetector(
                      onTap: _togglePlay,

                      child: Container(
                        width: 64,
                        height: 64,

                        decoration:
                            const BoxDecoration(
                          color: Color(0xff2D8CFF),
                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          playing
                              ? Icons.pause
                              : Icons.play_arrow,

                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),

                // ==================== NEXT ====================
                IconButton(
                  icon: const Icon(
                    Icons.skip_next,
                    color: Colors.white,
                    size: 32,
                  ),

                  onPressed: _playNext,
                ),

                // ==================== SPEED ====================
                IconButton(
                  icon: const Icon(
                    Icons.speed,
                    color: Colors.white54,
                    size: 24,
                  ),

                  onPressed: () {
                    showModalBottomSheet(
                      context: context,

                      backgroundColor:
                          const Color(0xff1A1D24),

                      builder: (context) {
                        final speeds = [
                          0.5,
                          0.75,
                          1.0,
                          1.25,
                          1.5,
                          2.0,
                        ];

                        return Padding(
                          padding:
                              const EdgeInsets.all(16),

                          child: Wrap(
                            spacing: 10,

                            children: speeds.map((s) {
                              return ChoiceChip(
                                label: Text('${s}x'),

                                selected:
                                    _player.speed == s,

                                onSelected: (_) {
                                  _player.setSpeed(s);

                                  Navigator.pop(
                                    context,
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
