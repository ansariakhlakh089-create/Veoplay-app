part of 'main.dart';

// ==================== Profile Screen ====================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'VeoPlay User';
  int _userCoins = 0;
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
    final coins = prefs.getInt('user_coins') ?? 0;
    final videos = prefs.getStringList('cached_videos') ?? [];
    final favSongs = prefs.getStringList('favorite_songs') ?? [];
    final favVideos = prefs.getStringList('favorite_videos') ?? [];
    final playlists = prefs.getStringList('user_playlists') ?? [];

    if (!mounted) return;
    setState(() {
      _userName = name;
      _userCoins = coins;
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

  void _showGetCoinDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Get Coins',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _coinOption('🎬 Watch Ad', '+50 coins', () async {
                Navigator.pop(context);
                await _addCoins(50);
              }),
              _coinOption('🎁 Daily Reward', '+100 coins', () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                final last = prefs.getString('last_daily_claim');
                final today = DateTime.now().toIso8601String().substring(0, 10);
                if (last == today) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('आज का reward ले लिया')),
                    );
                  }
                  return;
                }
                await prefs.setString('last_daily_claim', today);
                await _addCoins(100);
              }),
              _coinOption('⭐ Complete Task', '+200 coins', () async {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('यह feature जल्द आएगा')),
                  );
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coinOption(String title, String reward, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        trailing: Text(reward,
            style: const TextStyle(
                color: Color(0xff2D8CFF),
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    );
  }

  Future<void> _addCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    _userCoins += amount;
    await prefs.setInt('user_coins', _userCoins);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $amount coins मिले!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRedeemDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Redeem Gift',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _redeemItem('🎁 7 Day VIP', 500),
              _redeemItem('🎬 Remove Ads', 300),
              _redeemItem('⭐ HD Unlock', 1000),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _redeemItem(String title, int cost) {
    final canAfford = _userCoins >= cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$cost ',
                style: const TextStyle(
                    color: Color(0xff2D8CFF),
                    fontWeight: FontWeight.bold)),
            const Icon(Icons.monetization_on,
                color: Color(0xff2D8CFF), size: 16),
          ],
        ),
        enabled: canAfford,
        onTap: canAfford
            ? () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                _userCoins -= cost;
                await prefs.setInt('user_coins', _userCoins);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🎉 $title unlock हो गया!')),
                  );
                }
              }
            : null,
      ),
    );
  }

  void _showVipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text('⭐ VIP Benefits',
            style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 7 Day Free Trial',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 6),
            Text('• No Ads',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 6),
            Text('• Unlimited HD Quality',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 6),
            Text('• Unlimited Downloads',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('VIP subscription जल्द आएगी'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Start Trial',
                style: TextStyle(
                    color: Color(0xff2D8CFF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double size = 100,
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
              color: Colors.white10,
              border: Border.all(
                color: const Color(0xff2D8CFF).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(icon,
                color: const Color(0xff2D8CFF), size: size * 0.4),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.white70, size: 22),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ==================== TOP: AVATAR + NAME ====================
            GestureDetector(
              onTap: _editName,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xff2D8CFF), Color(0xff6B4DFF)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 50),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _editName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit,
                      color: Colors.white54, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==================== COIN SECTION ====================
            Row(
              children: [
                // My Coin
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.monetization_on,
                            color: Color(0xff2D8CFF), size: 28),
                        const SizedBox(height: 6),
                        const Text('My Coin',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text('$_userCoins',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Get Coin
                Expanded(
                  child: GestureDetector(
                    onTap: _showGetCoinDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xff2D8CFF)
                              .withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.add_shopping_cart,
                              color: Color(0xff2D8CFF), size: 28),
                          const SizedBox(height: 6),
                          const Text('Get Coin',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11)),
                          const SizedBox(height: 2),
                          const Text('FREE',
                              style: TextStyle(
                                  color: Color(0xff2D8CFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Redeem Gift
                Expanded(
                  child: GestureDetector(
                    onTap: _showRedeemDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xff2D8CFF)
                              .withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard,
                              color: Color(0xff2D8CFF), size: 28),
                          const SizedBox(height: 6),
                          const Text('Redeem Gift',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11)),
                          const SizedBox(height: 2),
                          const Text('GIFT',
                              style: TextStyle(
                                  color: Color(0xff2D8CFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ==================== VIP BANNER ====================
            GestureDetector(
              onTap: _showVipDialog,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff1E3A8A), Color(0xff6B4DFF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xff2D8CFF),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('VIP',
                          style: TextStyle(
                              color: Color(0xff1E3A8A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('7 Day Free Trial',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                              'no ads • unlimited HD • unlimited download',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==================== PRIVACY / THEME / HISTORY ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _circleButton(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Privacy Policy जल्द add होगी')),
                    );
                  },
                ),
                _circleButton(
                  icon: Icons.palette_outlined,
                  label: 'Theme',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Theme जल्द add होगी')),
                    );
                  },
                ),
                _circleButton(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('History जल्द add होगी')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ==================== STATS ====================
            Row(
              children: [
                _statBox('Videos', _totalVideos, Icons.video_library,
                    const Color(0xff2D8CFF)),
                const SizedBox(width: 8),
                _statBox('Favorites', _totalFavorites, Icons.favorite,
                    Colors.pinkAccent),
                const SizedBox(width: 8),
                _statBox('Playlists', _totalPlaylists, Icons.queue_music,
                    Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 20),

            // ==================== LIST ITEMS ====================
            _listItem(
              icon: Icons.settings,
              title: 'Setting',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                );
              },
            ),
            _listItem(
              icon: Icons.help_outline,
              title: 'Help & Feedback',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Help & Feedback feature जल्द आएगा'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            _listItem(
              icon: Icons.star_outline,
              title: 'Rate Us',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Play Store पर rate करें'),
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

            const SizedBox(height: 20),
            const Center(
              child: Text(
                '© 2026 Akhlakh Ansari\nAll Rights Reserved',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text('About VeoPlay',
            style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VeoPlay - Video & Music Player',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Version: 1.0.0',
                style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('Developer: Akhlakh Ansari',
                style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('Build: Release',
                style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 14),
            Text(
                'A lightweight, ad-free video and music player with dual video mode, equalizer, and background playback.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
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
