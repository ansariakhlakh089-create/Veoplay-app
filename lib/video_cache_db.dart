import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// वीडियो लिस्ट का cache अब SQLite में रहता है (पहले SharedPreferences में था).
/// - हज़ारों वीडियो होने पर भी app तेज़ रहता है
/// - पुराना 'cached_videos' अपने आप इस database में आ जाता है (एक बार)
class VideoCacheDb {
  static Future<Database>? _opening;

  static Future<Database> _open() async {
    try {
      return await (_opening ??= _doOpen());
    } catch (e) {
      _opening = null;
      rethrow;
    }
  }

  static Future<Database> _doOpen() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      '$dir/veoplay_cache.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE videos ('
            'title TEXT, res TEXT, size TEXT, source TEXT, duration TEXT, '
            'url TEXT, folder TEXT, vid TEXT)');
      },
    );
    await _migrateLegacy(db);
    return db;
  }

  /// पुराने SharedPreferences cache को एक बार database में ले आओ
  static Future<void> _migrateLegacy(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getStringList('cached_videos');
      if (legacy == null) return;

      final existing = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM videos')) ??
          0;
      if (existing == 0 && legacy.isNotEmpty) {
        final maps = <Map<String, String>>[];
        for (final s in legacy) {
          final p = s.split('|||');
          if (p.length >= 6) {
            maps.add({
              'title': p[0],
              'res': p[1],
              'size': p[2],
              'source': p[3],
              'duration': p[4],
              'url': p[5],
              'folder': p.length > 6 ? p[6] : 'Unknown',
              'id': p.length > 7 ? p[7] : '',
            });
          }
        }
        if (maps.isNotEmpty) {
          await _writeAll(db, maps);
        }
      }
      // database में सब सही चला गया — अब पुरानी भारी list हटा दो
      await prefs.remove('cached_videos');
    } catch (e) {
      debugPrint('VideoCacheDb migrate error: $e');
    }
  }

  static Future<void> _writeAll(
      Database db, List<Map<String, String>> videos) async {
    await db.transaction((txn) async {
      await txn.delete('videos');
      final batch = txn.batch();
      for (final m in videos) {
        batch.insert('videos', {
          'title': m['title'] ?? '',
          'res': m['res'] ?? '',
          'size': m['size'] ?? '',
          'source': m['source'] ?? '',
          'duration': m['duration'] ?? '',
          'url': m['url'] ?? '',
          'folder': m['folder'] ?? 'Unknown',
          'vid': m['id'] ?? '',
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// सारे cached वीडियो (खाली हो तो [])
  static Future<List<Map<String, String>>> loadAll() async {
    try {
      final db = await _open();
      final rows = await db.query('videos', orderBy: 'rowid ASC');
      return rows
          .map((r) => <String, String>{
                'title': (r['title'] ?? '').toString(),
                'res': (r['res'] ?? '').toString(),
                'size': (r['size'] ?? '').toString(),
                'source': (r['source'] ?? '').toString(),
                'duration': (r['duration'] ?? '').toString(),
                'url': (r['url'] ?? '').toString(),
                'isLocal': 'true',
                'folder': (r['folder'] ?? 'Unknown').toString(),
                'id': (r['vid'] ?? '').toString(),
              })
          .toList();
    } catch (e) {
      debugPrint('VideoCacheDb.loadAll error: $e');
      return [];
    }
  }

  /// पूरी list बदल दो (scan / delete / rename के बाद)
  static Future<void> replaceAll(List<Map<String, String>> videos) async {
    try {
      final db = await _open();
      await _writeAll(db, videos);
    } catch (e) {
      debugPrint('VideoCacheDb.replaceAll error: $e');
    }
  }

  /// कुल cached वीडियो (Profile screen के लिए)
  static Future<int> count() async {
    try {
      final db = await _open();
      return Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM videos')) ??
          0;
    } catch (e) {
      debugPrint('VideoCacheDb.count error: $e');
      return 0;
    }
  }
}
