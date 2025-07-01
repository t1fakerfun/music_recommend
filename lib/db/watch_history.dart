import 'package:sqflite/sqflite.dart';

class WatchHistory {
  final int userId;
  final int id;
  final String title;
  final int views;
  final int evaluation;
  final String url;
  final DateTime? watchedAt;

  WatchHistory({
    required this.userId,
    required this.id,
    required this.title,
    required this.views,
    required this.evaluation,
    required this.url,
    this.watchedAt,
  });
}

class WatchHistoryRepository {
  final Database database;

  WatchHistoryRepository(this.database);

  // データベースに視聴履歴を挿入する
  Future<void> insertWatchHistory(WatchHistory watchHistory) async {
    await database.insert('watch_history', {
      'userId': watchHistory.userId,
      'id': watchHistory.id,
      'title': watchHistory.title,
      'views': watchHistory.views,
      'evaluation': watchHistory.evaluation,
      'url': watchHistory.url,
      'watchedAt': watchHistory.watchedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // データベースから視聴履歴を取得する
  Future<List<WatchHistory>> getWatchHistory(int userId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'watch_history',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return WatchHistory(
        userId: maps[i]['userId'],
        id: maps[i]['id'],
        title: maps[i]['title'],
        views: maps[i]['views'],
        evaluation: maps[i]['evaluation'],
        url: maps[i]['url'],
        watchedAt: maps[i]['watchedAt'] != null
            ? DateTime.parse(maps[i]['watchedAt'])
            : null,
      );
    });
  }

  Future<void> evaluationWatchHistory(
    int userId,
    int id,
    int evaluation,
  ) async {
    await database.update(
      'watch_history',
      {'evaluation': evaluation},
      where: 'userId = ? AND id = ?',
      whereArgs: [userId, id],
    );
  }
}
