import 'package:sqflite/sqflite.dart';

class MonthlyViews {
  final int? id;
  final int userId;
  final int historyId;
  final String monthYear;
  final int viewCount;
  final DateTime lastWatchedAt;

  MonthlyViews({
    this.id,
    required this.userId,
    required this.historyId,
    required this.monthYear,
    required this.viewCount,
    required this.lastWatchedAt,
  });
}

class MonthlyViewsRepository {
  final Database database;

  MonthlyViewsRepository(this.database);

  // 指定日時での月毎視聴回数を追加/更新
  Future<void> addViewWithDate(
    int userId,
    int historyId,
    String monthYear,
    DateTime watchedAt,
  ) async {
    final existing = await database.query(
      'monthly_views',
      where: 'userId = ? AND historyId = ? AND monthYear = ?',
      whereArgs: [userId, historyId, monthYear],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // 既存の月データがある場合は視聴回数を増加
      final currentCount = existing[0]['viewCount'] as int;
      final currentLastWatched = DateTime.parse(
        existing[0]['lastWatchedAt'] as String,
      );

      // より新しい視聴日時の場合のみ更新
      final newLastWatched = watchedAt.isAfter(currentLastWatched)
          ? watchedAt
          : currentLastWatched;

      await database.update(
        'monthly_views',
        {
          'viewCount': currentCount + 1,
          'lastWatchedAt': newLastWatched.toIso8601String(),
        },
        where: 'userId = ? AND historyId = ? AND monthYear = ?',
        whereArgs: [userId, historyId, monthYear],
      );

      print('月毎視聴回数更新: $monthYear - ${currentCount + 1}回');
    } else {
      // 新しい月データを作成
      await database.insert('monthly_views', {
        'userId': userId,
        'historyId': historyId,
        'monthYear': monthYear,
        'viewCount': 1,
        'lastWatchedAt': watchedAt.toIso8601String(),
      });

      print('月毎視聴回数新規作成: $monthYear - 1回');
    }
  }

  // 現在時刻での追加（既存メソッド）
  Future<void> addView(int userId, int historyId, String monthYear) async {
    await addViewWithDate(userId, historyId, monthYear, DateTime.now());
  }

  // 特定の楽曲の月毎視聴回数を取得
  Future<List<MonthlyViews>> getMonthlyViewsForHistory(int historyId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'monthly_views',
      where: 'historyId = ?',
      whereArgs: [historyId],
      orderBy: 'monthYear DESC',
    );

    return List.generate(maps.length, (i) {
      return MonthlyViews(
        id: maps[i]['id'],
        userId: maps[i]['userId'],
        historyId: maps[i]['historyId'],
        monthYear: maps[i]['monthYear'],
        viewCount: maps[i]['viewCount'],
        lastWatchedAt: DateTime.parse(maps[i]['lastWatchedAt']),
      );
    });
  }

  // 特定の月の視聴履歴を取得（視聴回数順）
  Future<List<Map<String, dynamic>>> getHistoriesByMonth(
    int userId,
    String monthYear,
  ) async {
    return await database.rawQuery(
      '''
      SELECT 
        wh.id,
        wh.title,
        wh.channel,
        wh.url,
        wh.evaluation,
        wh.totalViews,
        wh.thumbnail,
        mv.viewCount as monthlyViews,
        mv.lastWatchedAt as lastWatchedInMonth
      FROM watch_history wh
      INNER JOIN monthly_views mv ON wh.id = mv.historyId
      WHERE mv.userId = ? AND mv.monthYear = ?
      ORDER BY mv.viewCount DESC, mv.lastWatchedAt DESC
    ''',
      [userId, monthYear],
    );
  }

  // ユーザーの全ての月を取得
  Future<List<String>> getAvailableMonths(int userId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'monthly_views',
      columns: ['monthYear'],
      where: 'userId = ?',
      whereArgs: [userId],
      groupBy: 'monthYear',
      orderBy: 'monthYear DESC',
    );

    return maps.map((map) => map['monthYear'] as String).toList();
  }

  // 月毎の統計情報を取得
  Future<Map<String, dynamic>> getMonthlyStats(
    int userId,
    String monthYear,
  ) async {
    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT 
        COUNT(DISTINCT mv.historyId) as uniqueSongs,
        SUM(mv.viewCount) as totalViews,
        AVG(wh.evaluation) as avgRating,
        COUNT(CASE WHEN wh.evaluation >= 4 THEN 1 END) as highRatedSongs
      FROM monthly_views mv
      INNER JOIN watch_history wh ON mv.historyId = wh.id
      WHERE mv.userId = ? AND mv.monthYear = ?
    ''',
      [userId, monthYear],
    );

    if (result.isNotEmpty) {
      return result[0];
    }
    return {
      'uniqueSongs': 0,
      'totalViews': 0,
      'avgRating': 0.0,
      'highRatedSongs': 0,
    };
  }

  // 月毎の推薦生成に適した楽曲を取得（高評価・高視聴回数）
  Future<List<Map<String, dynamic>>> getTopSongsForRecommendation(
    int userId,
    String monthYear, {
    int limit = 5,
  }) async {
    return await database.rawQuery(
      '''
      SELECT 
        wh.*,
        mv.viewCount as monthlyViews,
        mv.lastWatchedAt as lastWatchedInMonth
      FROM watch_history wh
      INNER JOIN monthly_views mv ON wh.id = mv.historyId
      WHERE mv.userId = ? AND mv.monthYear = ?
      ORDER BY 
        (wh.evaluation * 0.6 + (mv.viewCount / (SELECT MAX(viewCount) FROM monthly_views WHERE userId = ? AND monthYear = ?) * 5) * 0.4) DESC,
        mv.viewCount DESC,
        wh.evaluation DESC
      LIMIT ?
    ''',
      [userId, monthYear, userId, monthYear, limit],
    );
  }
}
