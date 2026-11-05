part of 'main.dart';

// Feedback के लिए अपना email/नंबर यहाँ लिखें (खाली छोड़ने पर संपर्क वाली लाइन नहीं दिखेगी)
const String kFeedbackContact = '';

// ==================== Profile Screen ====================
class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'VeoPlay User';
  int _totalVideos = 0;
  int _totalSongs = 0;
  int _totalFavorites = 0;
  int _totalPlaylists = 0;

  @override
  void initState() {
    super.initState();
    isDarkMode.addListener(_onThemeChanged);
    _loadStats();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'VeoPlay User';
    final videoCount = await VideoCacheDb.count();
    final songs = prefs.getStringList('cached_songs') ?? [];
    final favSongs = prefs.getStringList('favorite_songs') ?? [];
    final favVideos = prefs.getStringList('favorite_videos') ?? [];
    final playlists = prefs.getStringList('user_playlists') ?? [];

    if (!mounted) return;
    setState(() {
      _userName = name;
      _totalVideos = videoCount;
      _totalSongs = songs.length;
      _totalFavorites = favSongs.length + favVideos.length;
      _totalPlaylists = playlists.length;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Rename",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: "Enter your name"),
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

  void _showHelpDialog() {
    Widget q(String a, String b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(b,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Help & Feedback',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              q('Videos or songs not showing?',
                  'Grant Photos/Videos and Music permissions in Phone Settings → Apps → VeoPlay → Permissions. Then pull down on Home, or tap "Rescan Media" in Settings.'),
              q('What can I do while playing a video?',
                  'Double-tap for ±10s, long press for 2x speed, swipe up/down for brightness and volume, and swipe left/right to seek.'),
              q('How to resume a video where I left off?',
                  'It happens automatically. Keep Resume enabled in Settings.'),
              q('How to stop music automatically?',
                  'Use the clock icon in the Music player to set a Sleep Timer.'),
              if (kFeedbackContact.isNotEmpty) ...[
                const Divider(),
                Text('Contact us for feedback or issues:',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                SelectableText(kFeedbackContact,
                    style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
        actions: [
          if (kFeedbackContact.isNotEmpty)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: kFeedbackContact));
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
              child: const Text('Copy'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Privacy Policy',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VeoPlay stores all data locally on your device. No personal information is collected, uploaded, or shared with anyone.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text('What we store:',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                '• Your name (for display)\n• Favorites and playlists\n• Playback positions\n• App preferences',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'To delete all data, use "Clear All Data" from Settings.',
                style: TextStyle(
                    color: AppTheme.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    SharedPreferences.getInstance().then((p) {
      final recentSongs = p.getStringList('recent_songs') ?? [];
      final recentVideos = p.getString('recent_title');
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('History',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (recentVideos != null)
                  _historyItem(
                      Icons.videocam, 'Last video: $recentVideos'),
                if (recentSongs.isNotEmpty)
                  _historyItem(Icons.music_note,
                      '${recentSongs.length} songs recently played'),
                if (recentVideos == null && recentSongs.isEmpty)
                  Text('No history',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14)),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _historyItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.cardBorder, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$value',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 1),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double size = 80,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.card,
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(icon,
                color: AppTheme.primaryBlue, size: size * 0.4),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _listItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.cardBorder, width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppTheme.iconColor, size: 22),
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right,
            color: AppTheme.textTertiary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              // ==================== TOP BAR ====================
              Row(
                children: [
                  GestureDetector(
                    onTap: _editName,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryPurple
                          ],
                        ),
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _editName,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _userName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit,
                                  color: AppTheme.textSecondary,
                                  size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.settings,
                          color: AppTheme.primaryBlue, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==================== PRIVACY / THEME / HISTORY ====================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleButton(
  icon: Icons.lock_outline, // 👈 Icon change kiya
  label: 'Private',         // 👈 Label change kiya
  onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HiddenItemsScreen(
        allVideos: widget.videoList,
        allSongs: widget.songs,
      ), // 👈 MaterialPageRoute close
    ), // 👈 Navigator.push close
  );
},
                  _circleButton(
                    icon: Icons.history,
                    label: 'History',
                    onTap: _showHistoryDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // ==================== STATS ====================
              Row(
                children: [
                  _statBox('Videos', _totalVideos,
                      Icons.video_library,
                      AppTheme.primaryBlue),
                  const SizedBox(width: 6),
                  _statBox('Songs', _totalSongs, Icons.music_note,
                      Colors.greenAccent),
                  const SizedBox(width: 6),
                  _statBox('Favorites', _totalFavorites,
                      Icons.favorite, Colors.pinkAccent),
                  const SizedBox(width: 6),
                  _statBox('Playlists', _totalPlaylists,
                      Icons.queue_music, Colors.orangeAccent),
                ],
              ),
              const SizedBox(height: 16),

              // ==================== LIST ITEMS ====================
              _listItem(
                icon: Icons.settings,
                title: 'Setting',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const SettingsScreen()),
                  );
                },
              ),

              // ==================== DARK MODE TOGGLE ====================
              ValueListenableBuilder<bool>(
                valueListenable: isDarkMode,
                builder: (context, isDark, child) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.cardBorder, width: 1),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: AppTheme.iconColor,
                        size: 22,
                      ),
                      title: Text(
                        isDark ? "Dark Mode" : "Light Mode",
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                      trailing: Switch(
                        value: isDark,
                        activeColor: AppTheme.primaryBlue,
                        onChanged: (val) async {
                          await AppTheme.toggle(val);
                        },
                      ),
                    ),
                  );
                },
              ),

             _listItem(
  icon: Icons.privacy_tip_outlined,
  title: 'Privacy Policy',
  onTap: _showPrivacyDialog,
),     
              _listItem(
                icon: Icons.help_outline,
                title: 'Help & Feedback',
                onTap: _showHelpDialog,
              ),
              if (false)
              _listItem(
                icon: Icons.star_outline,
                title: 'Rate Us',
                onTap: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content:
                          Text('Rate on Play Store'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _listItem(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => _showAboutDialog(),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  '© 2026 Akhlakh Ansari\nAll Rights Reserved',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('About VeoPlay',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VeoPlay - Video & Music Player',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Version: $appVersionName',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Developer: Akhlakh Ansari',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Build: Release',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Text(
                'A lightweight, ad-free video and music player with dual video mode, equalizer, and background playback.',
                style: TextStyle(
                    color: AppTheme.textTertiary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

  class HiddenItemsScreen extends StatefulWidget {
  final List<Map<String, String>> allVideos;
  final List<SongModel> allSongs;
  
  const HiddenItemsScreen({super.key, required this.allVideos, required this.allSongs});

  @override
  State<HiddenItemsScreen> createState() => _HiddenItemsScreenState();
}

class _HiddenItemsScreenState extends State<HiddenItemsScreen> {
  Set<String> _hiddenVideoIds = {};
  Set<int> _hiddenSongIds = {};

  @override
  void initState() {
    super.initState();
    _loadHiddenItems();
  }

  Future<void> _loadHiddenItems() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hiddenVideoIds = (prefs.getStringList('hidden_videos') ?? []).toSet();
        _hiddenSongIds = (prefs.getStringList('hidden_songs') ?? []).map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
      });
    }
  }

  // Unhide karne ka function
  Future<void> _unhideVideo(String id) async {
    setState(() => _hiddenVideoIds.remove(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_videos', _hiddenVideoIds.toList());
    rescanRequestNotifier.value++; // Home screen refresh
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video Unhidden')));
  }

  Future<void> _unhideSong(int id) async {
    setState(() => _hiddenSongIds.remove(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_songs', _hiddenSongIds.map((e) => e.toString()).toList());
    rescanRequestNotifier.value++;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song Unhidden')));
  }

  @override
  Widget build(BuildContext context) {
    // Sirf hidden items filter karo
    final hiddenVideos = widget.allVideos.where((v) => _hiddenVideoIds.contains(v['id'])).toList();
    final hiddenSongs = widget.allSongs.where((s) => _hiddenSongIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        title: Text('Private', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: (hiddenVideos.isEmpty && hiddenSongs.isEmpty)
          ? Center(child: Text("No hidden items", style: TextStyle(color: AppTheme.textSecondary)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (hiddenVideos.isNotEmpty) ...[
                  Text("Videos", style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                  ...hiddenVideos.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['title'] ?? '', style: TextStyle(color: AppTheme.textPrimary)),
                    trailing: TextButton(
                      onPressed: () => _unhideVideo(item['id']!),
                      child: const Text('Unhide', style: TextStyle(color: Colors.greenAccent)),
                    ),
                    onTap: () {
                      // Video play karo
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RealVideoPlayer(
                        videoUrl: item['url']!,
                        title: item['title']!,
                        playlist: hiddenVideos,
                        currentIndex: hiddenVideos.indexOf(item),
                      )));
                    },
                  )),
                  const Divider(),
                ],
                if (hiddenSongs.isNotEmpty) ...[
                  Text("Songs", style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                  ...hiddenSongs.map((song) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(globalSongNames[song.id] ?? song.title, style: TextStyle(color: AppTheme.textPrimary)),
                    trailing: TextButton(
                      onPressed: () => _unhideSong(song.id),
                      child: const Text('Unhide', style: TextStyle(color: Colors.greenAccent)),
                    ),
                    onTap: () {
                      // Music play karo
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AudioPlayerScreen(
                        songs: hiddenSongs, 
                        initialIndex: hiddenSongs.indexOf(song)
                      )));
                    },
                  )),
                ],
              ],
            ),
    );
  }
}        
