import 'package:sqflite/sqflite.dart';

class Recommendation {
  final int userId;
  final int id;
  final int parentId;
  final String title;
  final String description;
  final String url;
  final DateTime? watchedAt;

  Recommendation({
    required this.userId,
    required this.id,
    required this.parentId,
    required this.title,
    required this.description,
    required this.url,
    this.watchedAt,
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
      'description': recommendation.description,
      'url': recommendation.url,
      'watchedAt': recommendation.watchedAt?.toIso8601String(),
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
        description: maps[i]['description'],
        url: maps[i]['url'],
        watchedAt: maps[i]['watchedAt'] != null
            ? DateTime.parse(maps[i]['watchedAt'])
            : null,
      );
    });
  }
}
