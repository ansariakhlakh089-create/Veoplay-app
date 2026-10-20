part of 'main.dart';

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
  int _sleepRemaining = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _player = globalAudioPlayer;
    _sleepRemaining = musicSleepRemaining.value;
    musicSleepRemaining.addListener(_onSleepChanged);

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
            artUri: song.albumId != null
                ? Uri.parse(
                    'content://media/external/audio/albumart/${song.albumId}')
                : null,
          ),
        );
      }).toList();

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: _currentIndex,
      );
      await _player.play();
    } catch (e) {
      debugPrint('Song setup error: $e');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text("ये गाना नहीं चल पाया, फ़ाइल हट चुकी हो सकती है"),
          ),
        );
      }
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

  Future<void> _playNextSong(SongModel song) async {
    try {
      if (globalAudioPlayer.sequence == null ||
          globalAudioPlayer.sequence!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('पहले कोई गाना चलाओ')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('अभी लिस्ट से गाना नहीं चल रहा')),
        );
        return;
      }
      await current.insert(nextIndex, source);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '"${globalSongNames[song.id] ?? song.title}" अगला चलेगा'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Play next error: $e');
    }
  }

  Future<void> _shareSong(SongModel song) async {
    try {
      final file = File(song.data);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('फ़ाइल नहीं मिली')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share नहीं हो पाया')),
      );
    }
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

  void _showMusicSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                if (_sleepRemaining > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$_sleepRemaining मिनट बाकी',
                    style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [5, 10, 15, 30, 60].map((min) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _startMusicSleepTimer(min);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer,
                                color: AppTheme.textSecondary, size: 16),
                            const SizedBox(width: 6),
                            Text('$min मिनट',
                                style:
                                    TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (_sleepRemaining > 0)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _cancelMusicSleepTimer();
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

  void _onSleepChanged() {
    if (mounted) setState(() => _sleepRemaining = musicSleepRemaining.value);
  }

  void _startMusicSleepTimer(int minutes) {
    startGlobalSleepTimer(minutes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$minutes मिनट बाद गाना रुकेगा')),
    );
  }

  void _cancelMusicSleepTimer() {
    cancelGlobalSleepTimer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep timer हटाया')),
      );
    }
  }

  Future<void> _showEqualizerDialog() async {
    AndroidEqualizerParameters? params;
    try {
      params = await globalEqualizer.parameters;
    } catch (e) {
      debugPrint('Equalizer error: $e');
    }
    if (!mounted) return;
    if (params == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('इस फ़ोन पर Equalizer उपलब्ध नहीं है')),
      );
      return;
    }
    final p = params;
    bool enabled = globalEqualizer.enabled;

    String freqLabel(double hz) =>
        hz >= 1000 ? '${(hz / 1000).toStringAsFixed(1)}k' : '${hz.round()}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Equalizer",
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("चालू करें",
                          style: TextStyle(color: AppTheme.textPrimary)),
                      value: enabled,
                      onChanged: (v) async {
                        await globalEqualizer.setEnabled(v);
                        setModalState(() => enabled = v);
                      },
                    ),
                    for (final band in p.bands)
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(freqLabel(band.centerFrequency),
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ),
                          Expanded(
                            child: StreamBuilder<double>(
                              stream: band.gainStream,
                              builder: (context, snap) {
                                final g = (snap.data ?? band.gain)
                                    .clamp(p.minDecibels, p.maxDecibels)
                                    .toDouble();
                                return Slider(
                                  value: g,
                                  min: p.minDecibels,
                                  max: p.maxDecibels,
                                  onChanged: enabled
                                      ? (v) => band.setGain(v)
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _presetBtn("Reset", () async {
                          for (final b in p.bands) {
                            await b.setGain(0);
                          }
                        }),
                        _presetBtn("Bass Boost", () async {
                          for (var i = 0; i < p.bands.length; i++) {
                            await p.bands[i]
                                .setGain(i < 2 ? p.maxDecibels * 0.6 : 0);
                          }
                        }),
                      ],
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

  Widget _eqSlider(String label, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppTheme.primaryBlue,
                inactiveTrackColor: AppTheme.cardBorder,
                thumbColor: AppTheme.primaryBlue,
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
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetBtn(String name, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
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
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Add to Playlist",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.add, color: AppTheme.primaryBlue),
                title: Text("Create New Playlist",
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final controller = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.card,
                      title: Text("New Playlist",
                          style: TextStyle(color: AppTheme.textPrimary)),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Enter playlist name",
                          hintStyle:
                              TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
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

                // 👇 Fix: पहले से हो तो उसमें जोड़ो, वरना नई बनाओ
                if (playlists.containsKey(clean)) {
                  final existing = playlists[clean] ?? [];
                  if (!existing.contains(song.id)) {
                    existing.add(song.id);
                  }
                  playlists[clean] = existing;
                } else {
                  playlists[clean] = [song.id];
                }

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
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "No playlist yet. Create one!",
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            ...playlists.keys.map((name) => ListTile(
                  leading: Icon(Icons.queue_music,
                      color: AppTheme.iconColor),
                  title: Text(name,
                      style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text(
                    "${playlists[name]!.length} songs",
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
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
  musicSleepRemaining.removeListener(_onSleepChanged);
  super.dispose();
}

@override
Widget build(BuildContext context) {
  if (widget.songs.isEmpty) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Text("No songs found",
            style: TextStyle(color: AppTheme.textPrimary)),
      ),
    );
  }
  if (_setupError != null) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
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
    backgroundColor: AppTheme.bg,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back,
            color: AppTheme.textPrimary, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.queue_music,
              color: AppTheme.iconColor),
          tooltip: 'Queue',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QueueScreen(),
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(
            _sleepRemaining > 0 ? Icons.timer : Icons.timer_outlined,
            color: _sleepRemaining > 0
                ? AppTheme.primaryBlue
                : AppTheme.iconColor,
          ),
          tooltip: _sleepRemaining > 0
              ? '$_sleepRemaining मिनट बाकी'
              : 'Sleep timer',
          onPressed: _showMusicSleepTimerDialog,
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          AlbumArtWidget(
            songId: song.id,
            size: 250,
            radius: 20,
          ),
          const SizedBox(height: 40),
          Text(
            songTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            song.artist ?? "Unknown",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                    color: AppTheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppTheme.textPrimary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => _shareSong(song),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.share,
                    color: AppTheme.textPrimary,
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
                    color: AppTheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.equalizer,
                    color: AppTheme.textPrimary,
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
                        : AppTheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFav
                          ? Colors.pinkAccent
                          : AppTheme.primaryBlue.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav
                        ? Colors.pinkAccent
                        : AppTheme.textPrimary,
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
                        activeColor: AppTheme.primaryBlue,
                        inactiveColor: AppTheme.cardBorder,
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
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                          Text(_formatDuration(duration),
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
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
                      ? AppTheme.textTertiary
                      : AppTheme.primaryBlue,
                  size: 24,
                ),
                onPressed: _toggleLoop,
              ),
              IconButton(
                icon: Icon(Icons.skip_previous,
                    color: AppTheme.textPrimary, size: 32),
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
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
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
                icon: Icon(Icons.skip_next,
                    color: AppTheme.textPrimary, size: 32),
                onPressed: _playNext,
              ),
              IconButton(
                icon: Icon(Icons.speed,
                    color: AppTheme.textTertiary, size: 24),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.card,
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
                                        : AppTheme.textPrimary,
                                  )),
                              selected: _player.speed == s,
                              selectedColor: AppTheme.primaryBlue,
                              backgroundColor: AppTheme.cardBorder,
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
