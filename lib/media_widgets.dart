part of 'main.dart';

// ==================== Album Art Widget ====================
class AlbumArtWidget extends StatefulWidget {
  final int songId;
  final double size;
  final double radius;
  final bool circle;
  final IconData fallbackIcon;
  const AlbumArtWidget({
    super.key,
    required this.songId,
    this.size = 50,
    this.radius = 8,
    this.circle = false,
    this.fallbackIcon = Icons.music_note,
  });

  @override
  State<AlbumArtWidget> createState() => _AlbumArtWidgetState();
}

class _AlbumArtWidgetState extends State<AlbumArtWidget> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AlbumArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _bytes = null;
    });
    try {
      final bytes = await OnAudioQuery().queryArtwork(
        widget.songId,
        ArtworkType.AUDIO,
        size: 300,
        quality: 50,
      );
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Album art error: $e');
      if (mounted) {
        setState(() {
          _bytes = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rad = widget.circle
        ? BorderRadius.circular(widget.size / 2)
        : BorderRadius.circular(widget.radius);

    // Fallback: vinyl-style premium design
    Widget fallback() => Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF1E2A47),
                Color(0xFF0F1626),
              ],
            ),
            borderRadius: rad,
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // विनाइल रिंग्स (हल्के)
              for (final s in [0.85, 0.68, 0.51])
                Container(
                  width: widget.size * s,
                  height: widget.size * s,
                  decoration: BoxDecoration(
                    shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: widget.circle ? null : rad,
                    border: Border.all(
                      color: const Color(0xff2D8CFF).withOpacity(0.10),
                      width: 1,
                    ),
                  ),
                ),
              // Center में बड़ा note
              Icon(
                widget.fallbackIcon,
                color: const Color(0xff2D8CFF).withOpacity(0.85),
                size: widget.size * 0.42,
              ),
              // छोटे decorative notes
              Positioned(
                top: widget.size * 0.10,
                right: widget.size * 0.10,
                child: Icon(
                  Icons.music_note,
                  color: Colors.white.withOpacity(0.10),
                  size: widget.size * 0.14,
                ),
              ),
              Positioned(
                bottom: widget.size * 0.12,
                left: widget.size * 0.12,
                child: Icon(
                  Icons.graphic_eq,
                  color: Colors.white.withOpacity(0.08),
                  size: widget.size * 0.12,
                ),
              ),
            ],
          ),
        );

    if (_loading) {
      return ClipRRect(borderRadius: rad, child: fallback());
    }

    if (_bytes == null || _bytes!.isEmpty) {
      return ClipRRect(borderRadius: rad, child: fallback());
    }

    return ClipRRect(
      borderRadius: rad,
      child: Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback(),
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
