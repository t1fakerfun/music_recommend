import 'package:sqflite/sqflite.dart';

class Recommendation {
  final int userId;
  final int? id;
  final int parentId;
  final String title;
  final String artist; // アーティスト名を追加
  final String description;
  final String url;
  final DateTime? watchedAt;
  final String? monthYear;

  Recommendation({
    required this.userId,
    this.id,
    required this.parentId,
    required this.title,
    required this.artist,
    required this.description,
    required this.url,
    this.watchedAt,
    this.monthYear,
  });
}

class RecommendationRepository {
  final Database database;

  RecommendationRepository(this.database);
  // データベースに推奨を挿入する
  Future<void> insertRecommendation(Recommendation recommendation) async {
    await database.insert('recommendations', {
      'userId': recommendation.userId,
      'id': recommendation.id,
      'parentId': recommendation.parentId,
      'title': recommendation.title,
      'artist': recommendation.artist,
      'description': recommendation.description,
      'url': recommendation.url,
      'watchedAt': recommendation.watchedAt?.toIso8601String(),
      'monthYear': recommendation.monthYear,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // データベースから推奨を取得する
  Future<List<Recommendation>> getRecommendations(int userId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'recommendations',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) {
      return Recommendation(
        userId: maps[i]['userId'],
        id: maps[i]['id'],
        parentId: maps[i]['parentId'],
        title: maps[i]['title'],
        artist: maps[i]['artist'] ?? '不明なアーティスト',
        description: maps[i]['description'],
        url: maps[i]['url'],
        watchedAt: maps[i]['watchedAt'] != null
            ? DateTime.parse(maps[i]['watchedAt'])
            : null,
        monthYear: maps[i]['monthYear'],
      );
    });
  }

  Future<List<Recommendation>> getRecommendedByMonth(
    int userId,
    String monthYear,
  ) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'recommendations',
      where: 'userId = ? AND monthYear = ?',
      whereArgs: [userId, monthYear],
      orderBy: 'watchedAt DESC',
    );
    return List.generate(maps.length, (i) {
      return Recommendation(
        userId: maps[i]['userId'],
        id: maps[i]['id'],
        parentId: maps[i]['parentId'],
        title: maps[i]['title'],
        artist: maps[i]['artist'] ?? '不明なアーティスト',
        description: maps[i]['description'],
        url: maps[i]['url'],
        watchedAt: maps[i]['watchedAt'] != null
            ? DateTime.parse(maps[i]['watchedAt'])
            : null,
        monthYear: maps[i]['monthYear'],
      );
    });
  }

  Future<void> deleteRecommendation(int? id) async {
    await database.delete('recommendations', where: 'id = ?', whereArgs: [id]);
  }

  // 月別の推薦を全て削除
  Future<void> deleteRecommendationsByMonth(
    int userId,
    String monthYear,
  ) async {
    await database.delete(
      'recommendations',
      where: 'userId = ? AND monthYear = ?',
      whereArgs: [userId, monthYear],
    );
  }

  // 特定のparentIdの推薦を削除
  Future<void> deleteRecommendationsByParent(int parentId) async {
    await database.delete(
      'recommendations',
      where: 'parentId = ?',
      whereArgs: [parentId],
    );
  }
}
