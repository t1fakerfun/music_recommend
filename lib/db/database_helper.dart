import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("music.db");
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    String dbpath = await getDatabasesPath();
    String path = join(dbpath, fileName);
    return await openDatabase(
      path,
      version: 4, // バージョンを4に更新
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recommendations (
        userId INTEGER,
        id INTEGER PRIMARY KEY,
        parentId INTEGER,
        title TEXT,
        artist TEXT,
        description TEXT,
        url TEXT,
        watchedAt TEXT,
        monthYear TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE users (
        userId INTEGER,
        id INTEGER PRIMARY KEY,
        name TEXT,
        email TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        title TEXT,
        totalViews INTEGER DEFAULT 0,
        evaluation INTEGER,
        url TEXT,
        channel TEXT,
        thumbnail BLOB,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE jsons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        filename TEXT,
        filesize INTEGER,
        entriesCount INTEGER,
        addDate TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE monthly_views(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        historyId INTEGER,
        monthYear TEXT,
        viewCount INTEGER DEFAULT 0,
        lastWatchedAt TEXT,
        FOREIGN KEY (historyId) REFERENCES watch_history (id)
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // バージョン4への移行：monthly_viewsテーブルの追加とwatch_historyテーブルの更新
      try {
        // 既存のwatch_historyテーブルに不足しているカラムを追加
        await db.execute(
          'ALTER TABLE watch_history ADD COLUMN totalViews INTEGER DEFAULT 0',
        );
        await db.execute('ALTER TABLE watch_history ADD COLUMN createdAt TEXT');
        await db.execute('ALTER TABLE watch_history ADD COLUMN updatedAt TEXT');

        // monthly_viewsテーブルを作成
        await db.execute('''
          CREATE TABLE IF NOT EXISTS monthly_views(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER,
            historyId INTEGER,
            monthYear TEXT,
            viewCount INTEGER DEFAULT 0,
            lastWatchedAt TEXT,
            FOREIGN KEY (historyId) REFERENCES watch_history (id)
          )
        ''');

        print('データベースをバージョン4に更新しました');
      } catch (e) {
        print('データベース更新エラー: $e');
      }
    }
  }
}
