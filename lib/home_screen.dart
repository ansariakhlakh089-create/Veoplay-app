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
  int _currentTab = 0;
  List<SongModel> _songs = [];
  bool _audioLoaded = false;
  bool _audioPermissionDenied = false;
  bool _audioLoading = false;

  String? _recentTitle;
  String? _recentUrl;
  int _recentPosition = 0;
  int _recentDuration = 0;
  int _musicSubTab = 0;
  Set<int> _favoriteIds = {};
  List<int> _recentSongIds = [];
  Map<String, List<int>> _playlists = {};
  StreamSubscription<dynamic>? _seqSub;
  Set<String> _favoriteVideoIds = {};
  Map<String, List<String>> _videoPlaylists = {};
  int _videoTab = 0;
  // 👇👇👇 ये नई लाइन्स ऐड करो 👇👇👇
  bool _isVideoSelectionMode = false;
  Set<String> _selectedVideoIds = {};

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
    _loadFavoriteVideos();
    _loadVideoPlaylists();
    _loadWatchProgress(); // 👈 यहाँ नई लाइन ऐड करो
    _loadHiddenFolders(); // 👈 यहाँ नई लाइन ऐड करो
  }

  void _onRecentChanged() {
    if (mounted) _loadRecent();
  }

  void _onMusicDataChanged() async {
    await _loadMusicData();
    if (mounted) setState(() {});
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

    Future<void> _addToHistory(
      String url, String title, int position, int duration) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_history') ?? [];
    list.removeWhere((s) => s.startsWith('$url|||'));
    list.insert(0, '$url|||$title|||$position|||$duration');
    if (list.length > 100) list.removeRange(100, list.length);
    await prefs.setStringList('watch_history', list);
    }

   // ==================== WATCH PROGRESS FUNCTIONS ====================

  Map<String, double> _watchProgress = {};
Set<String> _watchedVideos = {};

// 👇👇👇 ये नई लाइन्स ऐड करो 👇👇👇
Set<String> _hiddenFolders = {};
bool _showHiddenFolders = false;
Future<void> _loadWatchProgress() async {
  final prefs = await SharedPreferences.getInstance();
  final progressList = prefs.getStringList('watch_progress') ?? [];
  final watchedList = prefs.getStringList('watched_videos') ?? [];
  
  final progressMap = <String, double>{};
  for (final s in progressList) {
    final i = s.indexOf('|||');
    if (i > 0) {
      final url = s.substring(0, i);
      final val = double.tryParse(s.substring(i + 3)) ?? 0.0;
      progressMap[url] = val;
    }
  }
  
  if (mounted) {
    setState(() {
      _watchProgress = progressMap;
      _watchedVideos = watchedList.toSet();
    });
  }
}

Future<void> _loadHiddenFolders() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('hidden_folders') ?? [];
  if (mounted) {
    setState(() {
      _hiddenFolders = list.toSet();
    });
  }
}

Future<void> _saveHiddenFolders() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('hidden_folders', _hiddenFolders.toList());
}
  
Future<void> _saveWatchProgress(String url, double progress) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Progress update करो (सिर्फ तभी जब पहले से ज्यादा हो)
  if (progress > (_watchProgress[url] ?? 0)) {
    _watchProgress[url] = progress;
  }
  
  // अगर 95% से ज्यादा देख लिया तो "Watched" मार्क करो
  if (progress >= 0.95) {
    _watchedVideos.add(url);
    _watchProgress[url] = 1.0;
  }
  
  // सेव करो
  await prefs.setStringList(
    'watch_progress',
    _watchProgress.entries
        .map((e) => '${e.key}|||${e.value}')
        .toList(),
  );
  await prefs.setStringList(
    'watched_videos',
    _watchedVideos.toList(),
  );
  
  if (mounted) setState(() {});
}

bool _isVideoNew(String url) {
  return !_watchedVideos.contains(url) && (_watchProgress[url] ?? 0) == 0;
}

double _getVideoProgress(String url) {
  return _watchProgress[url] ?? 0.0;
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
     await _addToHistory(url, title, position, duration);
    }
  }

  Future<void> _loadFavoriteVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('favorite_videos') ?? []).toSet();
        if (mounted) {
      setState(() {
        _favoriteVideoIds = ids;
        if (_sortMode == 4) _sortList(videoList);
      });
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
    if (_sortMode == 4 && mounted) {
      setState(() => _sortList(videoList));
        }
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

// ==================== MULTI-SELECT FUNCTIONS ====================

void _toggleVideoSelectionMode() {
  setState(() {
    _isVideoSelectionMode = !_isVideoSelectionMode;
    if (!_isVideoSelectionMode) {
      _selectedVideoIds.clear();
    }
  });
}

void _toggleVideoSelection(String id) {
  if (id.isEmpty) return;
  setState(() {
    if (_selectedVideoIds.contains(id)) {
      _selectedVideoIds.remove(id);
    } else {
      _selectedVideoIds.add(id);
    }
  });
}

void _selectAllVideos() {
  setState(() {
    if (_selectedVideoIds.length == videoList.length) {
      _selectedVideoIds.clear();
    } else {
      _selectedVideoIds = videoList
          .map((v) => v['id'] ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    }
  });
}

Future<void> _deleteSelectedVideos() async {
  if (_selectedVideoIds.isEmpty) return;

  final count = _selectedVideoIds.length;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text("$count वीडियो डिलीट करें?",
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text("ये वीडियो डिवाइस से हमेशा के लिए हट जाएंगे।",
          style: TextStyle(color: AppTheme.textSecondary)),
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

  final idsToDelete = _selectedVideoIds.toList();
  for (final id in idsToDelete) {
    try {
      await PhotoManager.editor.deleteWithIds([id]);
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  try {
    await PhotoManager.editor.android.removeAllNoExistsAsset();
  } catch (_) {}

  setState(() {
    videoList.removeWhere((v) => _selectedVideoIds.contains(v['id']));
    _isVideoSelectionMode = false;
    _selectedVideoIds.clear();
  });

  final prefs = await SharedPreferences.getInstance();
  final toSave = videoList
      .map((m) =>
          "${m['title']}|||${m['res']}|||${m['size']}|||${m['source']}|||${m['duration']}|||${m['url']}|||${m['folder']}|||${m['id'] ?? ''}")
      .toList();
  await prefs.setStringList('cached_videos', toSave);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $count वीडियो डिलीट हो गए')),
    );
  }
}

void _showAddMultipleToPlaylistDialog() {
  final count = _selectedVideoIds.length;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text("$count videos को Playlist में जोड़ें",
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(Icons.add, color: AppTheme.primaryBlue),
              title: Text("नई Playlist बनाएँ",
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                final name = await _askVideoPlaylistName();
                if (name == null) return;
                if (!_videoPlaylists.containsKey(name)) {
                  setState(() => _videoPlaylists[name] = []);
                }
                for (final id in _selectedVideoIds) {
                  await _addVideoToPlaylist(name, id);
                }
                setState(() {
                  _isVideoSelectionMode = false;
                  _selectedVideoIds.clear();
                });
                _toast("'$name' में $count videos जोड़ दिए");
              },
            ),
            ..._videoPlaylists.keys.map((name) => ListTile(
                  leading: Icon(Icons.queue_music,
                      color: AppTheme.iconColor),
                  title: Text(name,
                      style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text(
                    "${_videoPlaylists[name]!.length} videos",
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    for (final id in _selectedVideoIds) {
                      await _addVideoToPlaylist(name, id);
                    }
                    setState(() {
                      _isVideoSelectionMode = false;
                      _selectedVideoIds.clear();
                    });
                    _toast("'$name' में $count videos जोड़ दिए");
                  },
                )),
          ],
        ),
      );
    },
  );
}

  Future<void> _loadVideoPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('video_playlists') ?? [];
    final map = <String, List<String>>{};
    for (final s in list) {
      final i = s.indexOf('|||');
      if (i <= 0) continue;
      map[s.substring(0, i)] = s
          .substring(i + 3)
          .split(',')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (mounted) setState(() => _videoPlaylists = map);
  }

  Future<void> _saveVideoPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'video_playlists',
      _videoPlaylists.entries
          .map((e) => '${e.key}|||${e.value.join(",")}')
          .toList(),
    );
  }

  Future<String?> _askVideoPlaylistName({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(initial == null ? "नई Playlist" : "नाम बदलें",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
              hintText: "Playlist का नाम",
              hintStyle: TextStyle(color: AppTheme.textSecondary)),
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
    if (name == null || name.isEmpty) return null;
    final clean = name.replaceAll('|', '').replaceAll(',', '').trim();
    return clean.isEmpty ? null : clean;
  }

  Future<void> _createVideoPlaylist() async {
    final name = await _askVideoPlaylistName();
    if (name == null) return;
    if (_videoPlaylists.containsKey(name)) {
      _toast("इस नाम की Playlist पहले से है");
      return;
    }
    setState(() => _videoPlaylists[name] = []);
    await _saveVideoPlaylists();
    _toast("Playlist बन गई");
  }

  Future<void> _deleteVideoPlaylist(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text("'$name' हटाएँ?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("Playlist हटेगी, वीडियो फोन में रहेंगे।",
            style: TextStyle(color: AppTheme.textSecondary)),
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
    setState(() => _videoPlaylists.remove(name));
    await _saveVideoPlaylists();
    _toast("Playlist हटा दी");
  }

  Future<void> _renameVideoPlaylist(String oldName) async {
    final newName = await _askVideoPlaylistName(initial: oldName);
    if (newName == null || newName == oldName) return;
    if (_videoPlaylists.containsKey(newName)) {
      _toast("इस नाम की Playlist पहले से है");
      return;
    }
    setState(() {
      final list = _videoPlaylists.remove(oldName) ?? [];
      _videoPlaylists[newName] = list;
    });
    await _saveVideoPlaylists();
    _toast("नाम बदल दिया");
  }

  Future<void> _addVideoToPlaylist(String name, String videoId) async {
    final list = _videoPlaylists[name] ?? [];
    if (!list.contains(videoId)) list.add(videoId);
    setState(() => _videoPlaylists[name] = list);
    await _saveVideoPlaylists();
    _toast("'$name' में जोड़ दिया");
  }

  Future<void> _removeVideoFromPlaylist(
      String name, String videoId) async {
    final list = _videoPlaylists[name] ?? [];
    list.remove(videoId);
    setState(() => _videoPlaylists[name] = list);
    await _saveVideoPlaylists();
    _toast("'$name' से हटा दिया");
  }

  void _showAddVideoToPlaylistDialog(Map<String, String> video) {
    final videoId = video['id'];
    if (videoId == null || videoId.isEmpty) {
      _toast("इस वीडियो को add नहीं कर सकते");
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Add to Playlist",
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: AppTheme.primaryBlue),
                title: Text("नई Playlist बनाएँ",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = await _askVideoPlaylistName();
                  if (name == null) return;
                  if (!_videoPlaylists.containsKey(name)) {
                    setState(() => _videoPlaylists[name] = []);
                  }
                  await _addVideoToPlaylist(name, videoId);
                },
              ),
              ..._videoPlaylists.keys.map((name) => ListTile(
                    leading: Icon(Icons.queue_music,
                        color: AppTheme.iconColor),
                    title: Text(name,
                        style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(
                      "${_videoPlaylists[name]!.length} videos",
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _addVideoToPlaylist(name, videoId);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadSongs() async {
    if (_audioLoaded) {
      _quickSyncSongs();
      return;
    }
    if (mounted) setState(() => _audioLoading = true);
    final OnAudioQuery audioQuery = OnAudioQuery();
    bool hasPermission = await audioQuery.checkAndRequest(retryRequest: true);
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _audioPermissionDenied = true;
          _audioLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _audioPermissionDenied = false;
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
    await prefs.setStringList(
      'cached_songs', sorted.map((s) => s.id.toString()).toList());
    if (!mounted) return;
    setState(() {
      _songs = sorted;
      _audioLoaded = true;
      _audioLoading = false;
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
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
          'cached_songs', sorted.map((s) => s.id.toString()).toList());
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
  leading: _isVideoSelectionMode
      ? IconButton(
          icon: Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: _toggleVideoSelectionMode,
        )
      : null,
  title: _isVideoSelectionMode
      ? Text(
          "${_selectedVideoIds.length} चुने गए",
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary))
      : Row(
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.primaryPurple
                        ],
                      ),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white),
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
  actions: _isVideoSelectionMode
      ? [
          IconButton(
            icon: Icon(
              _selectedVideoIds.length == videoList.length
                  ? Icons.deselect
                  : Icons.select_all,
              color: AppTheme.textPrimary,
            ),
            tooltip: "Select All",
            onPressed: _selectAllVideos,
          ),
        ]
      : [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VideoSearchScreen(videos: videoList),
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
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppTheme.primaryBlue.withOpacity(0.2),
                child: Icon(Icons.person,
                    color: AppTheme.primaryBlue, size: 20),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.checklist,
                color: AppTheme.textPrimary),
            tooltip: "Select Videos",
            onPressed: _toggleVideoSelectionMode,
          ),
        ],
      ),
      body: Column(
  children: [
    Expanded(
      child: _currentTab == 2
          ? _buildMusicTab()
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryBlue),
                      SizedBox(height: 20),
                      Text("Discovering videos...",
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
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
                            Icon(Icons.folder_off,
                                color: AppTheme.textSecondary, size: 60),
                            const SizedBox(height: 16),
                            Text("Video access permission चाहिए",
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  PhotoManager.openSetting(),
                              child: const Text("Settings खोलें"),
                            ),
                          ],
                        ),
                      ),
                    )
                  : videoList.isEmpty
                      ? Center(
                          child: Text("कोई वीडियो नहीं मिला",
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16)),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            try {
                              await PhotoManager.editor.android
                                  .removeAllNoExistsAsset();
                            } catch (_) {}
                            await _scanVideos(silent: true);
                            await _loadRecent();
                          },
                          child: SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                16, 12, 16, 18),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius:
                                        BorderRadius.circular(18),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_recentTitle != null) ...[
                                   Row(
                                    children: [
                                      Text("Recent",
                                          style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary)),
                                      const Spacer(),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  VideoHistoryScreen(
                                                      allVideos: videoList),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          children: [
                                            Icon(Icons.history,
                                                color: AppTheme.iconColor,
                                                size: 22),
                                            const SizedBox(width: 2),
                                            Icon(Icons.chevron_right,
                                                color: AppTheme.iconColor,
                                                size: 22),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RealVideoPlayer(
                                            videoUrl: _recentUrl!,
                                            title: _recentTitle!,
                                            startPosition:
                                                _recentPosition,
                                          ),
                                        ),
                                      );
                                      if (result != null && result is Map) {
                                        setState(() {
                                          _recentTitle = result['title'];
                                          _recentUrl = result['url'];
                                          _recentPosition =
                                              result['position'];
                                          _recentDuration =
                                              result['duration'];
                                        });
                                      } else {
                                        await Future.delayed(const Duration(
                                            milliseconds: 300));
                                        if (mounted) _loadRecent();
                                      }
                                    },
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(24),
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
                                                  begin:
                                                      Alignment.topCenter,
                                                  end: Alignment
                                                      .bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black
                                                        .withOpacity(0.6),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Center(
                                              child: Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.white,
                                                  size: 70),
                                            ),
                                            Positioned(
                                              left: 18,
                                              bottom: 18,
                                              right: 18,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  const Text(
                                                      "ContinueWatching",
                                                      style: TextStyle(
                                                          color: Colors
                                                              .white70)),
                                                  const SizedBox(
                                                      height: 5),
                                                  Text(_recentTitle!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                          color: Colors
                                                              .white)),
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
                                      onTap: () => setState(
                                          () => _videoTab = 0),
                                      child: Text("Videos",
                                          style: TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                              color: _videoTab == 0
                                                  ? AppTheme.textPrimary
                                                  : AppTheme
                                                      .textTertiary)),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _videoTab = 1),
                                      child: Text("Folders",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _videoTab == 1
                                                  ? AppTheme.textPrimary
                                                  : AppTheme
                                                      .textTertiary)),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _videoTab = 2),
                                      child: Text("My List",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _videoTab == 2
                                                  ? AppTheme.textPrimary
                                                  : AppTheme
                                                      .textTertiary)),
                                    ),
                                    const Spacer(),
                                    if (_videoTab == 2)
                                      IconButton(
                                        onPressed: _createVideoPlaylist,
                                        icon: Icon(Icons.add,
                                            color: AppTheme.iconColor),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                      ),
                                    if (_videoTab != 2)
                                      IconButton(
                                        onPressed: _showSortMenu,
                                        icon: Icon(Icons.sort,
                                            color: AppTheme.iconColor),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_videoTab == 0)
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: videoList.length,
                                    itemBuilder: (context, index) {
                                      final item = videoList[index];
                                      return _buildVideoTile(context, item);
                                    },
                                  )
                                else if (_videoTab == 1)
                                  _buildFoldersList()
                                else
                                  _buildPlaylistsList(),
                              ],
                            ),
                          ),
                        ),
    // 👇👇👇 Selection Mode वाला Bottom Action Bar 👇👇👇
    if (_isVideoSelectionMode && _videoTab == 0)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          border: Border(
              top: BorderSide(color: AppTheme.cardBorder, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedVideoIds.isEmpty
                      ? null
                      : _deleteSelectedVideos,
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  label: Text(
                    "Delete (${_selectedVideoIds.length})",
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedVideoIds.isEmpty
                      ? null
                      : _showAddMultipleToPlaylistDialog,
                  icon: const Icon(Icons.playlist_add,
                      color: Colors.white),
                  label: Text(
                    "Playlist (${_selectedVideoIds.length})",
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
  ],
),
bottomNavigationBar: NavigationBar(
      
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.card,
        indicatorColor:
            AppTheme.primaryBlue.withOpacity(0.2),
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          if (index == 1) {
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
                const SnackBar(
                    content:
                        Text("कोई हाल ही में चलाया गया वीडियो नहीं है")),
              );
            }
            return;
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
              icon: Icon(Icons.play_circle_fill, size: 36),
              label: "Play"),
          NavigationDestination(
              icon: Icon(Icons.music_note), label: "Music"),
        ],
      ),
    );
  }

  Widget _buildFoldersList() {
  final grouped = <String, List<Map<String, String>>>{};
  for (final video in videoList) {
    final folder = video['folder'] ?? 'Unknown';
    if (!_hiddenFolders.contains(folder)) {
      grouped.putIfAbsent(folder, () => []).add(video);
    }
  }
  final folderNames = grouped.keys.toList();
  final hiddenList = _hiddenFolders.toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: folderNames.length,
        itemBuilder: (context, index) {
          final folderName = folderNames[index];
          final folderVideos = grouped[folderName]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderVideosScreen(
                      folderName: folderName,
                      videos: folderVideos,
                    ),
                  ),
                );
              },
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.card,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.visibility_off,
                              color: Colors.redAccent),
                          title: const Text('Hide Folder',
                              style: TextStyle(color: Colors.redAccent)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _hiddenFolders.add(folderName);
                            });
                            _saveHiddenFolders();
                            _toast("'$folderName' हाइड कर दिया");
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder,
                        color: AppTheme.primaryBlue, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(folderName,
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("${folderVideos.length} videos",
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      // 👇 Hidden Folders Section
      if (hiddenList.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showHiddenFolders = !_showHiddenFolders;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    _showHiddenFolders
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _showHiddenFolders
                        ? "Hidden Folders छुपाओ"
                        : "Hidden Folders दिखाओ (${hiddenList.length})",
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (_showHiddenFolders)
        ...hiddenList.map((folderName) {
          final folderVideos = videoList
              .where((v) => v['folder'] == folderName)
              .toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _hiddenFolders.remove(folderName);
                });
                _saveHiddenFolders();
                _toast("'$folderName' दिखने लगा");
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_off,
                        color: AppTheme.textTertiary, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(folderName,
                              style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("${folderVideos.length} videos (Hidden)",
                              style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.visibility, color: AppTheme.primaryBlue),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
    ],
  );
  }

  Widget _buildPlaylistsList() {
    final names = _videoPlaylists.keys.toList();
    if (names.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            "अभी कोई Playlist नहीं है\nऊपर + दबाकर बनाओ",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 15),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final ids = _videoPlaylists[name] ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlaylistScreen(
                    playlistName: name,
                    videoIds: ids,
                    allVideos: videoList,
                    onRemove: (vid) =>
                        _removeVideoFromPlaylist(name, vid),
                    onDelete: () => _deleteVideoPlaylist(name),
                    onRename: () => _renameVideoPlaylist(name),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.cardBorder, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue_music,
                      color: AppTheme.primaryBlue, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("${ids.length} videos",
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.card,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(Icons.edit,
                                    color: AppTheme.iconColor),
                                title: Text('Rename',
                                    style: TextStyle(
                                        color:
                                            AppTheme.textPrimary)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _renameVideoPlaylist(name);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                title: const Text('Delete',
                                    style: TextStyle(
                                        color: Colors.redAccent)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _deleteVideoPlaylist(name);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.more_vert,
                        color: AppTheme.iconColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoTile(
    BuildContext context, Map<String, String> item) {
  final index = videoList.indexOf(item);
  final isSelected = _selectedVideoIds.contains(item['id']);

  return Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: GestureDetector(
      onTap: () async {
        // 👇 Selection Mode में टैप करने पर Select/Deselect हो
        if (_isVideoSelectionMode) {
          _toggleVideoSelection(item['id'] ?? '');
          return;
        }
        // Normal Mode में टैप करने पर वीडियो चले
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
          if (result != null && result is Map) {
  setState(() {
    _recentTitle = result['title'];
    _recentUrl = result['url'];
    _recentPosition = result['position'];
    _recentDuration = result['duration'];
  });

  // 👇👇👇 Watch Progress सेव करो 👇👇👇
  final url = result['url'] as String?;
  final pos = result['position'] as int? ?? 0;
  final dur = result['duration'] as int? ?? 0;
  if (url != null && dur > 0) {
    final progress = pos / dur;
    await _saveWatchProgress(url, progress);
  }
  // 👆👆👆 यहाँ तक 👆👆👆

} else {
  await Future.delayed(const Duration(milliseconds: 300));
  if (mounted) _loadRecent();
          }
        } 
      // 👇 Long Press करने पर Selection Mode ON हो
      onLongPress: () {
        if (!_isVideoSelectionMode) {
          _toggleVideoSelectionMode();
          _toggleVideoSelection(item['id'] ?? '');
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👇 Selection Mode में Checkbox दिखाओ
          if (_isVideoSelectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 25),
              child: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppTheme.primaryBlue
                    : AppTheme.textTertiary,
                size: 24,
              ),
            ),
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
              // 👇👇👇 Progress Bar (देखा हुआ) 👇👇👇
if (_getVideoProgress(item['url']!) > 0 &&
    !_watchedVideos.contains(item['url']))
  Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: LinearProgressIndicator(
        value: _getVideoProgress(item['url']!),
        minHeight: 4,
        backgroundColor: Colors.black45,
        valueColor: AlwaysStoppedAnimation<Color>(
          _getVideoProgress(item['url']!) > 0.5
              ? Colors.greenAccent
              : Colors.amber,
        ),
      ),
    ),
  ),

// 👇👇👇 NEW Badge (नया वीडियो) 👇👇👇
if (_isVideoNew(item['url']!))
  Positioned(
    top: 4,
    left: 4,
    child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
// 👆👆👆 यहाँ तक 👆👆👆
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? 'No Title',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${item['res'] ?? ''} | ${item['size'] ?? ''}",
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 0),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['source'] ?? '',
                        style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 👇 Selection Mode में Favorite और Menu छुपाओ
                    if (!_isVideoSelectionMode) ...[
                      IconButton(
                        onPressed: () => _toggleVideoFavorite(item),
                        icon: Icon(
                          _favoriteVideoIds.contains(item['id'])
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _favoriteVideoIds.contains(item['id'])
                              ? Colors.pinkAccent
                              : AppTheme.iconColor,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () =>
                            _showVideoOptions(context, item, index),
                        icon: Icon(Icons.more_vert,
                            color: AppTheme.iconColor, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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
    
  void _showVideoOptions(BuildContext context,
      Map<String, String> item, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.playlist_add,
                    color: AppTheme.iconColor),
                title: Text("Add to Playlist",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddVideoToPlaylistDialog(item);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: AppTheme.iconColor),
                title: Text("Details",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showVideoDetails(item);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppTheme.iconColor),
                title: Text("Rename",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _renameVideo(item, index);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text("Delete",
                    style: TextStyle(color: Colors.redAccent)),
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
              case 4:
        list.sort((a, b) {
          final fa = _favoriteVideoIds.contains(a['id']) ? 0 : 1;
          final fb = _favoriteVideoIds.contains(b['id']) ? 0 : 1;
          if (fa != fb) return fa.compareTo(fb);
          return idOf(b).compareTo(idOf(a));
        });
        break;
      default:
        list.sort((a, b) => idOf(b).compareTo(idOf(a)));
    }
  }

  void _showSortMenu() {
    final options = [
      'नया पहले',
      'पुराना पहले',
      'साइज़ (बड़ा पहले)',
      'Favorite पहले ❤️'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
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
                  color: _sortMode == i
                      ? AppTheme.primaryBlue
                      : AppTheme.iconColor,
                ),
                title: Text(options[i],
                    style: TextStyle(color: AppTheme.textPrimary)),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
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
        text:
            '${globalSongNames[song.id] ?? song.title}\n${song.artist ?? ''}',
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
      _playlists.entries
          .map((e) => '${e.key}|||${e.value.join(",")}')
          .toList(),
    );
  }

  Future<String?> _askPlaylistName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text("नई Playlist",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
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
      backgroundColor: AppTheme.card,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add, color: AppTheme.primaryBlue),
                title: Text("नई Playlist बनाएँ",
                    style: TextStyle(color: AppTheme.textPrimary)),
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
                    leading: Icon(Icons.queue_music,
                        color: AppTheme.iconColor),
                    title: Text(name,
                        style: TextStyle(
                            color: AppTheme.textPrimary)),
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
        backgroundColor: AppTheme.card,
        title: Text("'$name' हटाएँ?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("सिर्फ़ Playlist हटेगी, गाने फोन में रहेंगे।",
            style: TextStyle(color: AppTheme.textSecondary)),
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

  Future<void> _renamePlaylist(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text("Playlist का नाम बदलें",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
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
                    (title != "Favorite" ||
                        _favoriteIds.contains(s.id)),
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
    final isPlaying =
        nowTag is MediaItem && nowTag.id == song.id.toString();
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
                      child: const Icon(Icons.graphic_eq,
                          color: AppTheme.primaryBlue, size: 24),
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
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(song.artist ?? "Unknown",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
            if (_favoriteIds.contains(song.id))
              const Icon(Icons.favorite,
                  color: Colors.pinkAccent, size: 16),
            IconButton(
              onPressed: () => _showSongOptions(song),
              icon: Icon(Icons.more_vert,
                  color: AppTheme.iconColor, size: 20),
              padding: const EdgeInsets.only(left: 8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTile(IconData icon, String name, int count,
      VoidCallback onTap,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.cardBorder, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryBlue, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("$count songs",
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(Icons.chevron_right,
                    color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _musicBox(String title, IconData icon, Color color,
      int count, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.cardBorder, width: 1),
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
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text("$count songs",
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNowPlaying() {
    final seq = globalAudioPlayer.sequenceState?.sequence ??
        <IndexedAudioSource>[];
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
        builder: (_) =>
            AudioPlayerScreen(songs: list, initialIndex: idx),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primaryBlue
                          .withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Builder(builder: (_) {
                      final id = int.tryParse(tag.id);
                      if (id == null) {
                        return Icon(Icons.graphic_eq, color: AppTheme.primaryBlue);
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
                            final displayTitle =
                                (id != null &&
                                        globalSongNames
                                            .containsKey(id))
                                    ? globalSongNames[id]!
                                    : tag.title;
                            return Text(displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold));
                          }),
                          Text(tag.artist ?? "Unknown",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          globalAudioPlayer.seekToPrevious(),
                      icon: Icon(Icons.skip_previous,
                          color: AppTheme.textPrimary, size: 28),
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
                              playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: AppTheme.textPrimary,
                              size: 30),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => globalAudioPlayer.seekToNext(),
                      icon: Icon(Icons.skip_next,
                          color: AppTheme.textPrimary, size: 28),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMusicTab() {
    if (_audioLoading && _songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            SizedBox(height: 16),
            Text("गाने लोड हो रहे हैं...",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
              Icon(Icons.music_off,
                  color: AppTheme.textSecondary, size: 60),
              const SizedBox(height: 16),
              Text("Music access permission चाहिए",
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16),
                  textAlign: TextAlign.center),
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
      return Center(
        child: Text("कोई गाना नहीं मिला",
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
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
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: sel
                                        ? AppTheme.primaryBlue
                                        : AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                                height: 3,
                                width: 28,
                                color: sel
                                    ? AppTheme.primaryBlue
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
              icon: Icon(Icons.search, color: AppTheme.iconColor),
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
                child: _musicBox(
                    "Recently Played",
                    Icons.history,
                    Colors.orangeAccent,
                    recent.length,
                    () => _openSongList("Recently Played", recent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _musicBox(
                    "Favorite",
                    Icons.favorite,
                    Colors.pinkAccent,
                    favs.length,
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
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: _createPlaylist,
                  icon: Icon(Icons.add, color: AppTheme.iconColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: names.isEmpty
                ? Center(
                    child: Text(
                        "अभी कोई Playlist नहीं है, ऊपर + दबाकर बनाओ",
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15),
                        textAlign: TextAlign.center))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    itemCount: names.length,
                    itemBuilder: (context, index) {
                      final name = names[index];
                      final list =
                          _songsByIds(_playlists[name] ?? []);
                      return _groupTile(
                        Icons.queue_music,
                        name,
                        list.length,
                        () => _openSongList(name, list,
                            playlistName: name),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: AppTheme.iconColor, size: 20),
                          color: AppTheme.card,
                          onSelected: (v) {
                            if (v == 'rename')
                              _renamePlaylist(name);
                            if (v == 'delete')
                              _deletePlaylist(name);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary)),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(
                                      color: Colors.redAccent)),
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: _showSongSortMenu,
                icon: Icon(Icons.sort, color: AppTheme.iconColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primaryBlue, backgroundColor: AppTheme.card,
            onRefresh: () async {
              try {
                await PhotoManager.editor.android
                    .removeAllNoExistsAsset();
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
        list.sort((a, b) =>
            (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
        break;
      case 2:
        list.sort((a, b) => (globalSongNames[a.id] ?? a.title)
            .toLowerCase()
            .compareTo(
                (globalSongNames[b.id] ?? b.title).toLowerCase()));
        break;
      default:
        list.sort((a, b) =>
            (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    }
  }

  void _showSongSortMenu() {
    final options = [
      'नया गाना पहले',
      'पुराना गाना पहले',
      'नाम (A से Z)'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
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
                  color: _songSortMode == i
                      ? AppTheme.primaryBlue
                      : AppTheme.iconColor,
                ),
                title: Text(options[i],
                    style: TextStyle(color: AppTheme.textPrimary)),
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
      globalSongNames.entries
          .map((e) => '${e.key}|||${e.value}')
          .toList(),
    );
  }

  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: AppTheme.iconColor),
                title: Text("Details",
                    style: TextStyle(color: AppTheme.textPrimary)),
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
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_add,
                    color: AppTheme.iconColor),
                title: Text("Playlist में जोड़ें",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _addToPlaylistDialog(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppTheme.iconColor),
                title: Text("Rename",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _renameSong(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_play,
                    color: AppTheme.iconColor),
                title: Text("Play next",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _playNextSong(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: AppTheme.iconColor),
                title: Text("Share",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _shareSong(song);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete, color: Colors.redAccent),
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
        backgroundColor: AppTheme.card,
        title: Text(globalSongNames[song.id] ?? song.title,
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Artist: ${song.artist ?? 'Unknown'}",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Duration: $dur",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Size: ${_formatSize(song.size)}",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Path: ${song.data}",
                style: TextStyle(color: AppTheme.textSecondary),
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
        backgroundColor: AppTheme.card,
        title: Text("Rename Song",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary),
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
      musicDataNotifier.value++;
    });
  }

  Future<void> _deleteSong(SongModel song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text("गाना डिलीट करें?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("ये गाना डिवाइस से हमेशा के लिए हट जाएगा।",
            style: TextStyle(color: AppTheme.textSecondary)),
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

    bool removed = false;
    try {
      final result =
          await PhotoManager.editor.deleteWithIds([song.id.toString()]);
      removed = result.isNotEmpty;
    } catch (e) {
      debugPrint("Song delete (system) error: $e");
    }

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
          const SnackBar(
              content: Text("गाना डिलीट नहीं हो पाया (v2)")),
        );
      }
      return;
    }

    try {
      await PhotoManager.editor.android.removeAllNoExistsAsset();
    } catch (_) {}

    globalSongNames.remove(song.id);
    await _saveSongNames();

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
        backgroundColor: AppTheme.card,
        title: Text(item['title'] ?? 'Details',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Resolution: ${item['res']}",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Duration: ${item['duration']}",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Size: ${item['size']}",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Folder: ${item['folder']}",
                style: TextStyle(color: AppTheme.textSecondary)),
            Text("Path: ${item['url']}",
                style: TextStyle(color: AppTheme.textSecondary),
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

  Future<void> _renameVideo(Map<String, String> item, int index) async {
    final controller = TextEditingController(text: item['title']);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text("Rename Video",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary),
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
        backgroundColor: AppTheme.card,
        title: Text("वीडियो डिलीट करें?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("ये वीडियो डिवाइस से हमेशा के लिए हट जाएगी।",
            style: TextStyle(color: AppTheme.textSecondary)),
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
        final delId = item['id'] ?? '';
    if (delId.isNotEmpty) {
      _favoriteVideoIds.remove(delId);
      for (final k in _videoPlaylists.keys.toList()) {
        _videoPlaylists[k]?.remove(delId);
      }
      final prefsC = await SharedPreferences.getInstance();
      await prefsC.setStringList(
          'favorite_videos', _favoriteVideoIds.toList());
      await prefsC.remove('resume_${item['url']}');
      await _saveVideoPlaylists();
      if (mounted) setState(() {});
    }
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

  // ==================== Video Watch History Screen ====================
class VideoHistoryScreen extends StatefulWidget {
  final List<Map<String, String>> allVideos;
  const VideoHistoryScreen({super.key, required this.allVideos});

  @override
  State<VideoHistoryScreen> createState() => _VideoHistoryScreenState();
}

class _VideoHistoryScreenState extends State<VideoHistoryScreen> {
  List<List<String>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('watch_history') ?? [];
    final urls = widget.allVideos.map((v) => v['url']).toSet();
    final out = <List<String>>[];
    for (final s in raw) {
      final p = s.split('|||');
      if (p.length < 4) continue;
      if (!urls.contains(p[0])) continue;
      out.add(p);
    }
    if (mounted) {
      setState(() {
        _items = out;
        _loading = false;
      });
    }
  }

  Future<void> _removeOne(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('watch_history') ?? [];
    raw.removeWhere((s) => s.startsWith('$url|||'));
    await prefs.setStringList('watch_history', raw);
    await _loadHistory();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('सारी History हटाएँ?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('सारी watch history हट जाएगी',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_history');
    if (mounted) {
      setState(() {
        _items = [];
      });
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Watch History',
            style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: AppTheme.textPrimary),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          color: AppTheme.textTertiary, size: 60),
                      const SizedBox(height: 12),
                      Text('कोई watch history नहीं है',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final url = item[0];
                    final title = item.length > 1 ? item[1] : 'Unknown';
                    final pos =
                        item.length > 2 ? int.tryParse(item[2]) ?? 0 : 0;
                    final dur =
                        item.length > 3 ? int.tryParse(item[3]) ?? 0 : 0;
                    final progress = dur > 0 ? pos / dur : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.cardBorder, width: 1),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: VideoThumbnailWidget(videoPath: url),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                if (dur > 0) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: AppTheme.cardBorder,
                                      valueColor: AlwaysStoppedAnimation(
                                          AppTheme.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDuration(Duration(seconds: pos))} / ${_formatDuration(Duration(seconds: dur))}',
                                    style: TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.redAccent, size: 20),
                            onPressed: () => _removeOne(url),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
