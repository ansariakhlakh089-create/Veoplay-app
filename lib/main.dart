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
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
final ValueNotifier<int> recentChangedNotifier = ValueNotifier<int>(0);
final AudioPlayer globalAudioPlayer = AudioPlayer();
final Map<int, String> globalSongNames = {};
final ValueNotifier<int> musicDataNotifier = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.aucyos.veoplay.channel.audio',
      androidNotificationChannelName: 'VeoPlay Audio',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Audio background init true: $e');
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
                        width: 200,
                        height: 200,
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
              const SizedBox(height: 27),
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
    bool _audioPermissionDenied = false; // 👈 नया
  
  String? _recentTitle;
  String? _recentUrl;
  int _recentPosition = 0;
  int _recentDuration = 0;
  int _musicSubTab = 0;
  Set<int> _favoriteIds = {};
  List<int> _recentSongIds = [];
  Map<String, List<int>> _playlists = {};
  StreamSubscription<dynamic>? _seqSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    recentChangedNotifier.addListener(_onRecentChanged);
    musicDataNotifier.addListener(_onMusicDataChanged);
    _seqSub = globalAudioPlayer.sequenceStateStream.listen((s) {
      final tag = s?.currentSource?.tag;
      if (tag is MediaItem) {
        final id = int.tryParse(tag.id);
        if (id != null) _addRecentSong(id);
      }
      if (mounted) setState(() {});
    });
    _loadVideos();
    _loadRecent();
  }

  void _onRecentChanged() {
    if (mounted) _loadRecent();
  }

  @override
  void dispose() {
    recentChangedNotifier.removeListener(_onRecentChanged);
    musicDataNotifier.removeListener(_onMusicDataChanged);
    _seqSub?.cancel();
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
   if (mounted && title != null && url != null) {
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
  if (!hasPermission) {
    if (mounted) {
      setState(() => _audioPermissionDenied = true);
    }
    return;
  }
  if (mounted) setState(() => _audioPermissionDenied = false);
  final songs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    await _loadSongNames();
    await _loadMusicData();
    final prefs = await SharedPreferences.getInstance();
    _songSortMode = prefs.getInt('song_sort_mode') ?? 0;
    final sorted = List<SongModel>.of(songs);
    _sortSongs(sorted);
    if (!mounted) return;
    setState(() {
      _songs = sorted;
      _audioLoaded = true;
    });
  }

  Future<void> _loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('cached_videos');
    _sortMode = prefs.getInt('sort_mode') ?? 0;
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
          "id": parts.length > 7 ? parts[7] : "",
        };
      }).toList();
      setState(() {
        videoList = loadedCache;
        _sortList(videoList);
        _isLoading = false;
      });
      // _refreshVideosInBackground();
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

     int count = await albums[0].assetCountAsync;
    final List<AssetEntity> assets =
        await albums[0].getAssetListRange(start: 0, end: count);

    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, String>> loaded = [];
    int processed = 0;
    final customNames = await _loadCustomNames();
    
    List<String> toCache(List<Map<String, String>> list) => list
        .map((m) =>
            "${m['title']}|||${m['res']}|||${m['size']}|||${m['source']}|||${m['duration']}|||${m['url']}|||${m['folder']}|||${m['id']}")
        .toList();

    for (final asset in assets) {
      final file = await asset.file;
      processed++;
      if (file != null) {
        final duration = asset.videoDuration;
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds =
            (duration.inSeconds % 60).toString().padLeft(2, '0');
        final folderName = file.parent.path.split('/').last;
        loaded.add({
          "title": customNames[asset.id] ?? asset.title ?? "Unknown",
          "res": "${asset.width}x${asset.height}",
          "size": _formatSize(file.existsSync() ? file.lengthSync() : 0),
          "source": "Device",
          "duration": "$minutes:$seconds",
          "url": file.path,
          "isLocal": "true",
          "folder": folderName,
          "id": asset.id,
        });
      }

      if (!silent && processed % 15 == 0) {
        await prefs.setStringList('cached_videos', toCache(loaded));
        if (mounted) {
          setState(() {
            videoList = List.of(loaded);
            _sortList(videoList);
            _isLoading = false;
          });
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    await prefs.setStringList('cached_videos', toCache(loaded));
    if (mounted) {
      setState(() {
        videoList = loaded;
        _sortList(videoList);
        _isLoading = false;
      });
    }
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
                height: 45,
                width: 45,
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
    ? _buildMusicTab()
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
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
                          const SizedBox(height: 12),
                          if (_recentTitle != null) ...[
                            const Text("Recent",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
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
                            await Future.delayed(
                                const Duration(milliseconds: 300));
                            if (mounted) _loadRecent();
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
                            const SizedBox(height: 12),
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
                              const Spacer(),
                              IconButton(
                                onPressed: _showSortMenu,
                                icon: const Icon(Icons.sort,
                                    color: Colors.white70),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
    if (index == 1) {
      // Beech wala Play button — seedha Recent video kholiye
      if (_recentUrl != null && _recentTitle != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RealVideoPlayer(
              videoUrl: _recentUrl!,
              title: _recentTitle!,
              startPosition: _recentPosition,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("कोई हाल ही में चलाया गया वीडियो नहीं है")),
        );
      }
      return; // tab switch nahi karna, isliye yahin ruk jaayenge
    }

    setState(() => _currentTab = index);
    if (index == 2 && !_audioLoaded) {
      _loadSongs();
    }
  },
  destinations: const [
    NavigationDestination(
        icon: Icon(Icons.video_library), label: "Videos"),
    NavigationDestination(
        icon: Icon(Icons.play_circle_fill, size: 36),  // 👈 bada size
        label: "Play"),
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
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) _loadRecent();
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
                  const SizedBox(height: 2),
                  // रेज़ॉल्यूशन और साइज़
                  Text(
                    "${item['res'] ?? ''} | ${item['size'] ?? ''}",
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 0),
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
                        onPressed: () => _showVideoOptions(context, item, index),
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

  void _showVideoOptions(BuildContext context, Map<String, String> item, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text("Details", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showVideoDetails(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text("Rename", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _renameVideo(item, index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteVideo(item, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<Map<String, String>> _loadCustomNames() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_names') ?? [];
    final map = <String, String>{};
    for (final s in list) {
      final i = s.indexOf('|||');
      if (i > 0) map[s.substring(0, i)] = s.substring(i + 3);
    }
    return map;
  }

  Future<void> _saveCustomName(String id, String name) async {
    final map = await _loadCustomNames();
    map[id] = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'custom_names',
      map.entries.map((e) => '${e.key}|||${e.value}').toList(),
    );
  }
  
  int _sortMode = 0;

  double _sizeToMb(String? s) {
    if (s == null || s.isEmpty) return 0;
    final p = s.split(' ');
    final v = double.tryParse(p[0]) ?? 0;
    return (p.length > 1 && p[1] == 'GB') ? v * 1024 : v;
  }

  void _sortList(List<Map<String, String>> list) {
    int idOf(Map<String, String> m) => int.tryParse(m['id'] ?? '') ?? 0;
    switch (_sortMode) {
      case 1:
        list.sort((a, b) => idOf(a).compareTo(idOf(b)));
        break;
      case 2:
        list.sort((a, b) => (a['title'] ?? '')
            .toLowerCase()
            .compareTo((b['title'] ?? '').toLowerCase()));
        break;
      case 3:
        list.sort((a, b) =>
            _sizeToMb(b['size']).compareTo(_sizeToMb(a['size'])));
        break;
      default:
        list.sort((a, b) => idOf(b).compareTo(idOf(a)));
    }
  }

  void _showSortMenu() {
    final options = [
      'नया पहले',
      'पुराना पहले',
      'नाम (A से Z)',
      'साइज़ (बड़ा पहले)'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(options.length, (i) {
              return ListTile(
                leading: Icon(
                  _sortMode == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _sortMode == i ? Colors.blueAccent : Colors.white54,
                ),
                title: Text(options[i],
                    style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    _sortMode = i;
                    _sortList(videoList);
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('sort_mode', i);
                },
              );
            }),
          ),
        );
      },
    );
  }
  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _loadMusicData() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteIds = (prefs.getStringList('favorite_songs') ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();
    _recentSongIds = (prefs.getStringList('recent_songs') ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
    final pl = prefs.getStringList('user_playlists') ?? [];
    final map = <String, List<int>>{};
    for (final s in pl) {
      final i = s.indexOf('|||');
      if (i <= 0) continue;
      map[s.substring(0, i)] = s
          .substring(i + 3)
          .split(',')
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toList();
    }
    _playlists = map;
  }

  Future<void> _addRecentSong(int id) async {
    if (_recentSongIds.isNotEmpty && _recentSongIds.first == id) return;
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('recent_songs') ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
    list.remove(id);
    list.insert(0, id);
    if (list.length > 50) list.removeRange(50, list.length);
    await prefs.setStringList(
        'recent_songs', list.map((e) => e.toString()).toList());
    if (mounted) setState(() => _recentSongIds = list);
  }

  Future<void> _toggleFavorite(SongModel song) async {
    setState(() {
      if (_favoriteIds.contains(song.id)) {
        _favoriteIds.remove(song.id);
      } else {
        _favoriteIds.add(song.id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'favorite_songs', _favoriteIds.map((e) => e.toString()).toList());
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'user_playlists',
      _playlists.entries.map((e) => '${e.key}|||${e.value.join(",")}').toList(),
    );
  }

  Future<String?> _askPlaylistName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title:
            const Text("नई Playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Playlist का नाम"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Create")),
        ],
      ),
    );
    if (name == null) return null;
    final clean = name.replaceAll('|', '').replaceAll(',', '').trim();
    return clean.isEmpty ? null : clean;
  }

  Future<void> _createPlaylist() async {
    final name = await _askPlaylistName();
    if (name == null) return;
    if (_playlists.containsKey(name)) {
      _toast("इस नाम की Playlist पहले से है");
      return;
    }
    setState(() => _playlists[name] = []);
    await _savePlaylists();
  }

  Future<void> _addSongToPlaylist(String name, SongModel song) async {
    final list = _playlists[name] ?? [];
    if (!list.contains(song.id)) list.add(song.id);
    setState(() => _playlists[name] = list);
    await _savePlaylists();
    _toast("'$name' में जोड़ दिया");
  }

  void _addToPlaylistDialog(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add, color: Colors.blueAccent),
                title: const Text("नई Playlist बनाएँ",
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = await _askPlaylistName();
                  if (name == null) return;
                  if (!_playlists.containsKey(name)) {
                    setState(() => _playlists[name] = []);
                  }
                  await _addSongToPlaylist(name, song);
                },
              ),
              ..._playlists.keys.map((name) => ListTile(
                    leading:
                        const Icon(Icons.queue_music, color: Colors.white),
                    title: Text(name,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _addSongToPlaylist(name, song);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePlaylist(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: Text("'$name' हटाएँ?",
            style: const TextStyle(color: Colors.white)),
        content: const Text("सिर्फ़ Playlist हटेगी, गाने फोन में रहेंगे।",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _playlists.remove(name));
    await _savePlaylists();
  }

  List<SongModel> _songsByIds(List<int> ids) {
    final byId = {for (final s in _songs) s.id: s};
    final out = <SongModel>[];
    for (final id in ids) {
      final s = byId[id];
      if (s != null) out.add(s);
    }
    return out;
  }

  void _openSongList(String title, List<SongModel> songs) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SongListScreen(title: title, songs: songs)),
    );
  }

  Widget _songTile(int index) {
    final song = _songs[index];
    final nowTag = globalAudioPlayer.sequenceState?.currentSource?.tag;
    final isPlaying = nowTag is MediaItem && nowTag.id == song.id.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AudioPlayerScreen(songs: _songs, initialIndex: index),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xff2D8CFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                  isPlaying ? Icons.graphic_eq : Icons.music_note,
                  color: isPlaying
                      ? const Color(0xff2D8CFF)
                      : Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(globalSongNames[song.id] ?? song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(song.artist ?? "Unknown",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (_favoriteIds.contains(song.id))
              const Icon(Icons.favorite, color: Colors.pinkAccent, size: 16),
            IconButton(
              onPressed: () => _showSongOptions(song),
              icon: const Icon(Icons.more_vert,
                  color: Colors.white60, size: 20),
              padding: const EdgeInsets.only(left: 8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTile(IconData icon, String name, int count, VoidCallback onTap,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xff2D8CFF), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("$count songs",
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _musicBox(String title, IconData icon, Color color, int count,
      VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text("$count songs",
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _onMusicDataChanged() async {
    await _loadMusicData();
    if (mounted) setState(() {});
  }

  void _openNowPlaying() {
    final seq =
        globalAudioPlayer.sequenceState?.sequence ?? <IndexedAudioSource>[];
    final byId = {for (final s in _songs) s.id: s};
    final list = <SongModel>[];
    for (final src in seq) {
      final t = src.tag;
      if (t is MediaItem) {
        final s = byId[int.tryParse(t.id)];
        if (s != null) list.add(s);
      }
    }
    if (list.isEmpty) return;
    int idx = 0;
    final cur = globalAudioPlayer.sequenceState?.currentSource?.tag;
    if (cur is MediaItem) {
      final i = list.indexWhere((s) => s.id.toString() == cur.id);
      if (i >= 0) idx = i;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPlayerScreen(songs: list, initialIndex: idx),
      ),
    );
  }

  Widget _miniPlayer() {
  return ValueListenableBuilder<int>(
    valueListenable: musicDataNotifier,
    builder: (context, _, __) {
      return StreamBuilder<SequenceState?>(
        stream: globalAudioPlayer.sequenceStateStream,
        builder: (context, snapshot) {
          final tag = snapshot.data?.currentSource?.tag;
          if (tag is! MediaItem) return const SizedBox.shrink();
          return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openNowPlaying,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xff1A1D24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xff2D8CFF).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq, color: Color(0xff2D8CFF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
  Builder(builder: (_) {
    final id = int.tryParse(tag.id);
    final displayTitle = (id != null &&
            globalSongNames.containsKey(id))
        ? globalSongNames[id]!
        : tag.title;
    return Text(displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold));
  }),
  Text(tag.artist ?? "Unknown",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
               StreamBuilder<bool>(
                stream: globalAudioPlayer.playingStream,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return IconButton(
                    onPressed: () => playing
                        ? globalAudioPlayer.pause()
                        : globalAudioPlayer.play(),
                    icon: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 30),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
      );  // 👈 StreamBuilder का closing
    },    // 👈 ValueListenableBuilder का builder closing
  );      // 👈 ValueListenableBuilder का closing
}         // 👈 method closing
  
  Widget _buildMusicTab() {
  if (_audioPermissionDenied) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off, color: Colors.white54, size: 60),
            const SizedBox(height: 16),
            const Text(
              "Music access permission चाहिए",
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text("Settings खोलें"),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _audioPermissionDenied = false;
                  _audioLoaded = false;
                });
                _loadSongs();
              },
              child: const Text("फिर कोशिश करें"),
            ),
          ],
        ),
      ),
    );
  }
  if (_songs.isEmpty) {
    return const Center(
      child: Text("कोई गाना नहीं मिला",
          style: TextStyle(color: Colors.white54, fontSize: 16)),
    );
  }
    const tabs = ['All Songs', 'Playlist', 'Folder', 'Artist'];
    final recent = _songsByIds(_recentSongIds);
    final favs = _songsByIds(_favoriteIds.toList().reversed.toList());
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: List.generate(tabs.length, (i) {
              final sel = _musicSubTab == i;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _musicSubTab = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tabs[i],
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                              color: sel
                                  ? const Color(0xff2D8CFF)
                                  : Colors.white54)),
                      const SizedBox(height: 4),
                      Container(
                          height: 3,
                          width: 28,
                          color: sel
                              ? const Color(0xff2D8CFF)
                              : Colors.transparent),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: _musicBox("Recently Played", Icons.history,
                    Colors.orangeAccent, recent.length,
                    () => _openSongList("Recently Played", recent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _musicBox("Favorite", Icons.favorite,
                    Colors.pinkAccent, favs.length,
                    () => _openSongList("Favorite", favs)),
              ),
            ],
          ),
        ),
        Expanded(child: _buildMusicContent()),
        _miniPlayer(),
      ],
    );
  }
  
  Widget _buildMusicContent() {
  if (_musicSubTab == 1) {
    final names = _playlists.keys.toList();
    return Column(
      children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(
              children: [
                Text("Playlist (${names.length})",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _createPlaylist,
                  icon: const Icon(Icons.add, color: Colors.white70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: names.isEmpty
                ? const Center(
                    child: Text("अभी कोई Playlist नहीं है, ऊपर + दबाकर बनाओ",
                        style: TextStyle(color: Colors.white54, fontSize: 15),
                        textAlign: TextAlign.center))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    itemCount: names.length,
                    itemBuilder: (context, index) {
                      final name = names[index];
                      final list = _songsByIds(_playlists[name] ?? []);
                      return _groupTile(
                        Icons.queue_music,
                        name,
                        list.length,
                        () => _openSongList(name, list),
                        trailing: IconButton(
                          onPressed: () => _deletePlaylist(name),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }
    if (_musicSubTab == 2 || _musicSubTab == 3) {
      final groups = <String, List<SongModel>>{};
      for (final s in _songs) {
        String key;
        if (_musicSubTab == 2) {
          final p = s.data;
          final i = p.lastIndexOf('/');
          final parent = i > 0 ? p.substring(0, i) : '';
          key = parent.isEmpty
              ? 'Unknown'
              : parent.substring(parent.lastIndexOf('/') + 1);
        } else {
          final a = s.artist ?? '';
          key = (a.isEmpty || a == '<unknown>') ? 'Unknown' : a;
        }
        groups.putIfAbsent(key, () => []).add(s);
      }
      final keys = groups.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final key = keys[index];
          final list = groups[key]!;
          return _groupTile(
            _musicSubTab == 2 ? Icons.folder : Icons.person,
            key,
            list.length,
            () => _openSongList(key, list),
          );
        },
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Row(
            children: [
              Text("All Songs (${_songs.length})",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: _showSongSortMenu,
                icon: const Icon(Icons.sort, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
              const SizedBox(height: 8),
      Expanded(
        child: RefreshIndicator(
          color: const Color(0xff2D8CFF),
          backgroundColor: const Color(0xff1A1D24),
          onRefresh: () async {
            setState(() {
              _audioLoaded = false;
              _songs = [];
            });
            await _loadSongs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _songs.length,
            itemBuilder: (context, index) => _songTile(index),
          ),
        ),
      ),
    ],
  );
  }
  int _songSortMode = 0;

  void _sortSongs(List<SongModel> list) {
    switch (_songSortMode) {
      case 1:
        list.sort((a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
        break;
      case 2:
        list.sort((a, b) => (globalSongNames[a.id] ?? a.title)
            .toLowerCase()
            .compareTo((globalSongNames[b.id] ?? b.title).toLowerCase()));
        break;
      default:
        list.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    }
  }

  void _showSongSortMenu() {
    final options = ['नया गाना पहले', 'पुराना गाना पहले', 'नाम (A से Z)'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(options.length, (i) {
              return ListTile(
                leading: Icon(
                  _songSortMode == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color:
                      _songSortMode == i ? Colors.blueAccent : Colors.white54,
                ),
                title: Text(options[i],
                    style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    _songSortMode = i;
                    _sortSongs(_songs);
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('song_sort_mode', i);
                },
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _loadSongNames() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_song_names') ?? [];
    globalSongNames.clear();
    for (final s in list) {
      final i = s.indexOf('|||');
      if (i > 0) {
        final id = int.tryParse(s.substring(0, i));
        if (id != null) globalSongNames[id] = s.substring(i + 3);
      }
    }
  }

  Future<void> _saveSongNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'custom_song_names',
      globalSongNames.entries.map((e) => '${e.key}|||${e.value}').toList(),
    );
  }

  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text("Details",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showSongDetails(song);
                },
              ),
              ListTile(
                leading: Icon(
                  _favoriteIds.contains(song.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.pinkAccent,
                ),
                title: Text(
                    _favoriteIds.contains(song.id)
                        ? "Favorite से हटाएँ"
                        : "Favorite में जोड़ें",
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text("Playlist में जोड़ें",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _addToPlaylistDialog(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text("Rename",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _renameSong(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text("Delete",
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSong(song);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSongDetails(SongModel song) {
    final d = Duration(milliseconds: song.duration ?? 0);
    final dur =
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: Text(globalSongNames[song.id] ?? song.title,
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Artist: ${song.artist ?? 'Unknown'}",
                style: const TextStyle(color: Colors.white70)),
            Text("Duration: $dur",
                style: const TextStyle(color: Colors.white70)),
            Text("Size: ${_formatSize(song.size)}",
                style: const TextStyle(color: Colors.white70)),
            Text("Path: ${song.data}",
                style: const TextStyle(color: Colors.white70),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _renameSong(SongModel song) async {
    final controller =
        TextEditingController(text: globalSongNames[song.id] ?? song.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text("Rename Song",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "नया नाम डालें"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final cleanName = newName.replaceAll('|', '');
    if (cleanName.isEmpty) return;
    globalSongNames[song.id] = cleanName;
    await _saveSongNames();
    if (!mounted) return;
    setState(() {
     _sortSongs(_songs);
  musicDataNotifier.value++; // 👈 Mini Player को refresh करने के लिए
});
  }

  Future<void> _deleteSong(SongModel song) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xff1A1D24),
      title: const Text("गाना डिलीट करें?",
          style: TextStyle(color: Colors.white)),
      content: const Text("ये गाना डिवाइस से हमेशा के लिए हट जाएगा।",
          style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel")),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete",
              style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  // 👇 नया: File से सीधे delete (MediaStore update अपने आप होगा)
  try {
    final file = File(song.data);
    if (await file.exists()) {
      await file.delete();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("फ़ाइल नहीं मिली")),
        );
      }
      return;
    }
  } catch (e) {
    debugPrint("Song delete error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("डिलीट नहीं हो पाया: $e")),
      );
    }
    return;
  }

  globalSongNames.remove(song.id);
  await _saveSongNames();

  // 👇 favorites/recent से भी निकालो
  final prefs = await SharedPreferences.getInstance();
  _favoriteIds.remove(song.id);
  _recentSongIds.remove(song.id);
  await prefs.setStringList(
      'favorite_songs', _favoriteIds.map((e) => e.toString()).toList());
  await prefs.setStringList(
      'recent_songs', _recentSongIds.map((e) => e.toString()).toList());

  if (!mounted) return;
  setState(() => _songs.removeWhere((s) => s.id == song.id));
  }
  void _showVideoDetails(Map<String, String> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: Text(item['title'] ?? 'Details',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Resolution: ${item['res']}", style: const TextStyle(color: Colors.white70)),
            Text("Duration: ${item['duration']}", style: const TextStyle(color: Colors.white70)),
            Text("Size: ${item['size']}", style: const TextStyle(color: Colors.white70)),
            Text("Folder: ${item['folder']}", style: const TextStyle(color: Colors.white70)),
            Text("Path: ${item['url']}",
                style: const TextStyle(color: Colors.white70),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _renameVideo(Map<String, String> item, int index) async {
    final controller = TextEditingController(text: item['title']);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text("Rename Video", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "नया नाम डालें"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    final cleanName = newName.replaceAll('|', '');
    if (cleanName.isEmpty) return;
    final vid = videoList[index]['id'];
    if (vid != null && vid.isNotEmpty) {
      await _saveCustomName(vid, cleanName);
    }
    setState(() => videoList[index]['title'] = cleanName);

    final prefs = await SharedPreferences.getInstance();
    final toSave = videoList
        .map((m) =>
            "${m['title']}|||${m['res']}|||${m['size']}|||${m['source']}|||${m['duration']}|||${m['url']}|||${m['folder']}|||${m['id'] ?? ''}")
        .toList();
    await prefs.setStringList('cached_videos', toSave);
  }

  Future<void> _deleteVideo(Map<String, String> item, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text("वीडियो डिलीट करें?", style: TextStyle(color: Colors.white)),
        content: const Text("ये वीडियो डिवाइस से हमेशा के लिए हट जाएगी।",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = item['id'];
    if (id != null && id.isNotEmpty) {
      final result = await PhotoManager.editor.deleteWithIds([id]);
      if (result.isEmpty) return;
    } else {
      try {
        await File(item['url']!).delete();
      } catch (e) {
        debugPrint("Delete error: $e");
        return;
      }
    }

    setState(() => videoList.removeAt(index));
    final prefsR = await SharedPreferences.getInstance();
    if (prefsR.getString('recent_url') == item['url']) {
      await prefsR.remove('recent_title');
      await prefsR.remove('recent_url');
      await prefsR.remove('recent_position');
      await prefsR.remove('recent_duration');
      if (mounted) {
        setState(() {
          _recentTitle = null;
          _recentUrl = null;
        });
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    final toSave = videoList
        .map((m) =>
            "${m['title']}|||${m['res']}|||${m['size']}|||${m['source']}|||${m['duration']}|||${m['url']}|||${m['folder']}|||${m['id'] ?? ''}")
        .toList();
    await prefs.setStringList('cached_videos', toSave);
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
  bool _hasError = false;           // 👈 नया
  String _errorMessage = '';        // 👈 नया

  double _speed = 1.0;
  double _volume = 1.0;
  double _brightness = 0.8;
  double _dragSeekSeconds = 0;
  bool _isDraggingSeek = false;
  bool _isFullscreen = false;
  bool _replacing = false;
  bool _showGestureIndicator = false;
  String _gestureText = '';

@override
void initState() {
  super.initState();
  _loadSavedSpeed(); // 👈 नया
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

WakelockPlus.enable(); // 👈 नया

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
  _controller.setPlaybackSpeed(_speed);   // 👈 यही नई line जोड़ो   
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
      if (mounted) setState(() {});
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
    _replacing = true;
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
    _replacing = true;
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
          onTap: () async {
              _controller.setPlaybackSpeed(speed);
             setState(() => _speed = speed);
             final prefs = await SharedPreferences.getInstance();
             await prefs.setDouble('video_speed', speed); // 👈 ये line
             if (context.mounted) Navigator.pop(context);
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
        recentChangedNotifier.value++;
  }


  Future<void> _saveProgressData(String title, String url, int pos, int dur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_title', title);
    await prefs.setString('recent_url', url);
    await prefs.setInt('recent_position', pos);
    await prefs.setInt('recent_duration', dur); recentChangedNotifier.value++;
  }

  @override
void dispose() {
  final title = widget.title;
  final url = widget.videoUrl;
  final position = _controller.value.position.inSeconds;
  final duration = _controller.value.duration.inSeconds;

  _hideTimer?.cancel();
WakelockPlus.disable(); // 👈 नया
_controller.dispose();
  // 👇 नया: Brightness वापस default पर
  try {
    ScreenBrightness().resetScreenBrightness();
  } catch (_) {}

  if (!_replacing) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  if (position >= 5) {
    _saveProgressData(title, url, position, duration);
  }
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
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
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          )
        : GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _toggleControls,
    onDoubleTapDown: (details) {
      final w = MediaQuery.of(context).size.width;
      if (details.globalPosition.dx < w / 2) {
        _skipBackward();
      } else {
        _skipForward();
      }
    },
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

// एक साथ सिर्फ़ 3 thumbnail बनते हैं (पहली बार app खोलने पर crash न हो)
class _ThumbQueue {
  static const int _maxParallel = 3;
  static int _running = 0;
  static final List<Completer<void>> _waiting = [];

  static Future<void> acquire() async {
    if (_running < _maxParallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  static void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailBytes;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _thumbnailBytes = null;
      _loadOrGenerateThumbnail();
    }
  }

  String _cacheFileName(String path) => 'thumb_${path.hashCode}.jpg';

  Future<void> _loadOrGenerateThumbnail() async {
    final path = widget.videoPath;
    try {
      final cacheFile =
          File('${Directory.systemTemp.path}/${_cacheFileName(path)}');
      Uint8List? bytes;

      try {
        if (await cacheFile.exists()) {
          bytes = await cacheFile.readAsBytes();
        }
      } catch (_) {}

      if (bytes == null) {
        await _ThumbQueue.acquire();
        try {
          if (!mounted || path != widget.videoPath) return;
          bytes = await VideoThumbnail.thumbnailData(
            video: path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200,
            quality: 50,
          );
          if (bytes != null) {
            try {
              await cacheFile.writeAsBytes(bytes);
            } catch (_) {}
          }
        } finally {
          _ThumbQueue.release();
        }
      }

      if (mounted && bytes != null && path == widget.videoPath) {
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
        gaplessPlayback: true,
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

  int _loopMode = 0;
  Set<int> _favoriteIds = {};

  StreamSubscription<int?>? _currentIndexSubscription;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _player = globalAudioPlayer;

    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && mounted) {
        setState(() => _currentIndex = index);
      }
    });

    if (_player.loopMode == LoopMode.one) {
      _loopMode = 1;
    } else if (_player.shuffleModeEnabled) {
      _loopMode = 2;
    } else {
      _loopMode = 0;
    }

    _loadFavorites();

    final currentTag = _player.sequenceState?.currentSource?.tag;
    final selectedId = widget.songs.isNotEmpty
        ? widget.songs[_currentIndex].id.toString()
        : '';
    if (currentTag is MediaItem &&
        currentTag.id == selectedId &&
        (_player.sequence?.length ?? 0) == widget.songs.length) {
      _currentIndex = _player.currentIndex ?? _currentIndex;
    } else {
      _setupPlaylist();
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('favorite_songs') ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();
    if (mounted) setState(() => _favoriteIds = ids);
  }

  Future<void> _setupPlaylist() async {
    try {
      final sources = widget.songs.map((song) {
        return AudioSource.uri(
          Uri.parse('content://media/external/audio/media/${song.id}'),
          tag: MediaItem(
            id: song.id.toString(),
            album: "VeoPlay",
            title: globalSongNames[song.id] ?? song.title,
            artist: song.artist ?? "Unknown",
          ),
        );
      }).toList();

      await _player.setAudioSource(
    ConcatenatingAudioSource(children: sources),
    initialIndex: _currentIndex,
);
await _player.play();
    } catch (e) {
      if (mounted) setState(() => _setupError = e.toString());
    }
  }

  void _togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

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

  Future<void> _toggleLoop() async {
    setState(() {
      _loopMode = (_loopMode + 1) % 3;
    });

    if (_loopMode == 0) {
      await _player.setShuffleModeEnabled(false);
      await _player.setLoopMode(LoopMode.off);
    } else if (_loopMode == 1) {
      await _player.setShuffleModeEnabled(false);
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.all);
      await _player.setShuffleModeEnabled(true);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleFavorite(SongModel song) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('favorite_songs') ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();

    setState(() {
      if (list.contains(song.id)) {
        list.remove(song.id);
      } else {
        list.add(song.id);
      }
      _favoriteIds = list;
    });

    await prefs.setStringList(
      'favorite_songs',
      list.map((e) => e.toString()).toList(),
    );
    musicDataNotifier.value++;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_favoriteIds.contains(song.id)
              ? "❤️ Added to Favorite"
              : "Removed from Favorite"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _showEqualizerDialog() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('AudioSession error: $e');
    }

    double bass = 1.0, mid = 1.0, treble = 1.0;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Equalizer",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _eqSlider("Bass", bass, (v) {
                    setModalState(() => bass = v);
                  }),
                  _eqSlider("Mid", mid, (v) {
                    setModalState(() => mid = v);
                  }),
                  _eqSlider("Treble", treble, (v) {
                    setModalState(() => treble = v);
                  }),
                  const SizedBox(height: 12),
                  const Text("Presets",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _presetBtn("Normal", () {
                        setModalState(() {
                          bass = 1.0; mid = 1.0; treble = 1.0;
                        });
                      }),
                      _presetBtn("Bass Boost", () {
                        setModalState(() {
                          bass = 1.7; mid = 1.0; treble = 0.9;
                        });
                      }),
                      _presetBtn("Vocal", () {
                        setModalState(() {
                          bass = 0.9; mid = 1.5; treble = 1.2;
                        });
                      }),
                      _presetBtn("Rock", () {
                        setModalState(() {
                          bass = 1.4; mid = 1.1; treble = 1.5;
                        });
                      }),
                      _presetBtn("Pop", () {
                        setModalState(() {
                          bass = 1.2; mid = 1.2; treble = 1.3;
                        });
                      }),
                      _presetBtn("Classical", () {
                        setModalState(() {
                          bass = 1.3; mid = 1.0; treble = 1.3;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Note: Equalizer effect device ke audio hardware par depend karta hai",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _eqSlider(String label, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: const Color(0xff2D8CFF),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xff2D8CFF),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                min: 0.5,
                max: 2.0,
                divisions: 30,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetBtn(String name, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff2D8CFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: onTap,
      child: Text(name, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _showAddToPlaylistDialog(SongModel song) async {
    final prefs = await SharedPreferences.getInstance();
    final pl = prefs.getStringList('user_playlists') ?? [];
    final playlists = <String, List<int>>{};
    for (final s in pl) {
      final i = s.indexOf('|||');
      if (i <= 0) continue;
      playlists[s.substring(0, i)] = s
          .substring(i + 3)
          .split(',')
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toList();
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Add to Playlist",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.blueAccent),
                title: const Text("Create New Playlist",
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final controller = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xff1A1D24),
                      title: const Text("New Playlist",
                          style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Enter playlist name",
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          child: const Text("Create"),
                        ),
                      ],
                    ),
                  );
                  if (name == null || name.isEmpty) return;
                  final clean =
                      name.replaceAll('|', '').replaceAll(',', '').trim();
                  if (clean.isEmpty) return;

                  playlists[clean] = [song.id];
                  await prefs.setStringList(
                    'user_playlists',
                    playlists.entries
                        .map((e) => '${e.key}|||${e.value.join(",")}')
                        .toList(),
                  );
                  musicDataNotifier.value++;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("✅ Created '$clean' & added song"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "No playlist yet. Create one!",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ...playlists.keys.map((name) => ListTile(
                    leading: const Icon(Icons.queue_music,
                        color: Colors.white),
                    title: Text(name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      "${playlists[name]!.length} songs",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final list = playlists[name] ?? [];
                      if (!list.contains(song.id)) {
                        list.add(song.id);
                        playlists[name] = list;
                        await prefs.setStringList(
                          'user_playlists',
                          playlists.entries
                              .map((e) =>
                                  '${e.key}|||${e.value.join(",")}')
                              .toList(),
                        );
                        musicDataNotifier.value++;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("✅ Added to '$name'"),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Already in playlist"),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _currentIndexSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xff0B0D12),
        body: Center(
          child: Text("No songs found",
              style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_setupError != null) {
      return Scaffold(
        backgroundColor: const Color(0xff0B0D12),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SelectableText(
              "ERROR:\n$_setupError",
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final song = widget.songs[_currentIndex];
    final songTitle = globalSongNames[song.id] ?? song.title;
    final isFav = _favoriteIds.contains(song.id);

    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff2D8CFF), Color(0xff6B4DFF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.music_note,
                  color: Colors.white, size: 100),
            ),
            const SizedBox(height: 40),
            Text(
              songTitle,
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
            Text(
              song.artist ?? "Unknown",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showAddToPlaylistDialog(song),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff2D8CFF).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: _showEqualizerDialog,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff2D8CFF).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.equalizer,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => _toggleFavorite(song),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFav
                          ? Colors.pinkAccent.withOpacity(0.2)
                          : Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFav
                            ? Colors.pinkAccent
                            : const Color(0xff2D8CFF).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.pinkAccent : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final maxSeconds = duration.inSeconds > 0
                        ? duration.inSeconds.toDouble()
                        : 1.0;
                    final currentSeconds = position.inSeconds
                        .toDouble()
                        .clamp(0.0, maxSeconds);

                    return Column(
                      children: [
                        Slider(
                          value: currentSeconds,
                          min: 0,
                          max: maxSeconds,
                          activeColor: const Color(0xff2D8CFF),
                          inactiveColor: Colors.white24,
                          onChanged: duration.inSeconds > 0
                              ? (value) {
                                  _player.seek(
                                    Duration(seconds: value.toInt()),
                                  );
                                }
                              : null,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position),
                                style: const TextStyle(color: Colors.white70)),
                            Text(_formatDuration(duration),
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _loopMode == 0
                        ? Icons.repeat
                        : _loopMode == 1
                            ? Icons.repeat_one
                            : Icons.shuffle,
                    color: _loopMode == 0
                        ? Colors.white54
                        : const Color(0xff2D8CFF),
                    size: 24,
                  ),
                  onPressed: _toggleLoop,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 32),
                  onPressed: _playPrevious,
                ),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xff2D8CFF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white, size: 32),
                  onPressed: _playNext,
                ),
                IconButton(
                  icon: const Icon(Icons.speed,
                      color: Colors.white54, size: 24),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xff1A1D24),
                      builder: (context) {
                        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: speeds.map((s) {
                              return ChoiceChip(
                                label: Text('${s}x',
                                    style: TextStyle(
                                      color: _player.speed == s
                                          ? Colors.white
                                          : Colors.white70,
                                    )),
                                selected: _player.speed == s,
                                selectedColor: const Color(0xff2D8CFF),
                                backgroundColor: Colors.white10,
                                onSelected: (_) {
                                  _player.setSpeed(s);
                                  Navigator.pop(context);
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
      
  class SongListScreen extends StatefulWidget {
  final String title;
  final List<SongModel> songs;
  const SongListScreen({super.key, required this.title, required this.songs});

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.title)),
      body: widget.songs.isEmpty
          ? const Center(
              child: Text("यहाँ अभी कोई गाना नहीं है",
                  style: TextStyle(color: Colors.white54, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: widget.songs.length,
              itemBuilder: (context, index) {
                final song = widget.songs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AudioPlayerScreen(
                            songs: widget.songs, initialIndex: index),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xff2D8CFF).withOpacity(0.2),
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
                              Text(globalSongNames[song.id] ?? song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(song.artist ?? "Unknown",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
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
