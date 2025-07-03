import 'package:sqflite/sqflite.dart';

class Jsons {
  final int userId;
  final int? id;
  final String filename;
  final int filesize;
  final int entriesCount;
  final DateTime addDate;

  Jsons({
    required this.userId,
    this.id,
    required this.filename,
    required this.filesize,
    required this.entriesCount,
    required this.addDate,
  });
}

class JsonsRepository {
  final Database database;

  JsonsRepository(this.database);

  // データベースにJSONを挿入する
  Future<void> insertJson(Jsons json) async {
    await database.insert('jsons', {
      'userId': json.userId,
      // 'id'は除外してAUTOINCREMENTに任せる
      'filename': json.filename,
      'filesize': json.filesize,
      'entriesCount': json.entriesCount,
      'addDate': json.addDate.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // データベースからJSONを取得する
  Future<List<Jsons>> getJsons(int userId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'jsons',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'addDate DESC', // 新しい順でソート
    );

    return List.generate(maps.length, (i) {
      return Jsons(
        userId: maps[i]['userId'],
        id: maps[i]['id'],
        filename: maps[i]['filename'],
        filesize: maps[i]['filesize'],
        entriesCount: maps[i]['entriesCount'],
        addDate: DateTime.parse(maps[i]['addDate']),
      );
    });
  }
}
