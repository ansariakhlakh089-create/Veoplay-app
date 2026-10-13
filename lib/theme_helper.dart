part of 'main.dart';

// ==================== THEME HELPER ====================
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

class AppTheme {
  static bool get isDark => isDarkMode.value;

  // Backgrounds
  static Color get bg =>
      isDark ? const Color(0xff0B0D12) : const Color(0xffF5F7FA);

  static Color get card =>
      isDark ? Colors.white10 : Colors.white;

  static Color get cardBorder =>
      isDark ? Colors.transparent : Colors.black12;

  // Text
  static Color get textPrimary =>
      isDark ? Colors.white : const Color(0xff1A1D24);

  static Color get textSecondary =>
      isDark ? Colors.white54 : const Color(0xff6B7280);

  static Color get textTertiary =>
      isDark ? Colors.white38 : const Color(0xff9CA3AF);

  // Accent stays same
  static const Color accent = Color(0xff2D8CFF);
  static const Color accentSecondary = Color(0xff6B4DFF);

  // Misc
  static Color get divider => isDark ? Colors.white12 : Colors.black12;
  static Color get iconColor => isDark ? Colors.white70 : Colors.black54;
  static Color get switchTrackInactive =>
      isDark ? const Color(0xff3A3D44) : const Color(0xffD1D5DB);

  // Save / Load
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('is_dark_mode') ?? true;
  }

  static Future<void> toggle(bool value) async {
    isDarkMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }
}
