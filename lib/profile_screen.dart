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
  int _totalSongs = 0;
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
    final songs = prefs.getStringList('cached_songs') ?? [];
    final favSongs = prefs.getStringList('favorite_songs') ?? [];
    final favVideos = prefs.getStringList('favorite_videos') ?? [];
    final playlists = prefs.getStringList('user_playlists') ?? [];

    if (!mounted) return;
    setState(() {
      _userName = name;
      _userCoins = coins;
      _totalVideos = videos.length;
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
        backgroundColor: AppTheme.card,
        title: Text("नाम बदलें",
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
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
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Get Coins',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
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
                final today =
                    DateTime.now().toIso8601String().substring(0, 10);
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
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 15)),
        trailing: Text(reward,
            style: TextStyle(
                color: AppTheme.primaryBlue,
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
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Redeem Gift',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
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
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$cost ',
                style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold)),
            Icon(Icons.monetization_on,
                color: AppTheme.primaryBlue, size: 16),
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
                    SnackBar(
                        content:
                            Text('🎉 $title unlock हो गया!')),
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
        backgroundColor: AppTheme.card,
        title: Text('⭐ VIP Benefits',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 7 Day Free Trial',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            Text('• No Ads',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            Text('• Unlimited HD Quality',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            Text('• Unlimited Downloads',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
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
            child: Text('Start Trial',
                style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
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
        backgroundColor: AppTheme.card,
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
                  Text('कोई history नहीं है',
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
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                  Icons.monetization_on,
                                  color: Color(0xffFFD700),
                                  size: 14),
                              const SizedBox(width: 4),
                              Text('$_userCoins coins',
                                  style: TextStyle(
                                      color:
                                          AppTheme.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const SettingsScreen()),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryBlue
                              .withOpacity(0.5),
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
              
              // ==================== COIN SECTION ====================
              Row(
                children: [
                  Expanded(
                    child: _coinBox(
                      icon: Icons.monetization_on,
                      label: 'My Coin',
                      badgeText: '$_userCoins',
                      badgeColor: Colors.transparent,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _coinBox(
                      icon: Icons.shopping_cart,
                      label: 'Get Coin',
                      badgeText: 'FREE',
                      badgeColor: AppTheme.primaryBlue,
                      onTap: _showGetCoinDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _coinBox(
                      icon: Icons.card_giftcard,
                      label: 'Redeem Gift',
                      badgeText: 'GIFT',
                      badgeColor: AppTheme.primaryPurple,
                      onTap: _showRedeemDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ==================== VIP BANNER ====================
              GestureDetector(
                onTap: _showVipDialog,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff1E3A8A),
                        Color(0xff6B4DFF)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.workspace_premium,
                                color: Color(0xff1E3A8A),
                                size: 14),
                            SizedBox(width: 3),
                            Text('VIP',
                                style: TextStyle(
                                    color: Color(0xff1E3A8A),
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('7 Day Free Trial',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.bold)),
                            SizedBox(height: 2),
                            Text(
                                'no ads • unlimited HD • unlimited download',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==================== PRIVACY / THEME / HISTORY ====================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleButton(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy',
                    onTap: _showPrivacyDialog,
                  ),
                  _circleButton(
                    icon: Icons.palette_outlined,
                    label: 'Theme',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const SettingsScreen()),
                      );
                    },
                  ),
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
                icon: Icons.help_outline,
                title: 'Help & Feedback',
                onTap: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Help & Feedback जल्द आएगा'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _listItem(
                icon: Icons.star_outline,
                title: 'Rate Us',
                onTap: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content:
                          Text('Play Store पर rate करें'),
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

  Widget _coinBox({
    required IconData icon,
    required String label,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final isBadge = badgeColor != Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.5),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isBadge
                    ? badgeColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badgeText,
                  style: TextStyle(
                      color: isBadge
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
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
            Text('Version: 1.0.0',
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
