part of 'main.dart';

// ==================== Video Search Screen ====================
class VideoSearchScreen extends StatefulWidget {
  final List<Map<String, String>> videos;
  const VideoSearchScreen({super.key, required this.videos});

  @override
  State<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends State<VideoSearchScreen> {
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
        ? <Map<String, String>>[]
        : widget.videos.where((v) {
            final title = (v['title'] ?? '').toLowerCase();
            final folder = (v['folder'] ?? '').toLowerCase();
            return title.contains(q) || folder.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'वीडियो का नाम खोजें...',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: q.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, color: AppTheme.textTertiary, size: 60),
                  const SizedBox(height: 12),
                  Text('वीडियो या फोल्डर का नाम लिखें',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            )
          : results.isEmpty
              ? Center(
                  child: Text('कुछ नहीं मिला',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final item = results[i];
                    final originalIndex = widget.videos.indexOf(item);
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
                                playlist: widget.videos,
                                currentIndex: originalIndex,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: VideoThumbnailWidget(
                                  videoPath: item['url']!),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${item['duration']} • ${item['folder']}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
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
