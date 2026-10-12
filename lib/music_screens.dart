part of 'main.dart';

      
  class SongListScreen extends StatefulWidget {
  final String title;
  final List<SongModel> songs;
  final void Function(SongModel song)? onMenu;
  final bool Function(SongModel song)? keep;
  final String? playlistName;
  final void Function(SongModel song)? onRemoveFromPlaylist;
  final Set<int>? favoriteIds;                              // 👈 नया
  final void Function(SongModel song)? onToggleFavorite;    // 👈 नया
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    this.onMenu,
    this.keep,
    this.playlistName,
    this.onRemoveFromPlaylist,
    this.favoriteIds,                                       // 👈 नया
    this.onToggleFavorite,                                  // 👈 नया
  });

  @override
  State<SongListScreen> createState() => _SongListScreenState();
  }

class _SongListScreenState extends State<SongListScreen> {
  @override
  void initState() {
    super.initState();
    musicDataNotifier.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    musicDataNotifier.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songs =
        widget.keep == null ? widget.songs : widget.songs.where(widget.keep!).toList();
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.title)),
      body: songs.isEmpty
          ? const Center(
              child: Text("यहाँ अभी कोई गाना नहीं है",
                  style: TextStyle(color: Colors.white54, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AudioPlayerScreen(
                              songs: songs, initialIndex: index),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        AlbumArtWidget(
  songId: song.id,
  size: 50,
  radius: 8,
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
                          // 👇 Remove from playlist button (सिर्फ playlist में दिखेगा)
    // 👇 Remove from playlist (सिर्फ playlist में)
  if (widget.playlistName != null &&
      widget.onRemoveFromPlaylist != null)
    IconButton(
      onPressed: () {
        widget.onRemoveFromPlaylist!(song);
        setState(() {});
      },
      icon: const Icon(Icons.remove_circle_outline,
          color: Colors.redAccent, size: 20),
      padding: const EdgeInsets.only(left: 8),
      constraints: const BoxConstraints(),
    ),
  // 👇 Favorite से हटाओ (सिर्फ Favorite list में)
  if (widget.onToggleFavorite != null &&
      widget.favoriteIds != null &&
      widget.favoriteIds!.contains(song.id))
    IconButton(
      onPressed: () {
        widget.onToggleFavorite!(song);
        setState(() {});
      },
      icon: const Icon(
        Icons.remove_circle_outline,
        color: Colors.pinkAccent,
        size: 20,
      ),
      padding: const EdgeInsets.only(left: 4),
      constraints: const BoxConstraints(),
    ),
  // 👇 Menu (3-dot)
  if (widget.onMenu != null)
    IconButton(
      onPressed: () => widget.onMenu!(song),
      icon: const Icon(Icons.more_vert,
          color: Colors.white60, size: 20),
      padding: const EdgeInsets.only(left: 8),
      constraints: const BoxConstraints(),
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

// ==================== Queue Screen ====================
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Queue'),
      ),
      body: StreamBuilder<SequenceState?>(
        stream: globalAudioPlayer.sequenceStateStream,
        builder: (context, snapshot) {
          final sequence = snapshot.data?.sequence ?? [];
          final currentIndex = snapshot.data?.currentIndex ?? 0;

          if (sequence.isEmpty) {
            return const Center(
              child: Text('Queue खाली है',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: sequence.length,
            itemBuilder: (context, i) {
              final source = sequence[i];
              final tag = source.tag;
              final title = tag is MediaItem ? tag.title : 'Unknown';
              final artist = tag is MediaItem ? (tag.artist ?? '') : '';
              final isCurrent = i == currentIndex;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xff2D8CFF)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isCurrent
                        ? const Icon(Icons.graphic_eq,
                            color: Colors.white, size: 22)
                        : Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isCurrent
                          ? const Color(0xff2D8CFF)
                          : Colors.white,
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal),
                ),
                subtitle: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                trailing: isCurrent
                    ? const Text('चल रहा',
                        style: TextStyle(
                            color: Color(0xff2D8CFF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold))
                    : null,
                onTap: () async {
                  if (i == currentIndex) return;
                  await globalAudioPlayer.seek(Duration.zero, index: i);
                  await globalAudioPlayer.play();
                  if (context.mounted) Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ==================== Music Search Screen ====================
class MusicSearchScreen extends StatefulWidget {
  final List<SongModel> songs;
  final void Function(SongModel song)? onMenu;
  const MusicSearchScreen({
    super.key,
    required this.songs,
    this.onMenu,
  });

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();
    final results = q.isEmpty
        ? <SongModel>[]
        : widget.songs.where((s) {
            final title =
                (globalSongNames[s.id] ?? s.title).toLowerCase();
            final artist = (s.artist ?? '').toLowerCase();
            return title.contains(q) || artist.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'गाना या कलाकार खोजें...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: q.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, color: Colors.white24, size: 60),
                  SizedBox(height: 12),
                  Text('गाना या कलाकार का नाम लिखें',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 14)),
                ],
              ),
            )
          : results.isEmpty
              ? const Center(
                  child: Text('कुछ नहीं मिला',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final song = results[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AudioPlayerScreen(
                                  songs: results, initialIndex: i),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            AlbumArtWidget(
                              songId: song.id,
                              size: 50,
                              radius: 8,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    globalSongNames[song.id] ?? song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.onMenu != null)
                              IconButton(
                                onPressed: () => widget.onMenu!(song),
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white60, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
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
