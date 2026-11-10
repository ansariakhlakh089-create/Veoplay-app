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
  bool _isSongSelectionMode = false;
  Set<int> _selectedSongIds = {};

  // Ye list sirf wo videos dikhayegi jo hidden nahi hain
List<Map<String, String>> get _visibleVideos {
  return videoList.where((v) {
    final id = v['id'] ?? '';
    final folderKey = _folderKey(v);
    final folderName = v['folder'] ?? 'Unknown';
    return !_hiddenVideoIds.contains(id) && 
           !_hiddenFolders.contains(folderKey) && 
           !_hiddenFolders.contains(folderName);
  }).toList();
}

// Ye list sirf wo gaane dikhayegi jo hidden nahi hain
List<SongModel> get _visibleSongs {
  return _songs.where((s) => !_hiddenSongIds.contains(s.id)).toList();
}
  
  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  recentChangedNotifier.addListener(_onRecentChanged);
  musicDataNotifier.addListener(_onMusicDataChanged);
  rescanRequestNotifier.addListener(_onRescanRequested);
  isDarkMode.addListener(_onThemeChanged);
  
  _seqSub = globalAudioPlayer.sequenceStateStream.listen((s) {
    final tag = s?.currentSource?.tag;
    if (tag is MediaItem) {
      final id = int.tryParse(tag.id);
      if (id != null) _addRecentSong(id);
    }
    if (mounted) setState(() {});
  });

  // 👇 YAHAN SE NAYA CODE SHURU HAI 👇
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 1. Sabse pehle Notification Permission maango
    await askNotificationPermission(); 
    
    // 2. Phir videos aur history load karo
    _loadVideos();
    _loadRecent();
    _loadFavoriteVideos();
    _loadVideoPlaylists();
    _loadWatchProgress();
    _loadHiddenFolders();
  });
  // 👆 YAHAN TAK NAYA CODE KHATAM 👆
}

// 👇 Yahan se function shuru karo
Future<void> askNotificationPermission() async {
  // Android 13+ ke liye notification permission maango
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }
}
  
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onRescanRequested() {
    _loadHiddenFolders();
    _scanVideos(silent: true);
    _quickSyncSongs();
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
    rescanRequestNotifier.removeListener(_onRescanRequested);
    isDarkMode.removeListener(_onThemeChanged);
    _seqSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecent();
      // पहला scan / permission dialog चल रहा हो तो दोबारा मत छेड़ो
      if (!_isLoading) _quickSyncVideos();
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
Set<String> _hiddenVideoIds = {}; // Sirf videos ke liye
Set<int> _hiddenSongIds = {};     // Sirf songs ke liye
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
  if (mounted) {
    setState(() {
      _hiddenFolders = (prefs.getStringList('hidden_folders') ?? []).toSet();
      _hiddenVideoIds = (prefs.getStringList('hidden_videos') ?? []).toSet();
      _hiddenSongIds = (prefs.getStringList('hidden_songs') ?? []).map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
    });
  }
}
  
Future<void> _saveHiddenData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('hidden_folders', _hiddenFolders.toList());
  await prefs.setStringList('hidden_videos', _hiddenVideoIds.toList());
  await prefs.setStringList('hidden_songs', _hiddenSongIds.map((e) => e.toString()).toList());
}

// Video Hide karne ke liye
Future<void> _hideVideo(Map<String, String> item) async {
  final id = item['id'] ?? '';
  if (id.isNotEmpty) {
    setState(() => _hiddenVideoIds.add(id));
    await _saveHiddenData();
    _toast('Video hidden');
  }
}

// Folder Hide karne ke liye
Future<void> _hideFolder(String folderKey) async {
  setState(() => _hiddenFolders.add(folderKey));
  await _saveHiddenData();
  _toast('Folder hidden');
}

// Song Hide karne ke liye
Future<void> _hideSong(SongModel song) async {
  setState(() => _hiddenSongIds.add(song.id));
  await _saveHiddenData();
  _toast('Song hidden');
}
  
Future<bool> _verifyOrCreateFolderPin() async {
  final prefs = await SharedPreferences.getInstance();
  final savedPin = prefs.getString('hidden_folder_pin');
  final ctrl = TextEditingController();

  final entered = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        savedPin == null ? 'Create 5-digit PIN' : 'Enter PIN',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        maxLength: 5,
        keyboardType: TextInputType.number,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, letterSpacing: 6),
        decoration: InputDecoration(
          hintText: '••••',
          hintStyle: TextStyle(color: AppTheme.textTertiary),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(savedPin == null ? 'Set PIN' : 'Unlock'),
        ),
      ],
    ),
  );

  if (entered == null || entered.length < 5) return false;
  if (savedPin == null) {
    await prefs.setString('hidden_folder_pin', entered);
    _toast('🔒 PIN set successfully');
    return true;
  }
  if (entered == savedPin) return true;
  _toast('❌ Wrong PIN!');
  return false;
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
              ? '❤️ Added to Favorites'
              : 'Removed from Favorites'),
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
    // 👈 Auto-exit (if empty) wali line yahan se hata di gayi hai
  });
}

void _selectAllVideos() {
  setState(() {
    if (_selectedVideoIds.length == _visibleVideos.length) {
      _selectedVideoIds.clear();
    } else {
      _selectedVideoIds = _visibleVideos // 👈 _visibleVideos use karo
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
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text("Delete $count videos?",
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text("These videos will be permanently deleted from your device.",
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
  final deletedIds = <String>{};
  for (final id in idsToDelete) {
    try {
      final r = await PhotoManager.editor.deleteWithIds([id]);
      if (r.isNotEmpty) deletedIds.add(id);
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  try {
    await PhotoManager.editor.android.removeAllNoExistsAsset();
  } catch (_) {}

  setState(() {
    videoList.removeWhere((v) => deletedIds.contains(v['id']));
    _isVideoSelectionMode = false;
    _selectedVideoIds.clear();
  });

  final prefs = await SharedPreferences.getInstance();
  _favoriteVideoIds.removeAll(deletedIds);
  for (final k in _videoPlaylists.keys.toList()) {
    _videoPlaylists[k]?.removeWhere(deletedIds.contains);
  }
  await prefs.setStringList('favorite_videos', _favoriteVideoIds.toList());
  await _saveVideoPlaylists();
  await VideoCacheDb.replaceAll(videoList);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(deletedIds.length == idsToDelete.length
              ? '✅ ${deletedIds.length} videos deleted'
              : '${deletedIds.length}/${idsToDelete.length} videos deleted')),
    );
  }
}

// ==================== MUSIC MULTI-SELECT ====================

void _toggleSongSelectionMode() {
  setState(() {
    _isSongSelectionMode = !_isSongSelectionMode;
    if (!_isSongSelectionMode) _selectedSongIds.clear();
  });
}

void _toggleSongSelection(int id) {
  setState(() {
    if (_selectedSongIds.contains(id)) {
      _selectedSongIds.remove(id);
    } else {
      _selectedSongIds.add(id);
    }
    // 👈 Auto-exit (if empty) wali line yahan se hata di gayi hai
  });
}

void _selectAllSongs() {
  setState(() {
    final visible = _visibleSongs;
    if (_selectedSongIds.length == visible.length) {
      _selectedSongIds.clear();
    } else {
      _selectedSongIds = visible.map((song) => song.id).toSet();
    }
  });
}

Future<void> _deleteSelectedSongs() async {
  if (_selectedSongIds.isEmpty) return;

  final idsToDelete = Set<int>.from(_selectedSongIds);
  final count = idsToDelete.length;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text('Delete $count songs?',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text('The selected songs will be deleted from your device. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete',
              style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  final songsToDelete = _songs
      .where((song) => idsToDelete.contains(song.id))
      .toList();
  final deletedIds = <int>{};

  // पहले MediaStore से bulk delete की कोशिश करें।
  try {
    final result = await PhotoManager.editor.deleteWithIds(
      idsToDelete.map((id) => id.toString()).toList(),
    );
    deletedIds.addAll(result.map((id) => int.tryParse(id.toString()))
        .whereType<int>());
  } catch (e) {
    debugPrint('Bulk song delete error: $e');
  }

  // जिनकी MediaStore deletion सफल नहीं हुई, उनके लिए मौजूदा single-delete
  // implementation जैसा file fallback इस्तेमाल करें।
  for (final song in songsToDelete) {
    if (deletedIds.contains(song.id)) continue;
    try {
      final file = File(song.data);
      if (!await file.exists()) {
        deletedIds.add(song.id);
      } else {
        await file.delete();
        deletedIds.add(song.id);
      }
    } on PathNotFoundException {
      deletedIds.add(song.id);
    } catch (e) {
      debugPrint('Song file delete error (${song.id}): $e');
    }
  }

  if (deletedIds.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete songs')),
      );
    }
    return;
  }

  try {
    await PhotoManager.editor.android.removeAllNoExistsAsset();
  } catch (_) {}

  for (final id in deletedIds) {
    globalSongNames.remove(id);
    _favoriteIds.remove(id);
    _recentSongIds.remove(id);
  }
  for (final playlist in _playlists.values) {
    playlist.removeWhere(deletedIds.contains);
  }

  final prefs = await SharedPreferences.getInstance();
  await _saveSongNames();
  await prefs.setStringList(
      'favorite_songs', _favoriteIds.map((id) => id.toString()).toList());
  await prefs.setStringList(
      'recent_songs', _recentSongIds.map((id) => id.toString()).toList());
  await _savePlaylists();

  if (!mounted) return;
  setState(() {
    _songs.removeWhere((song) => deletedIds.contains(song.id));
    _selectedSongIds.clear();
    _isSongSelectionMode = false;
  });
  musicDataNotifier.value++;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(deletedIds.length == count
          ? '${deletedIds.length} songs deleted'
          : '${deletedIds.length}/$count songs deleted'),
    ),
  );
}

void _showAddMultipleToPlaylistDialog() {
  final count = _selectedVideoIds.length;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
              child: Text("Add $count videos to Playlist",
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(Icons.add, color: AppTheme.primaryBlue),
              title: Text("Create new Playlist",
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
                _toast("Added $count videos to '$name'");
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
                    _toast("Added $count videos to '$name'");
                  },
                )),
          ],
        ),
      );
    },
  );
}

  void _showAddMultipleSongsToPlaylistDialog() {
    if (_selectedSongIds.isEmpty) return;
    final count = _selectedSongIds.length;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                child: Text("Add $count songs to Playlist",
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: AppTheme.primaryBlue),
                title: Text("Create new Playlist",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = await _askPlaylistName();
                  if (name == null) return;
                  final list = _playlists[name] ?? <int>[];
                  for (final id in _selectedSongIds) {
                    if (!list.contains(id)) list.add(id);
                  }
                  setState(() {
                    _playlists[name] = list;
                    _isSongSelectionMode = false;
                    _selectedSongIds.clear();
                  });
                  await _savePlaylists();
                  musicDataNotifier.value++;
                  _toast("Added $count songs to '$name'");
                },
              ),
              ..._playlists.keys.map((name) => ListTile(
                    leading: Icon(Icons.queue_music,
                        color: AppTheme.iconColor),
                    title: Text(name,
                        style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(
                      "${_playlists[name]!.length} songs",
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final list = _playlists[name] ?? <int>[];
                      for (final id in _selectedSongIds) {
                        if (!list.contains(id)) list.add(id);
                      }
                      setState(() {
                        _playlists[name] = list;
                        _isSongSelectionMode = false;
                        _selectedSongIds.clear();
                      });
                      await _savePlaylists();
                      musicDataNotifier.value++;
                      _toast("Added $count songs to '$name'");
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(initial == null ? "New Playlist" : "Rename",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
              hintText: "Playlist name",
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
      _toast("A Playlist with this name already exists");
      return;
    }
    setState(() => _videoPlaylists[name] = []);
    await _saveVideoPlaylists();
    _toast("Playlist created");
  }

  Future<void> _deleteVideoPlaylist(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Delete '$name'?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("The Playlist will be deleted. Videos will stay on your phone.",
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
    _toast("Playlist deleted");
  }

  Future<void> _renameVideoPlaylist(String oldName) async {
    final newName = await _askVideoPlaylistName(initial: oldName);
    if (newName == null || newName == oldName) return;
    if (_videoPlaylists.containsKey(newName)) {
      _toast("A Playlist with this name already exists");
      return;
    }
    setState(() {
      final list = _videoPlaylists.remove(oldName) ?? [];
      _videoPlaylists[newName] = list;
    });
    await _saveVideoPlaylists();
    _toast("Renamed");
  }

  Future<void> _addVideoToPlaylist(String name, String videoId) async {
    final list = _videoPlaylists[name] ?? [];
    if (!list.contains(videoId)) list.add(videoId);
    setState(() => _videoPlaylists[name] = list);
    await _saveVideoPlaylists();
    _toast("Added to '$name'");
  }

  Future<void> _removeVideoFromPlaylist(
      String name, String videoId) async {
    final list = _videoPlaylists[name] ?? [];
    list.remove(videoId);
    setState(() => _videoPlaylists[name] = list);
    await _saveVideoPlaylists();
    _toast("Removed from '$name'");
  }

  void _showAddVideoToPlaylistDialog(Map<String, String> video) {
    final videoId = video['id'];
    if (videoId == null || videoId.isEmpty) {
      _toast("This video cannot be added");
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                title: Text("Create new Playlist",
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

Future<void> _loadVideos() async {
  Future.delayed(const Duration(seconds: 60), () {
    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  });
  try {
    final prefs = await SharedPreferences.getInstance();
    _sortMode = prefs.getInt('sort_mode') ?? 0;
    final loadedCache = await VideoCacheDb.loadAll();

    if (loadedCache.isNotEmpty) {
      if (mounted) {
        setState(() {
          videoList = loadedCache;
          _sortList(videoList);
          _isLoading = false;
        });
      }
      _quickSyncVideos();
      return;
    }

    // अगर कैश खाली है, तो स्कैन करो
    await _scanVideos();
  } catch (e) {
    debugPrint("Error loading cached videos: $e");
    await _scanVideos();
  }
}
  
    Future<void> _loadSongs() async {
  if (_audioLoaded) {
    _quickSyncSongs();
    return;
  }
  if (mounted) setState(() => _audioLoading = true);

  try {
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
      ignoreCase: true, // 👈 ये ऐड किया है
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
    });
  } catch (e) {
    debugPrint('Music scan error: $e');
  } finally {
    if (mounted) {
      setState(() => _audioLoading = false);
    }
  }
    }

  Future<PermissionState>? _permFuture;
  Future<PermissionState> _askVideoPermission() {
    const opt = PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: RequestType.video,
        mediaLocation: false,
      ),
    );
    _permFuture ??= PhotoManager.requestPermissionExtend(requestOption: opt)
        .timeout(
          const Duration(seconds: 40),
          onTimeout: () => PhotoManager.getPermissionState(requestOption: opt),
        )
        .whenComplete(() => _permFuture = null);
    return _permFuture!;
  }

Future<Map<String, String>?> _assetToMap(
    AssetEntity asset, Map<String, String> customNames) async {
  try {
    File? file;
    try {
      file = await asset.originFile.timeout(const Duration(seconds: 8));
    } catch (_) {}
    try {
      file ??= await asset.file.timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (file == null || !file.existsSync()) return null;

    final d = asset.videoDuration;
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return {
      "title": (customNames[asset.id] ?? asset.title ?? file.path.split('/').last)
          .replaceAll('|||', '|'),
      "res": "${asset.width}x${asset.height}",
      "size": _formatSize(file.lengthSync()),
      "source": "Device",
      "duration": h > 0 ? "$h:$m:$s" : "$m:$s",
      "url": file.path,
      "isLocal": "true",
      "folder": file.parent.path.split('/').last,
      "id": asset.id,
    };
  } catch (e) {
    debugPrint("asset error ${asset.id}: $e");
    return null;
  }
}
  
Future<void> _scanVideos({bool silent = false}) async {
  try {
    final permission = await _askVideoPermission();
    if (!permission.isAuth && !permission.hasAccess) {
      if (!silent && mounted) {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
      return;
    }
    if (mounted && _permissionDenied) {
      setState(() => _permissionDenied = false);
    }
    PhotoManager.setIgnorePermissionCheck(true);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _scanInfo = 'No video albums found on this phone';
        });
      }
      return;
    }

    final album = albums.first;
    final count = await album.assetCountAsync;
    _scanInfo = 'Scan found $count videos';
    final prefs = await SharedPreferences.getInstance();
    final customNames = await _loadCustomNames();

    final loaded = <Map<String, String>>[];
    const page = 60;

    for (int start = 0; start < count; start += page) {
      final end = start + page > count ? count : start + page;
      final assets = await album.getAssetListRange(start: start, end: end);
      final results =
          await Future.wait(assets.map((a) => _assetToMap(a, customNames)));
      for (final r in results) {
        if (r != null) loaded.add(r);
      }

      // पहला batch आते ही लिस्ट दिखा दो
      if (!silent && mounted && loaded.isNotEmpty) {
        setState(() {
          videoList = List.of(loaded);
          _sortList(videoList);
          _isLoading = false;
        });
      }
    }

    // पुरानी अच्छी लिस्ट को खाली scan से overwrite मत करो
    if (loaded.isEmpty && videoList.isNotEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await VideoCacheDb.replaceAll(loaded);
    await prefs.setInt('last_video_count', count);

    if (mounted) {
      setState(() {
        videoList = loaded;
        _sortList(videoList);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Scan error: $e");
    if (mounted) setState(() => _isLoading = false);
    _toast("Scan error: $e");
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

 bool _syncingVideos = false;
Future<void> _quickSyncVideos() async {
  if (_syncingVideos) return;
  _syncingVideos = true;
  try {
    final permission = await _askVideoPermission();
if (!permission.isAuth && !permission.hasAccess) return;
    PhotoManager.setIgnorePermissionCheck(true);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (albums.isEmpty) return;

    final count = await albums[0].assetCountAsync;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('last_video_count') != count ||
        (videoList.isEmpty && count > 0)) {
      await _scanVideos(silent: true);
    }
  } catch (e) {
    debugPrint('Quick video sync error: $e');
  } finally {
    _syncingVideos = false;
  }
}
  
  @override
Widget build(BuildContext context) {
  final visibleVideos = _visibleVideos;
  // 👇 YAHAN SE POP-SCOPE SHURU KARO
  return PopScope(
    canPop: !(_isVideoSelectionMode || _isSongSelectionMode),
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) return;
      if (_isVideoSelectionMode) {
        setState(() { _isVideoSelectionMode = false; _selectedVideoIds.clear(); });
      } else if (_isSongSelectionMode) {
        setState(() { _isSongSelectionMode = false; _selectedSongIds.clear(); });
      }
    },
    child: Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 18,
        leading: (_isVideoSelectionMode ||
                (_currentTab == 1 && _isSongSelectionMode))
            ? IconButton(
                icon: Icon(Icons.close, color: AppTheme.textPrimary),
                onPressed: _isVideoSelectionMode
                    ? _toggleVideoSelectionMode
                    : _toggleSongSelectionMode,
              )
            : null,
        title: _isVideoSelectionMode
            ? Text(
                "${_selectedVideoIds.length}/${visibleVideos.length}",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary))
            : (_currentTab == 1 && _isSongSelectionMode)
                ? Text(
                    "${_selectedSongIds.length}/${_visibleSongs.length}",
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
                    _selectedVideoIds.length == visibleVideos.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: AppTheme.textPrimary,
                  ),
                  tooltip: "Select All",
                  onPressed: _selectAllVideos,
                ),
              ]
            : (_currentTab == 1 && _isSongSelectionMode)
                ? [
                    IconButton(
                      icon: Icon(
                        _selectedSongIds.length == _visibleSongs.length
                            ? Icons.deselect
                            : Icons.select_all,
                        color: AppTheme.textPrimary,
                      ),
                      tooltip: 'Select All',
                      onPressed: _selectAllSongs,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      tooltip: 'Delete selected songs',
                      onPressed: _selectedSongIds.isEmpty
                          ? null
                          : _deleteSelectedSongs,
                    ),
                  ]
                : [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VideoSearchScreen(videos: visibleVideos),
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
                                builder: (_) => ProfileScreen(
                                    videoList: videoList,
                                    songs: _songs)),
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
                      tooltip: _currentTab == 1 ? "Select Songs" : "Select Videos",
                      onPressed: _currentTab == 1
                          ? _toggleSongSelectionMode
                          : _toggleVideoSelectionMode,
                    ),
                  ],
      ),
      body: Column(
        children: [
      Expanded(
  child: _currentTab == 1 // 👈 Music tab
      ? _buildMusicTab()
      : _currentTab == 2 // 👈 Photos tab
          ? Center(
              child: Text(
                "Photos & Gallery Coming Soon...",
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16),
              ),
            )
          : _isLoading // 👈 Yahan Loading ka code add kiya hai
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          color: AppTheme.primaryBlue),
                      SizedBox(height: 20),
                      Text("Discovering videos...",
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                )
              : _permissionDenied // 👈 Permission Denied
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_off,
                                color: AppTheme.textSecondary, size: 60),
                            const SizedBox(height: 16),
                            Text("Video access permission required",
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  PhotoManager.openSetting(),
                              child: const Text("Open Settings"),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _visibleVideos.isEmpty // 👈 No Videos
                      ? RefreshIndicator(
                          onRefresh: () => _scanVideos(silent: true),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.3),
                              Center(
                                child: Text("No videos found",
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 16)),
                              ),
                              const SizedBox(height: 8),
                              if (_scanInfo.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Center(
                                    child: Text(_scanInfo,
                                        style: TextStyle(
                                            color: AppTheme.textTertiary,
                                            fontSize: 12)),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text("Pull down to rescan",
                                    style: TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator( // 👈 Videos List (Line 1452 se shuru hone wala code)
                          onRefresh: () async {
                            try {
                              await PhotoManager.editor.android.removeAllNoExistsAsset();
                            } catch (_) {}
                            await _scanVideos(silent: true);
                            await _loadRecent();
                          },
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(13, 4, 13, 0),
                                sliver: SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (kShowAdSlot) ...[
                                        Container(
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: AppTheme.card,
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (_recentTitle != null && !_isVideoSelectionMode) ...[
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
                                                    builder: (_) => VideoHistoryScreen(
                                                        allVideos: _visibleVideos),
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
                                            final recentIndex = _visibleVideos.indexWhere((v) => v['url'] == _recentUrl);
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RealVideoPlayer(
                                                  videoUrl: _recentUrl!,
                                                  title: _recentTitle!,
                                                  startPosition: _recentPosition,
                                                  playlist: recentIndex >= 0 ? _visibleVideos : null,
                                                  currentIndex: recentIndex >= 0 ? recentIndex : 0,
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
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(24),
                                            child: SizedBox(
                                              height: 150,
                                              width: double.infinity,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  VideoThumbnailWidget(videoPath: _recentUrl!),
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
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text("Continue Watching",
                                                            style: TextStyle(color: Colors.white70)),
                                                        const SizedBox(height: 5),
                                                        Text(_recentTitle!,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.white)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                      ],
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => setState(() => _videoTab = 0),
                                            child: Text("Videos",
                                                style: TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.bold,
                                                    color: _videoTab == 0
                                                        ? AppTheme.textPrimary
                                                        : AppTheme.textTertiary)),
                                          ),
                                          const SizedBox(width: 16),
                                          GestureDetector(
                                            onTap: () => setState(() => _videoTab = 1),
                                            child: Text("Folders",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: _videoTab == 1
                                                        ? AppTheme.textPrimary
                                                        : AppTheme.textTertiary)),
                                          ),
                                          const SizedBox(width: 16),
                                          GestureDetector(
                                            onTap: () => setState(() => _videoTab = 2),
                                            child: Text("My List",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: _videoTab == 2
                                                        ? AppTheme.textPrimary
                                                        : AppTheme.textTertiary)),
                                          ),
                                          const Spacer(),
                                          if (_videoTab == 2)
                                            IconButton(
                                              onPressed: _createVideoPlaylist,
                                              icon: Icon(Icons.add, color: AppTheme.iconColor),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          if (_videoTab != 2)
                                            IconButton(
                                              onPressed: _showSortMenu,
                                              icon: Icon(Icons.sort, color: AppTheme.iconColor),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                    ],
                                  ),
                                ),
                              ),
                              if (_videoTab == 0)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.85,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 16,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _buildVideoTile(
                                          context, visibleVideos[index], index, visibleVideos),
                                      childCount: visibleVideos.length,
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                  sliver: SliverToBoxAdapter(
                                    child: _videoTab == 1
                                        ? _buildFoldersList()
                                        : _buildPlaylistsList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
),
                ],
              ),

      // 👇 यह बटन सिर्फ वीडियो टैब (_currentTab == 0) में ही दिखेगा
floatingActionButton: (_currentTab == 0 && !_isVideoSelectionMode)
    ? FloatingActionButton(
        onPressed: () async {
          if (_recentUrl != null && _recentTitle != null) {
            final recentIndex = _visibleVideos.indexWhere((v) => v['url'] == _recentUrl);
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RealVideoPlayer(
                  videoUrl: _recentUrl!,
                  title: _recentTitle!,
                  startPosition: _recentPosition,
                  playlist: recentIndex >= 0 ? _visibleVideos : null,
                  currentIndex: recentIndex >= 0 ? recentIndex : 0,
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
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No recent video found")),
            );
          }
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
      )
    : null, // 👈 यह null होने की वजह से बाकी टैब्स (Music/Photos) में बटन गायब हो जाएगा
floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      
      bottomNavigationBar: (_isVideoSelectionMode || _isSongSelectionMode)
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                border: Border(top: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.star_border, color: Colors.white),
                      tooltip: "Add to Favorites",
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        if (_isVideoSelectionMode) {
                          if (_selectedVideoIds.isEmpty) return;
                          final count = _selectedVideoIds.length;
                          setState(() {
                            _favoriteVideoIds.addAll(_selectedVideoIds);
                            _isVideoSelectionMode = false;
                            _selectedVideoIds.clear();
                          });
                          await prefs.setStringList(
                              'favorite_videos', _favoriteVideoIds.toList());
                          _toast('Added $count videos to Favorites');
                        } else if (_isSongSelectionMode) {
                          if (_selectedSongIds.isEmpty) return;
                          final count = _selectedSongIds.length;
                          setState(() {
                            _favoriteIds.addAll(_selectedSongIds);
                            _isSongSelectionMode = false;
                            _selectedSongIds.clear();
                          });
                          await prefs.setStringList(
                              'favorite_songs',
                              _favoriteIds.map((e) => e.toString()).toList());
                          musicDataNotifier.value++;
                          _toast('Added $count songs to Favorites');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add, color: Colors.white),
                      tooltip: "Add to Playlist",
                      onPressed: _isVideoSelectionMode
                          ? _showAddMultipleToPlaylistDialog
                          : _showAddMultipleSongsToPlaylistDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      tooltip: "Delete",
                      onPressed: _isVideoSelectionMode
                          ? _deleteSelectedVideos
                          : _deleteSelectedSongs,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      tooltip: "More Options",
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(Icons.visibility_off,
                                      color: AppTheme.iconColor),
                                  title: Text(
                                    _isVideoSelectionMode
                                        ? "Hide selected videos"
                                        : "Hide selected songs",
                                    style:
                                        TextStyle(color: AppTheme.textPrimary),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    if (_isVideoSelectionMode &&
                                        _selectedVideoIds.isNotEmpty) {
                                      final c = _selectedVideoIds.length;
                                      setState(() {
                                        _hiddenVideoIds
                                            .addAll(_selectedVideoIds);
                                        _isVideoSelectionMode = false;
                                        _selectedVideoIds.clear();
                                      });
                                      await _saveHiddenData();
                                      _toast('$c videos hidden');
                                    } else if (_isSongSelectionMode &&
                                        _selectedSongIds.isNotEmpty) {
                                      final c = _selectedSongIds.length;
                                      setState(() {
                                        _hiddenSongIds.addAll(_selectedSongIds);
                                        _isSongSelectionMode = false;
                                        _selectedSongIds.clear();
                                      });
                                      await _saveHiddenData();
                                      _toast('$c songs hidden');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : NavigationBar(
              backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              indicatorColor: AppTheme.primaryBlue.withOpacity(0.2),
              selectedIndex: _currentTab,
                onDestinationSelected: (index) {
    setState(() {
      _currentTab = index;
      // Selection mode reset karo
      _isVideoSelectionMode = false;
      _selectedVideoIds.clear();
      _isSongSelectionMode = false;
      _selectedSongIds.clear();
    });
    
    // 👈 Index 1 ab Music tab hai
    if (index == 1 && !_audioLoaded) {
      _loadSongs();
    }
  },
  destinations: const [
    NavigationDestination(
        icon: Icon(Icons.video_library), label: "Videos"),
    // 👇 Center me Music aa gaya
    NavigationDestination(
        icon: Icon(Icons.music_note), label: "Music"),
    // 👇 Right me Photos aa gaya
    NavigationDestination(
        icon: Icon(Icons.photo_library), label: "Photos"),
  ],
),
    ),
  );
}

  String _folderKey(Map<String, String> v) {
    final url = v['url'] ?? '';
    final i = url.lastIndexOf('/');
    return i > 0 ? url.substring(0, i) : (v['folder'] ?? 'Unknown');
  }

  String _folderTitle(String key, List<String> allKeys) {
    final parts = key.split('/').where((e) => e.isNotEmpty).toList();
    final name = parts.isEmpty ? key : parts.last;
    final clash = allKeys.where((k) {
      final p = k.split('/').where((e) => e.isNotEmpty).toList();
      return (p.isEmpty ? k : p.last) == name;
    }).length > 1;
    if (clash && parts.length > 1) {
      return '$name (${parts[parts.length - 2]})';
    }
    return name;
  }

  Widget _buildFoldersList() {
  final grouped = <String, List<Map<String, String>>>{};
  for (final video in _visibleVideos) {
    final key = _folderKey(video);
    final folder = video['folder'] ?? 'Unknown';
    if (!_hiddenFolders.contains(key) && !_hiddenFolders.contains(folder)) {
      grouped.putIfAbsent(key, () => []).add(video);
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
          final folderKey = folderNames[index];
          final folderName = _folderTitle(folderKey, folderNames);
          final folderVideos = grouped[folderKey]!;
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
                  backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                              _hiddenFolders.add(folderKey);
                            });
                            _saveHiddenData();
                            _toast("'$folderName' hidden");
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
            // 👇 Hidden Folders Section (With PIN Lock)
      if (hiddenList.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: () async {
              if (_showHiddenFolders) {
                setState(() => _showHiddenFolders = false);
              } else {
                final ok = await _verifyOrCreateFolderPin();
                if (ok && mounted) {
                  setState(() => _showHiddenFolders = true);
                }
              }
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
                        ? "Hide Hidden Folders"
                        : "Show Hidden Folders (${hiddenList.length})",
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (_showHiddenFolders)
        ...hiddenList.map((folderKey) {
          final folderName = _folderTitle(folderKey, hiddenList);
          final folderVideos = videoList
              .where((v) =>
                  _folderKey(v) == folderKey || v['folder'] == folderKey)
              .toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _hiddenFolders.remove(folderKey);
                });
                _saveHiddenData();
                _toast("'$folderName' is visible again");
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
            "No Playlist yet\nTap + above to create one",
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
                    allVideos: _visibleVideos,
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
                        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

Widget _buildVideoTile(BuildContext context, Map<String, String> item, int index, List<Map<String, String>> list) {
  final isSelected = _selectedVideoIds.contains(item['id']);

  return GestureDetector(
    onTap: () async {
      // 👇 1. Selection Mode Logic
      if (_isVideoSelectionMode) {
        _toggleVideoSelection(item['id'] ?? '');
        return;
      }
      
      // 👇 2. Video Player kholne ka logic
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RealVideoPlayer(
            videoUrl: item['url']!,
            title: item['title']!,
            playlist: list,
            currentIndex: index,
          ),
        ),
      );

      // 👇 3. Recent aur Progress update karne ka logic
      if (result != null && result is Map) {
        setState(() {
          _recentTitle = result['title'];
          _recentUrl = result['url'];
          _recentPosition = result['position'];
          _recentDuration = result['duration'];
        });

        final url = result['url'] as String?;
        final pos = result['position'] as int? ?? 0;
        final dur = result['duration'] as int? ?? 0;
        if (url != null && dur > 0) {
          await _saveWatchProgress(url, pos / dur);
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _loadRecent();
      }
    },
    
    // 👇 4. Long Press par select karne ka logic
    onLongPress: () {
      if (!_isVideoSelectionMode) {
        _toggleVideoSelectionMode();
        _toggleVideoSelection(item['id'] ?? '');
      }
    },
    
    // 👇 5. VLC Jaisa 2-Column Grid Design
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail Area
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoThumbnailWidget(videoPath: item['url']!),
                ),
              ),
              // Duration Badge
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['duration']!,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // NEW Badge
              if (_isVideoNew(item['url']!))
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              // Checkbox (Selection Mode)
              if (_isVideoSelectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? Colors.greenAccent : Colors.white,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Video Title
        Text(
          item['title'] ?? 'No Title',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        
        // Info (Size, Resolution)
        Row(
          children: [
            Expanded(
              child: Text(
                "${item['res'] ?? ''} | ${item['size'] ?? ''}",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isVideoSelectionMode)
              IconButton(
                onPressed: () => _showVideoOptions(context, item, index),
                icon: Icon(Icons.more_vert, color: AppTheme.iconColor, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ],
    ),
  );
}

  void _showVideoOptions(BuildContext context,
      Map<String, String> item, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                leading: Icon(Icons.visibility_off,
                    color: AppTheme.iconColor),
                title: Text("Hide Video",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _hideVideo(item);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.folder_off, color: AppTheme.iconColor),
                title: Text("Hide Folder (${item['folder'] ?? ''})",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _hideFolder(_folderKey(item));
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
  String _scanInfo = '';

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
      'Newest First',
      'Oldest First',
      'Name (A-Z)',
      'Size (Largest First)',
      'Favorites First ❤️'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
        _toast('Play a song first');
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
        _toast('Not playing from a list right now');
        return;
      }
      await current.insert(nextIndex, source);
      _toast('"${globalSongNames[song.id] ?? song.title}" will play next');
    } catch (e) {
      debugPrint('Play next error: $e');
      _toast('Could not add song to queue');
    }
  }

  Future<void> _shareSong(SongModel song) async {
    try {
      final file = File(song.data);
      if (!await file.exists()) {
        _toast('File not found');
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
      _toast('Failed to share');
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("New Playlist",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: "Playlist name"),
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
      _toast("A Playlist with this name already exists");
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
    _toast("Added to '$name'");
  }

  void _addToPlaylistDialog(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add, color: AppTheme.primaryBlue),
                title: Text("Create new Playlist",
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Delete '$name'?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("Only the Playlist will be deleted. Songs will stay on your phone.",
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Rename Playlist",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: "New name"),
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
      _toast("A Playlist with this name already exists");
      return;
    }
    setState(() {
      final list = _playlists.remove(oldName) ?? [];
      _playlists[clean] = list;
    });
    await _savePlaylists();
    _toast("Renamed");
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
    _toast("Removed from '$playlistName'");
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

  Widget _songTile(int index, List<SongModel> visibleSongs) {
    final song = visibleSongs[index];
    final nowTag = globalAudioPlayer.sequenceState?.currentSource?.tag;
    final isPlaying =
        nowTag is MediaItem && nowTag.id == song.id.toString();
    final isSelected = _selectedSongIds.contains(song.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? AppTheme.primaryBlue.withOpacity(0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isSongSelectionMode) {
              _toggleSongSelection(song.id);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AudioPlayerScreen(songs: visibleSongs, initialIndex: index),
              ),
            );
          },
          onLongPress: () {
            if (!_isSongSelectionMode) {
              setState(() {
                _isSongSelectionMode = true;
                _selectedSongIds.add(song.id);
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                if (_isSongSelectionMode)
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Icon(
      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
      color: isSelected ? Colors.greenAccent : AppTheme.textSecondary,
      size: 26,
    ),
  ),
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
                      Text(song.artist ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (!_isSongSelectionMode) ...[
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
              ],
            ),
          ),
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
    if (_audioLoading && _visibleSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            SizedBox(height: 16),
            Text("Loading songs...",
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
              Text("Music access permission required",
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => PhotoManager.openSetting(),
                child: const Text("Open Settings"),
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
                child: const Text("Try again"),
              ),
            ],
          ),
        ),
      );
    }
    if (_visibleSongs.isEmpty) {
      return Center(
        child: Text("No songs found",
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
                      onTap: () => setState(() {
                        _musicSubTab = i;
                        _isSongSelectionMode = false;
                        _selectedSongIds.clear();
                      }),
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
                      songs: _visibleSongs,
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
    final visibleSongsList = _visibleSongs;
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
                        "No Playlist yet, tap + above to create one",
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
      for (final s in _visibleSongs) {
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
              Text("All Songs (${_visibleSongs.length})",
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
            color: AppTheme.primaryBlue, backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
              itemCount: visibleSongsList.length,
              itemBuilder: (context, index) =>
                  _songTile(index, visibleSongsList),
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
      'Newest First',
      'Oldest First',
      'Name (A to Z)'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
      backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                        ? "Remove from Favorites"
                        : "Add to Favorites",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_add,
                    color: AppTheme.iconColor),
                title: Text("Add to Playlist",
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
                leading: Icon(Icons.visibility_off,
                    color: AppTheme.iconColor),
                title: Text("Hide Song",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _hideSong(song);
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Rename Song",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: "Enter new name"),
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Delete song?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("This song will be permanently deleted from your device.",
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
              content: Text("Could not delete song")),
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Rename Video",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: "Enter new name"),
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
    final realIndex = videoList.indexWhere((v) => v['id'] == item['id']);
    if (realIndex < 0) return;
    final vid = videoList[realIndex]['id'];
    if (vid != null && vid.isNotEmpty) {
      await _saveCustomName(vid, cleanName);
    }
    setState(() => videoList[realIndex]['title'] = cleanName);

    final prefs = await SharedPreferences.getInstance();
    await VideoCacheDb.replaceAll(videoList);
  }

  Future<void> _deleteVideo(Map<String, String> item, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Delete video?",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text("This video will be permanently deleted from your device.",
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

    setState(() => videoList.removeWhere((v) => v['id'] == item['id']));
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
    await VideoCacheDb.replaceAll(videoList);
  }
}

  // ==================== Video Watch History Screen ====================
class VideoHistoryScreen extends StatefulWidget {
  final List<Map<String, String>> allVideos;

  const VideoHistoryScreen({
    super.key,
    required this.allVideos,
  });

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
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Clear all history?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('All watch history will be cleared',
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
                      Text('No watch history',
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

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final idx = widget.allVideos
                            .indexWhere((v) => v['url'] == url);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RealVideoPlayer(
                              videoUrl: url,
                              title: title,
                              startPosition: pos,
                              playlist: idx >= 0 ? widget.allVideos : null,
                              currentIndex: idx >= 0 ? idx : 0,
                            ),
                          ),
                        );
                        if (mounted) _loadHistory();
                      },
                      child: Container(
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
                      ),
                    );
                  },
                ),
    );
  }
}
