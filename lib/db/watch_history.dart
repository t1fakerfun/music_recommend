import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../db/recommendation.dart';
import '../AI/gen_recommend.dart';

class WatchHistory {
  final int userId;
  final int? id; // オプショナルに変更
  final String title;
  final int views;
  final int evaluation;
  final String url;
  final DateTime? watchedAt;
  final String monthYear; // "2024-01" の形式
  final String channel;

  WatchHistory({
    required this.userId,
    this.id, // requiredを削除
    required this.title,
    required this.views,
    required this.evaluation,
    required this.url,
    this.watchedAt,
    required this.monthYear,
    required this.channel,
  });

  // 日付から月年文字列を生成するヘルパーメソッド
  static String getMonthYear(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}

class WatchHistoryRepository {
  final Database database;

  WatchHistoryRepository(this.database);

  // データベースに視聴履歴を挿入する
  Future<void> insertOrUpdate(WatchHistory watchHistory) async {
    final existing = await database.query(
      'watch_history',
      where: 'title = ? AND userId = ? AND monthYear = ?',
      whereArgs: [
        watchHistory.title,
        watchHistory.userId,
        watchHistory.monthYear,
      ],
    );

    if (existing.isNotEmpty) {
      // 既存の視聴履歴がある場合は更新（viewsをインクリメント）
      final currentViews = existing[0]['views'] as int;
      await database.update(
        'watch_history',
        {
          'views': currentViews + 1, // viewsをインクリメント
          'evaluation': watchHistory.evaluation,
          'url': watchHistory.url,
          'watchedAt': DateTime.now().toIso8601String(), // 視聴時刻を現在時刻に更新
          'channel': watchHistory.channel,
        },
        where: 'title = ? AND userId = ? AND monthYear = ?',
        whereArgs: [
          watchHistory.title,
          watchHistory.userId,
          watchHistory.monthYear,
        ],
      );
      return;
    } else {
      await database.insert('watch_history', {
        'userId': watchHistory.userId,
        // 'id'は除外してAUTOINCREMENTに任せる
        'title': watchHistory.title,
        'views': watchHistory.views,
        'evaluation': watchHistory.evaluation,
        'url': watchHistory.url,
        'watchedAt': watchHistory.watchedAt?.toIso8601String(),
        'monthYear': watchHistory.monthYear,
        'channel': watchHistory.channel,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
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
        id: maps[i]['id'], // AUTOINCREMENTで生成されたID
        title: maps[i]['title'],
        views: maps[i]['views'],
        evaluation: maps[i]['evaluation'],
        url: maps[i]['url'],
        monthYear: maps[i]['monthYear'] ?? '',
        channel: maps[i]['channel'] ?? '不明',
        watchedAt: maps[i]['watchedAt'] != null
            ? DateTime.parse(maps[i]['watchedAt'])
            : null,
      );
    });
  }

  // 月毎の視聴履歴を取得する
  Future<List<WatchHistory>> getWatchHistoryByMonth(
    int userId,
    String monthYear,
  ) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'watch_history',
      where: 'userId = ? AND monthYear = ?',
      whereArgs: [userId, monthYear],
      orderBy: 'views DESC, evaluation DESC', // 視聴回数と評価順でソート
    );

    return List.generate(maps.length, (i) {
      return WatchHistory(
        userId: maps[i]['userId'],
        id: maps[i]['id'], // AUTOINCREMENTで生成されたID
        title: maps[i]['title'],
        views: maps[i]['views'],
        evaluation: maps[i]['evaluation'],
        url: maps[i]['url'],
        monthYear: maps[i]['monthYear'],
        channel: maps[i]['channel'] ?? '不明',
        watchedAt: maps[i]['watchedAt'] != null
            ? DateTime.parse(maps[i]['watchedAt'])
            : null,
      );
    });
  }

  // 利用可能な月年のリストを取得する
  Future<List<String>> getAvailableMonths(int userId) async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      'SELECT DISTINCT monthYear FROM watch_history WHERE userId = ? ORDER BY monthYear DESC',
      [userId],
    );

    return maps.map((map) => map['monthYear'] as String).toList();
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

  // 視聴履歴を更新する
  Future<void> updateWatchHistory(WatchHistory watchHistory) async {
    await database.update(
      'watch_history',
      {
        'title': watchHistory.title,
        'views': watchHistory.views,
        'evaluation': watchHistory.evaluation,
        'url': watchHistory.url,
        'watchedAt': watchHistory.watchedAt?.toIso8601String(),
        'monthYear': watchHistory.monthYear,
        'channel': watchHistory.channel,
      },
      where: 'id = ? AND userId = ?',
      whereArgs: [watchHistory.id, watchHistory.userId],
    );
  }

  Future<bool> generaterecommend(WatchHistory watchHistory) async {
    try {
      // gen_recommend関数を呼び出して、視聴履歴から推奨を生成
      final recommendation = await genRecommendBysongTitle(watchHistory);
      final recommendationRepository = RecommendationRepository(database);
      await recommendationRepository.insertRecommendation(recommendation);
      print('成功: 推奨を生成しました: ${recommendation.title}');
      return true;
    } catch (e) {
      print('Error generating recommendation: $e');
      return false;
    }
  }
}
