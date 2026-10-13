part of 'main.dart';

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
bool _audioPermissionDenied = false;
bool _audioLoading = false; // 👈 नया
  
  String? _recentTitle;
  String? _recentUrl;
  int _recentPosition = 0;
  int _recentDuration = 0;
  int _musicSubTab = 0;
  Set<int> _favoriteIds = {};
  List<int> _recentSongIds = [];
  Map<String, List<int>> _playlists = {};
  StreamSubscription<dynamic>? _seqSub;
  Set<String> _favoriteVideoIds = {};   // 👈 नई line

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
    _loadFavoriteVideos();   // 👈 नई line
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
      _quickSyncVideos();
      _quickSyncSongs();
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

 
Future<void> _loadFavoriteVideos() async {
  final prefs = await SharedPreferences.getInstance();
  final ids = (prefs.getStringList('favorite_videos') ?? []).toSet();
  if (mounted) setState(() => _favoriteVideoIds = ids);
}

Future<void> _toggleVideoFavorite(Map<String, String> item) async {
  final id = item['id'];
  if (id == null || id.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    if (_favoriteVideoIds.contains(id)) {
      _favoriteVideoIds.remove(id);
    } else {
      _favoriteVideoIds.add(id);
    }
  });
  await prefs.setStringList('favorite_videos', _favoriteVideoIds.toList());
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_favoriteVideoIds.contains(id)
            ? '❤️ Favorite में जोड़ा'
            : 'Favorite से हटाया'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
  
  Future<void> _loadSongs() async {
if (_audioLoaded) {
  _quickSyncSongs();
  return;
}
if (mounted) setState(() => _audioLoading = true); // 👈 नया
final OnAudioQuery audioQuery = OnAudioQuery();
bool hasPermission = await audioQuery.checkAndRequest(retryRequest: true);
if (!hasPermission) {
  if (mounted) {
    setState(() {
      _audioPermissionDenied = true;
      _audioLoading = false; // 👈
    });
  }
  return;
}
if (mounted) {
  setState(() {
    _audioPermissionDenied = false;
    // _audioLoading बाद में false होगा, डेटा मिलने पर
  });
}
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
    _audioLoading = false; // 👈 नया
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
      _quickSyncVideos();
      return;
    }
    await _scanVideos();
  }

  Future<void> _refreshVideosInBackground() async {
    await _scanVideos(silent: true);
  }
  bool _syncingVideos = false;
  Future<void> _quickSyncVideos() async {
    if (_syncingVideos) return;
    _syncingVideos = true;
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) return;
      PhotoManager.setIgnorePermissionCheck(true);
      final albums = await PhotoManager.getAssetPathList(
          type: RequestType.video, onlyAll: true);
      if (albums.isEmpty) return;
      final count = await albums[0].assetCountAsync;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('last_video_count') != count) {
        await _scanVideos(silent: true);
      }
    } catch (e) {
      debugPrint('Quick video sync error: $e');
    } finally {
      _syncingVideos = false;
    }
  }

  bool _syncingSongs = false;
  Future<void> _quickSyncSongs() async {
    if (!_audioLoaded || _syncingSongs) return;
    _syncingSongs = true;
    try {
      final fresh = await OnAudioQuery().querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );
      final oldIds = _songs.map((s) => s.id).toSet();
      final newIds = fresh.map((s) => s.id).toSet();
      if (oldIds.length == newIds.length && oldIds.containsAll(newIds)) {
        return;
      }
      final sorted = List<SongModel>.of(fresh);
      _sortSongs(sorted);
      if (!mounted) return;
      setState(() => _songs = sorted);
    } catch (e) {
      debugPrint('Quick song sync error: $e');
    } finally {
      _syncingSongs = false;
    }
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
      if (file != null && file.existsSync()) {
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
    await prefs.setInt('last_video_count', count);
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
      backgroundColor: AppTheme.bg,
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
            Text("VeoPlay",
    style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary)),
          ],
        ),
        actions: [
  IconButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoSearchScreen(videos: videoList),
      ),
    );
  },
  icon: Icon(Icons.search, color: AppTheme.textPrimary),
),
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      },
      child: CircleAvatar(
  radius: 18,
  backgroundColor: const Color(0xff2D8CFF).withOpacity(0.2),
  child: const Icon(Icons.person, color: Color(0xff2D8CFF), size: 20),
),
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
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                        Icon(Icons.folder_off, color: AppTheme.textSecondary, size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          "Video access permission चाहिए",
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 16),
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
                      try {
                        await PhotoManager.editor.android.removeAllNoExistsAsset();
                      } catch (_) {}
                        await _scanVideos(silent: true);
                        await _loadRecent();
                      },
                      child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_recentTitle != null) ...[
                            Text("Recent",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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
                                        color: !_showPlaylist ? AppTheme.textPrimary : AppTheme.textTertiary
                              ),
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showPlaylist = true),
                                child: Text("Playlist",
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: _showPlaylist ? AppTheme.textPrimary : AppTheme.textTertiary
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
                                                  Text(folderName, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
  backgroundColor: AppTheme.card,
  indicatorColor: const Color(0xff2D8CFF).withOpacity(0.2),
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // रेज़ॉल्यूशन और साइज़
                Text(
                  "${item['res'] ?? ''} | ${item['size'] ?? ''}",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 0),
                // सोर्स और more_vert आइकन वाली Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['source'] ?? '',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
  children: [
    Expanded(
      child: Text(
        item['source'] ?? '',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    IconButton(                                          // 👈 नया Heart button
      onPressed: () => _toggleVideoFavorite(item),
      icon: Icon(
        _favoriteVideoIds.contains(item['id'])
            ? Icons.favorite
            : Icons.favorite_border,
        color: _favoriteVideoIds.contains(item['id'])
            ? Colors.pinkAccent
            : Colors.white60,
        size: 18,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
    const SizedBox(width: 4),                             // 👈 नया spacing
    IconButton(                                          // 👈 पुराना Menu button
      onPressed: () => _showVideoOptions(context, item, index),
      icon: Icon(Icons.more_vert, color: AppTheme.iconColor, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
  ],
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

Future<void> _playNextSong(SongModel song) async {
  try {
    if (globalAudioPlayer.sequence == null ||
        globalAudioPlayer.sequence!.isEmpty) {
      _toast('पहले कोई गाना चलाओ');
      return;
    }
    final source = AudioSource.uri(
      Uri.parse('content://media/external/audio/media/${song.id}'),
      tag: MediaItem(
        id: song.id.toString(),
        album: 'VeoPlay',
        title: globalSongNames[song.id] ?? song.title,
        artist: song.artist ?? 'Unknown',
      ),
    );
    final nextIndex = (globalAudioPlayer.currentIndex ?? 0) + 1;
    final current = globalAudioPlayer.audioSource;
    if (current is! ConcatenatingAudioSource) {
      _toast('अभी लिस्ट से गाना नहीं चल रहा');
      return;
    }
    await current.insert(nextIndex, source);
    _toast('"${globalSongNames[song.id] ?? song.title}" अगला चलेगा');
  } catch (e) {
    debugPrint('Play next error: $e');
    _toast('नहीं हो पाया');
  }
}

  Future<void> _shareSong(SongModel song) async {
  try {
    final file = File(song.data);
    if (!await file.exists()) {
      _toast('फ़ाइल नहीं मिली');
      return;
    }
    await Share.shareXFiles(
      [XFile(song.data, mimeType: 'audio/*')],
      subject: globalSongNames[song.id] ?? song.title,
      text: '${globalSongNames[song.id] ?? song.title}\n${song.artist ?? ''}',
    );
  } catch (e) {
    debugPrint('Song share error: $e');
    _toast('Share नहीं हो पाया');
  }
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
    musicDataNotifier.value++;
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
 
// 👇 Playlist rename
Future<void> _renamePlaylist(String oldName) async {
  final controller = TextEditingController(text: oldName);
  final newName = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xff1A1D24),
      title: const Text("Playlist का नाम बदलें",
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: "नया नाम"),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save")),
      ],
    ),
  );
  if (newName == null || newName.isEmpty) return;
  final clean = newName.replaceAll('|', '').replaceAll(',', '').trim();
  if (clean.isEmpty || clean == oldName) return;
  if (_playlists.containsKey(clean)) {
    _toast("इस नाम की Playlist पहले से है");
    return;
  }
  setState(() {
    final list = _playlists.remove(oldName) ?? [];
    _playlists[clean] = list;
  });
  await _savePlaylists();
  _toast("नाम बदल दिया");
}

// 👇 Playlist से गाना हटाओ
Future<void> _removeSongFromPlaylist(
    String playlistName, SongModel song) async {
  final list = _playlists[playlistName] ?? [];
  if (!list.contains(song.id)) return;
  setState(() {
    list.remove(song.id);
    _playlists[playlistName] = list;
  });
  await _savePlaylists();
  _toast("'$playlistName' से हटा दिया");
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

  void _openSongList(String title, List<SongModel> songs,
{String? playlistName}) {
  final isFavScreen = title == "Favorite";
  Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => SongListScreen(
              title: title,
              songs: songs,
              onMenu: _showSongOptions,
              keep: (s) =>
                  _songs.any((x) => x.id == s.id) &&
                  (title != "Favorite" || _favoriteIds.contains(s.id)),
              playlistName: playlistName,
              onRemoveFromPlaylist: playlistName == null
                  ? null
                  : (s) => _removeSongFromPlaylist(playlistName, s),
              favoriteIds: isFavScreen ? _favoriteIds : null,
              onToggleFavorite: isFavScreen
                  ? (s) async {
                      await _toggleFavorite(s);
                      if (mounted) setState(() {});
                    }
                  : null,
            )),
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
            Stack(
  children: [
    AlbumArtWidget(
      songId: song.id,
      size: 50,
      radius: 8,
      fallbackIcon:
          isPlaying ? Icons.graphic_eq : Icons.music_note,
    ),
    if (isPlaying)
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.graphic_eq,
            color: Color(0xff2D8CFF),
            size: 24,
          ),
        ),
      ),
  ],
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
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
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
                Builder(builder: (_) {
  final id = int.tryParse(tag.id);
  if (id == null) {
    return const Icon(Icons.graphic_eq,
        color: Color(0xff2D8CFF));
  }
  return AlbumArtWidget(
    songId: id,
    size: 42,
    radius: 10,
  );
}),
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
              IconButton(
                  onPressed: () => globalAudioPlayer.seekToPrevious(),
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 28),
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
              IconButton(
                  onPressed: () => globalAudioPlayer.seekToNext(),
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white, size: 28),
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
if (_audioLoading && _songs.isEmpty) {           // 👈 नया
  return const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Color(0xff2D8CFF)),
        SizedBox(height: 16),
        Text("गाने लोड हो रहे हैं...",
            style: TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    ),
  );
}
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
    Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 18),
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
                                color: sel ? const Color(0xff2D8CFF) : AppTheme.textSecondary
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
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70),
          padding: const EdgeInsets.only(right: 8),
          constraints: const BoxConstraints(),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MusicSearchScreen(
                  songs: _songs,
                  onMenu: _showSongOptions,
                ),
              ),
            );
          },
        ),
      ],
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
  () => _openSongList(name, list, playlistName: name),
  trailing: PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert,
        color: Colors.white60, size: 20),
    color: const Color(0xff1A1D24),
    onSelected: (v) {
      if (v == 'rename') _renamePlaylist(name);
      if (v == 'delete') _deletePlaylist(name);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'rename',
        child: Text('Rename',
            style: TextStyle(color: Colors.white)),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text('Delete',
            style: TextStyle(color: Colors.redAccent)),
      ),
    ],
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
       try {
             await PhotoManager.editor.android.removeAllNoExistsAsset();
          } catch (_) {}
            setState(() {
              _audioLoaded = false;
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
  leading: const Icon(Icons.playlist_play,
      color: Colors.white),
  title: const Text("Play next",
      style: TextStyle(color: Colors.white)),
  onTap: () {
    Navigator.pop(context);
    _playNextSong(song);
  },
),
ListTile(
  leading: const Icon(Icons.share, color: Colors.white),
  title: const Text("Share",
      style: TextStyle(color: Colors.white)),
  onTap: () {
    Navigator.pop(context);
    _shareSong(song);
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

  // 👇 वीडियो जैसा तरीका: पहले सिस्टम से delete
  bool removed = false;
  try {
    final result =
        await PhotoManager.editor.deleteWithIds([song.id.toString()]);
    removed = result.isNotEmpty;
  } catch (e) {
    debugPrint("Song delete (system) error: $e");
  }

  // सिस्टम से नहीं हुआ तो फाइल से कोशिश; फाइल पहले ही हटी हो तो भी लिस्ट साफ़ करो
  if (!removed) {
    try {
      final file = File(song.data);
      if (await file.exists()) {
        await file.delete();
      }
      removed = true;
    } on PathNotFoundException {
      removed = true;
    } catch (e) {
      debugPrint("Song delete (file) error: $e");
    }
  }

  if (!removed) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("गाना डिलीट नहीं हो पाया (v2)")),
      );
    }
    return;
  }

  try {
    await PhotoManager.editor.android.removeAllNoExistsAsset();
  } catch (_) {}

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
    musicDataNotifier.value++;
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
