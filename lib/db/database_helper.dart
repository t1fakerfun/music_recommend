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
      version: 2,
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
        views INTEGER,
        evaluation INTEGER,
        url TEXT,
        watchedAt TEXT,
        monthYear TEXT,
        channel TEXT
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
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // artistカラムをrecommendationsテーブルに追加
      await db.execute('ALTER TABLE recommendations ADD COLUMN artist TEXT');
    }
  }
}
