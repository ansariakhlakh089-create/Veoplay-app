part of 'main.dart';

// ==================== Video Playlist Screen ====================
class VideoPlaylistScreen extends StatefulWidget {
  final String playlistName;
  final List<String> videoIds;
  final List<Map<String, String>> allVideos;
  final Future<void> Function(String videoId) onRemove;
  final Future<void> Function() onDelete;
  final Future<void> Function() onRename;

  const VideoPlaylistScreen({
    super.key,
    required this.playlistName,
    required this.videoIds,
    required this.allVideos,
    required this.onRemove,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<VideoPlaylistScreen> createState() => _VideoPlaylistScreenState();
}

class _VideoPlaylistScreenState extends State<VideoPlaylistScreen> {
  late List<String> _ids;

  @override
  void initState() {
    super.initState();
    _ids = List<String>.of(widget.videoIds);
  }

  List<Map<String, String>> get _videos {
    final byId = <String, Map<String, String>>{};
    for (final v in widget.allVideos) {
      final id = v['id'] ?? '';
      if (id.isNotEmpty) byId[id] = v;
    }
    final out = <Map<String, String>>[];
    for (final id in _ids) {
      final v = byId[id];
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<void> _remove(String id) async {
    await widget.onRemove(id);
    if (mounted) setState(() => _ids.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        title: Text(widget.playlistName,
            style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          PopupMenuButton<String>(
            color: AppTheme.card,
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onSelected: (v) async {
              if (v == 'rename') {
                await widget.onRename();
              } else if (v == 'delete') {
                await widget.onDelete();
              }
              if (mounted) Navigator.pop(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'rename',
                child: Text('Rename',
                    style: TextStyle(color: AppTheme.textPrimary)),
              ),
              const PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
      body: videos.isEmpty
          ? Center(
              child: Text('इस Playlist में कोई वीडियो नहीं है',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 16)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: videos.length,
              itemBuilder: (context, i) {
                final item = videos[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RealVideoPlayer(
                            videoUrl: item['url']!,
                            title: item['title']!,
                            playlist: videos,
                            currentIndex: i,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: VideoThumbnailWidget(videoPath: item['url']!),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(item['duration'] ?? '',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _remove(item['id'] ?? ''),
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.redAccent, size: 20),
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
