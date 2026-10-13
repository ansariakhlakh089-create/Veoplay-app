part of 'main.dart';

// ==================== Profile Screen ====================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'VeoPlay User';
  int _totalVideos = 0;
  int _totalFavorites = 0;
  int _totalPlaylists = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'VeoPlay User';
    final videos = prefs.getStringList('cached_videos') ?? [];
    final favSongs = prefs.getStringList('favorite_songs') ?? [];
    final favVideos = prefs.getStringList('favorite_videos') ?? [];
    final playlists = prefs.getStringList('user_playlists') ?? [];

    if (!mounted) return;
    setState(() {
      _userName = name;
      _totalVideos = videos.length;
      _totalFavorites = favSongs.length + favVideos.length;
      _totalPlaylists = playlists.length;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text("नाम बदलें",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "अपना नाम लिखें"),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);
    if (mounted) setState(() => _userName = newName);
  }

  Widget _statBox(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _editName,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xff2D8CFF), Color(0xff6B4DFF)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _editName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit,
                      color: Colors.white54, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('Tap to edit',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 30),
            Row(
              children: [
                _statBox('Videos', _totalVideos,
                    Icons.video_library, const Color(0xff2D8CFF)),
                const SizedBox(width: 12),
                _statBox('Favorites', _totalFavorites,
                    Icons.favorite, Colors.pinkAccent),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBox('Playlists', _totalPlaylists,
                    Icons.queue_music, Colors.orangeAccent),
                const SizedBox(width: 12),
                _statBox('Songs', 0,
                    Icons.music_note, Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xff2D8CFF), size: 20),
                      SizedBox(width: 8),
                      Text('App Info',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  _infoRow('App Name', 'VeoPlay'),
                  _infoRow('Version', '1.0.0'),
                  _infoRow('Developer', 'Akhlakh Ansari'),
                  _infoRow('Build', 'Release'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('© 2026 Akhlakh Ansari',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _infoRow extends StatelessWidget {
  final String label;
  final String value;
  const _infoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
