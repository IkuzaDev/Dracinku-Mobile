import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OfflineDB {
  static const String dbName = 'dramawave_offline.db';
  static const int dbVersion = 1;
  static const String tableDownloads = 'downloads';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableDownloads (
            id TEXT PRIMARY KEY,
            seriesId TEXT,
            title TEXT,
            episodeIndex INTEGER,
            videoPath TEXT,
            subtitlePath TEXT,
            coverUrl TEXT,
            downloadDate TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertDownload(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(tableDownloads, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getDownloads() async {
    final db = await database;
    return await db.query(tableDownloads, orderBy: 'downloadDate DESC');
  }

  Future<void> deleteDownload(String id) async {
    final db = await database;
    await db.delete(tableDownloads, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getDownload(String seriesId, int episodeIndex) async {
    final db = await database;
    final res = await db.query(
      tableDownloads, 
      where: 'seriesId = ? AND episodeIndex = ?', 
      whereArgs: [seriesId, episodeIndex]
    );
    return res.isNotEmpty ? res.first : null;
  }
}
