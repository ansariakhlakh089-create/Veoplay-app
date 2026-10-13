part of 'main.dart';

// ==================== Settings Screen ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPlayNext = true;
  bool _resumePlayback = true;
  bool _showHiddenFiles = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoPlayNext = prefs.getBool('auto_play_next') ?? true;
      _resumePlayback = prefs.getBool('resume_playback') ?? true;
      _showHiddenFiles = prefs.getBool('show_hidden_files') ?? false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _clearAppData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A1D24),
        title: const Text("सारा डेटा हटाएँ?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
            "सारी settings, favorites, playlists और recent history हट जाएगी। गाने/वीडियो फोन में रहेंगे।",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final keysToKeep = <String>['video_loop_mode', 'video_speed'];
    final allKeys = prefs.getKeys().toList();
    for (final k in allKeys) {
      if (!keysToKeep.contains(k)) {
        await prefs.remove(k);
      }
    }
    // Cache फाइल हटाएं
    try {
      final cacheDir = Directory.systemTemp;
      final files = cacheDir.listSync();
      for (final f in files) {
        if (f is File && f.path.contains('thumb_')) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ सारा डेटा हटा दिया'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xff2D8CFF),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color iconColor = Colors.white70,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ PLAYBACK ============
            _sectionTitle('PLAYBACK'),

            // Auto-play next video
            _settingTile(
              icon: Icons.play_circle_outline,
              title: 'Auto-play Next',
              subtitle: 'वीडियो खत्म होते ही अगला चलाएं',
              trailing: Switch(
                value: _autoPlayNext,
                activeColor: const Color(0xff2D8CFF),
                onChanged: (v) {
                  setState(() => _autoPlayNext = v);
                  _saveBool('auto_play_next', v);
                },
              ),
            ),

            // Resume playback
            _settingTile(
              icon: Icons.restore,
              title: 'Resume Playback',
              subtitle: 'जहाँ छोड़ा था वहीं से चलाएं',
              trailing: Switch(
                value: _resumePlayback,
                activeColor: const Color(0xff2D8CFF),
                onChanged: (v) {
                  setState(() => _resumePlayback = v);
                  _saveBool('resume_playback', v);
                },
              ),
            ),

            // Default Video Speed
            _settingTile(
              icon: Icons.speed,
              title: 'Default Video Speed',
              subtitle: 'नए वीडियो पर लागू होगी',
              onTap: _showVideoSpeedDialog,
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white38),
            ),

            // Default Music Speed
            _settingTile(
              icon: Icons.slow_motion_video,
              title: 'Default Music Speed',
              subtitle: 'नए गाने पर लागू होगी',
              onTap: _showMusicSpeedDialog,
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white38),
            ),

            // ============ LIBRARY ============
            _sectionTitle('LIBRARY'),

            // Show Hidden Files
            _settingTile(
              icon: Icons.visibility_outlined,
              title: 'Show Hidden Files',
              subtitle: 'छुपी हुई फाइलें भी दिखाएं',
              trailing: Switch(
                value: _showHiddenFiles,
                activeColor: const Color(0xff2D8CFF),
                onChanged: (v) {
                  setState(() => _showHiddenFiles = v);
                  _saveBool('show_hidden_files', v);
                },
              ),
            ),

            // Rescan Media
            _settingTile(
              icon: Icons.refresh,
              title: 'Rescan Media',
              subtitle: 'वीडियो और गाने फिर से scan करें',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Media scan शुरू होगा जब app खुलेगा'),
                  ),
                );
              },
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white38),
            ),

            // ============ STORAGE ============
            _sectionTitle('STORAGE'),

            // Clear Cache
            _settingTile(
              icon: Icons.cleaning_services_outlined,
              title: 'Clear Thumbnail Cache',
              subtitle: 'थंबनेल की cache हटाएं',
              onTap: _clearThumbnailCache,
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white38),
            ),

            // Clear All Data
            _settingTile(
              icon: Icons.delete_forever_outlined,
              title: 'Clear All App Data',
              subtitle: 'Favorites, playlists, settings हटाएं',
              iconColor: Colors.redAccent,
              onTap: _clearAppData,
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white38),
            ),

            // ============ ABOUT ============
            _sectionTitle('ABOUT'),

            _settingTile(
              icon: Icons.info_outline,
              title: 'App Version',
              subtitle: '1.0.0 (Build 1)',
            ),

            _settingTile(
              icon: Icons.person_outline,
              title: 'Developer',
              subtitle: 'Akhlakh Ansari',
            ),

            _settingTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'हमारी privacy policy पढ़ें',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Privacy Policy जल्द add होगी'),
                  ),
                );
              },
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white38),
            ),

            const SizedBox(height: 30),
            const Center(
              child: Text(
                '© 2026 Akhlakh Ansari\nAll Rights Reserved',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _showVideoSpeedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble('default_video_speed') ?? 1.0;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xff1A1D24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Default Video Speed',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                  final selected = s == current;
                  return GestureDetector(
                    onTap: () async {
                      await prefs.setDouble('default_video_speed', s);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xff2D8CFF)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${s}x',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMusicSpeedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble('default_music_speed') ?? 1.0;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xff1A1D24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Default Music Speed',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                  final selected = s == current;
                  return GestureDetector(
                    onTap: () async {
                      await prefs.setDouble('default_music_speed', s);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xff2D8CFF)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${s}x',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearThumbnailCache() async {
    try {
      final cacheDir = Directory.systemTemp;
      final files = cacheDir.listSync();
      int count = 0;
      for (final f in files) {
        if (f is File && f.path.contains('thumb_')) {
          try {
            await f.delete();
            count++;
          } catch (_) {}
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $count थंबनेल हटा दिए'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache clear नहीं हो पाई')),
        );
      }
    }
  }
}
