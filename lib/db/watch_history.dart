import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../db/recommendation.dart';
import '../db/monthly_views.dart';
import '../AI/gen_recommend.dart';

class MonthlyViews {
  final int? id;
  final int userId;
  final int musicId;
  final String monthYear;
  final int views;

  MonthlyViews({
    this.id,
    required this.userId,
    required this.musicId,
    required this.monthYear,
    required this.views,
  });
}

class WatchHistory {
  final int userId;
  final int? id;
  final String title;
  final int totalViews;
  final int evaluation;
  final String url;
  final String channel;
  final Uint8List? thumbnail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // 月毎の情報（optional、UI表示用）
  final int? monthlyViews;
  final DateTime? lastWatchedInMonth;

  WatchHistory({
    required this.userId,
    this.id,
    required this.title,
    required this.totalViews,
    required this.evaluation,
    required this.url,
    required this.channel,
    this.thumbnail,
    this.createdAt,
    this.updatedAt,
    this.monthlyViews,
    this.lastWatchedInMonth,
  });

  // 現在日時から月年文字列を生成
  static String getMonthYear(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static String? extractYoutubeId(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.host.contains('youtube.com') ||
          uri.host.contains('music.youtube.com')) {
        return uri.queryParameters['v'];
      }
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments[0];
      }
      return null;
    } catch (e) {
      ('YouTube ID抽出エラー: $e');
      return null;
    }
  }

  static String? getThumbnailUrl(String? youtubeId) {
    if (youtubeId == null || youtubeId.isEmpty) return null;
    return 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';
  }

  // 後方互換性のための静的メソッド（古いコードで使用）
  static List<DateTime> parseWatchedDates(String? watchedDatesString) {
    if (watchedDatesString == null || watchedDatesString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> dateStrings = json.decode(watchedDatesString);
      return dateStrings
          .map((dateString) => DateTime.parse(dateString))
          .toList();
    } catch (e) {
      print('watchedDates解析エラー: $e');
      return [];
    }
  }

  // 後方互換性のためのgetter（古いコードで使用）
  String get watchedDatesJson {
    return json.encode([]);
  }

  // 後方互換性のためのgetter（古いコードで使用）
  List<DateTime> get watchedDates {
    return [];
  }
}

class WatchHistoryRepository {
  final Database database;
  late final MonthlyViewsRepository monthlyViewsRepository;

  WatchHistoryRepository(this.database) {
    monthlyViewsRepository = MonthlyViewsRepository(database);
  }

  // 指定した日時でデータを挿入/更新する（JSONインポート用）
  Future<void> insertOrUpdateWithDate(
    WatchHistory watchHistory,
    DateTime watchedAt,
  ) async {
    try {
      // 既存の楽曲をチェック（同じタイトル、ユーザー）
      final existing = await database.query(
        'watch_history',
        where: 'title = ? AND userId = ?',
        whereArgs: [watchHistory.title, watchHistory.userId],
        limit: 1,
      );

      final monthYear = WatchHistory.getMonthYear(watchedAt);

      if (existing.isNotEmpty) {
        // 既存の楽曲がある場合
        final existingRecord = existing[0];
        final musicId = existingRecord['id'] as int;
        final existingTotalViews = (existingRecord['totalViews'] as int?) ?? 0;

        //print('既存楽曲を更新: ${watchHistory.title} (${watchedAt.toString()})');

        // watch_historyテーブルの総視聴回数を更新
        await database.update(
          'watch_history',
          {
            'totalViews': existingTotalViews + 1,
            'evaluation': watchHistory.evaluation,
            'url': watchHistory.url,
            'channel': watchHistory.channel,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'title = ? AND userId = ?',
          whereArgs: [watchHistory.title, watchHistory.userId],
        );

        // monthly_viewsテーブルを更新（指定された日時を使用）
        await monthlyViewsRepository.addViewWithDate(
          watchHistory.userId,
          musicId,
          monthYear,
          watchedAt,
        );
      } else {
        // 新しい楽曲の場合のみサムネイルをダウンロード

        final thumbnailData = await _downloadThumbnail(watchHistory.url);

        // watch_historyテーブルに新しい楽曲を追加
        final musicId = await database.insert('watch_history', {
          'userId': watchHistory.userId,
          'title': watchHistory.title,
          'totalViews': 1,
          'evaluation': watchHistory.evaluation,
          'url': watchHistory.url,
          'channel': watchHistory.channel,
          'thumbnail': thumbnailData,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // monthly_viewsテーブルに月毎の視聴記録を追加（指定された日時を使用）
        await monthlyViewsRepository.addViewWithDate(
          watchHistory.userId,
          musicId,
          monthYear,
          watchedAt,
        );
      }
    } catch (e) {
      //print('❌ insertOrUpdateWithDate エラー: $e');
      throw e;
    }
  }

  // 効率的な重複チェックとサムネイル管理（新しいmonthly_viewsテーブル対応）
  Future<void> insertOrUpdate(WatchHistory watchHistory) async {
    try {
      // 既存の楽曲をチェック（同じタイトル、ユーザー）
      final existing = await database.query(
        'watch_history',
        where: 'title = ? AND userId = ?',
        whereArgs: [watchHistory.title, watchHistory.userId],
        limit: 1,
      );

      final watchDate = DateTime.now();
      final monthYear = WatchHistory.getMonthYear(watchDate);

      if (existing.isNotEmpty) {
        // 既存の楽曲がある場合
        final existingRecord = existing[0];
        final musicId = existingRecord['id'] as int;
        final existingTotalViews = (existingRecord['totalViews'] as int?) ?? 0;

        //print('既存楽曲を更新: ${watchHistory.title}');

        // watch_historyテーブルの総視聴回数を更新
        await database.update(
          'watch_history',
          {
            'totalViews': existingTotalViews + 1,
            'evaluation': watchHistory.evaluation,
            'url': watchHistory.url,
            'channel': watchHistory.channel,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'title = ? AND userId = ?',
          whereArgs: [watchHistory.title, watchHistory.userId],
        );

        // monthly_viewsテーブルを更新
        await monthlyViewsRepository.addViewWithDate(
          watchHistory.userId,
          musicId,
          monthYear,
          watchDate,
        );

        //print('✅ 視聴記録追加完了（サムネイル再利用）');
      } else {
        // 新しい楽曲の場合のみサムネイルをダウンロード
        //print('新しい楽曲を追加: ${watchHistory.title}');
        //print('サムネイルをダウンロード中...');

        final thumbnailData = await _downloadThumbnail(watchHistory.url);

        // watch_historyテーブルに新しい楽曲を追加
        final musicId = await database.insert('watch_history', {
          'userId': watchHistory.userId,
          'title': watchHistory.title,
          'totalViews': 1,
          'evaluation': watchHistory.evaluation,
          'url': watchHistory.url,
          'channel': watchHistory.channel,
          'thumbnail': thumbnailData,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // monthly_viewsテーブルに月毎の視聴記録を追加
        await monthlyViewsRepository.addViewWithDate(
          watchHistory.userId,
          musicId,
          monthYear,
          watchDate,
        );

        //print('✅ 新しい楽曲追加完了（サムネイル付き）');
      }
    } catch (e) {
      //print('❌ insertOrUpdate エラー: $e');
      throw e;
    }
  }

  // バッチ処理用の効率的な一括挿入（新しいmonthly_viewsテーブル対応）
  Future<void> insertOrUpdateBatch(List<WatchHistory> watchHistories) async {
    print('🚀 バッチ処理開始: ${watchHistories.length}件');

    int newCount = 0;
    int updatedCount = 0;

    for (int i = 0; i < watchHistories.length; i++) {
      final history = watchHistories[i];

      // プログレス表示
      // if ((i + 1) % 10 == 0 || i == watchHistories.length - 1) {
      //   // print(
      //   //   '処理中: ${i + 1}/${watchHistories.length} (新規: $newCount, 更新: $updatedCount)',
      //   // );
      // }

      try {
        // 単純にinsertOrUpdateを呼び出す
        await insertOrUpdate(history);

        // 新規か更新かの判定（簡易版）
        final existing = await database.query(
          'watch_history',
          where: 'title = ? AND userId = ?',
          whereArgs: [history.title, history.userId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          updatedCount++;
        } else {
          newCount++;
        }
      } catch (e) {
        print('バッチ処理エラー: ${history.title} - $e');
      }
    }

    print('✅ バッチ処理完了: 新規 $newCount件, 更新 $updatedCount件');
  }

  // サムネイル画像をダウンロードする（キャッシュ対応）
  Future<Uint8List?> _downloadThumbnail(String url) async {
    try {
      final youtubeId = WatchHistory.extractYoutubeId(url);
      final thumbnailUrl = WatchHistory.getThumbnailUrl(youtubeId);
      if (thumbnailUrl == null) return null;
      final response = await http
          .get(
            Uri.parse(thumbnailUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (compatible; MusicApp/1.0)'},
          )
          .timeout(Duration(seconds: 10)); // タイムアウト設定
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        ('❌ サムネイルダウンロード失敗: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      ('❌ サムネイルダウンロードエラー: $e');
      return null;
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
        userId: maps[i]['userId'] as int,
        id: maps[i]['id'] as int?,
        title: maps[i]['title'].toString(),
        totalViews: (maps[i]['totalViews'] as int?) ?? 0,
        evaluation: (maps[i]['evaluation'] as int?) ?? 0,
        url: maps[i]['url'].toString(),
        channel: maps[i]['channel']?.toString() ?? '不明',
        thumbnail: maps[i]['thumbnail'] as Uint8List?,
        createdAt: maps[i]['createdAt'] != null
            ? DateTime.parse(maps[i]['createdAt'].toString())
            : null,
        updatedAt: maps[i]['updatedAt'] != null
            ? DateTime.parse(maps[i]['updatedAt'].toString())
            : null,
      );
    });
  }

  // 月毎の視聴履歴を取得する（新しいmonthly_viewsテーブルを使用）
  Future<List<WatchHistory>> getWatchHistoryByMonth(
    int userId,
    String monthYear,
  ) async {
    // INNER JOINを使用して、対象月のデータのみをデータベースレベルで取得・ソートする
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      '''
      SELECT 
        wh.id,
        wh.userId,
        wh.title,
        wh.channel,
        wh.url,
        wh.evaluation,
        wh.totalViews,
        wh.thumbnail,
        wh.createdAt,
        wh.updatedAt,
        mv.viewCount as monthlyViews,
        mv.lastWatchedAt as lastWatchedInMonth
      FROM watch_history wh
      INNER JOIN monthly_views mv ON wh.id = mv.historyId
      WHERE mv.userId = ? AND mv.monthYear = ?
      ORDER BY mv.viewCount DESC, wh.evaluation DESC
    ''',
      [userId, monthYear],
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return WatchHistory(
        userId: map['userId'] as int,
        id: map['id'] as int,
        title: map['title'].toString(),
        totalViews: (map['totalViews'] as int?) ?? 0,
        evaluation: (map['evaluation'] as int?) ?? 0,
        url: map['url'].toString(),
        channel: map['channel']?.toString() ?? '不明',
        thumbnail: map['thumbnail'] as Uint8List?,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'].toString())
            : null,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'].toString())
            : null,
        monthlyViews: map['monthlyViews'] as int?,
        lastWatchedInMonth: map['lastWatchedInMonth'] != null
            ? DateTime.parse(map['lastWatchedInMonth'].toString())
            : null,
      );
    });
  }

  // 利用可能な月年のリストを取得する（新しいmonthly_viewsテーブルを使用）
  Future<List<String>> getAvailableMonths(int userId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'monthly_views',
      columns: ['monthYear'],
      where: 'userId = ?',
      whereArgs: [userId],
      groupBy: 'monthYear',
    );

    final monthList = maps.map((map) => map['monthYear'].toString()).toList();
    monthList.sort((a, b) => b.compareTo(a)); // 降順ソート
    return monthList;
  }

  Future<void> evaluationWatchHistory(
    int userId,
    int id,
    int evaluation,
  ) async {
    await database.update(
      'watch_history',
      {'evaluation': evaluation, 'updatedAt': DateTime.now().toIso8601String()},
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
        'totalViews': watchHistory.totalViews,
        'evaluation': watchHistory.evaluation,
        'url': watchHistory.url,
        'channel': watchHistory.channel,
        'updatedAt': DateTime.now().toIso8601String(),
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
      ('成功: 推奨を生成しました: ${recommendation.title}');
      return true;
    } catch (e) {
      ('Error generating recommendation: $e');
      return false;
    }
  }

  Future<DateTime?> getLatestWatchedDate(int userId) async {
    try {
      final result = await database.rawQuery(
        '''
        SELECT MAX(lastWatchedAt) as latestWatched
        FROM monthly_views
          WHERE userId = ?
        ''',
        [userId],
      );
      if (result.isNotEmpty && result[0]['latestWatched'] != null) {
        return DateTime.parse(result[0]['latestWatched'].toString());
      }
      return null;
    } catch (e) {
      ('Error getting latest watched date: $e');
      return null;
    }
  }

  Future<DateTime?> getEarliestWatchedDate(int userId) async {
    try {
      final result = await database.rawQuery(
        '''
        SELECT MIN(lastWatchedAt) as earliestWatched
        FROM monthly_views
        WHERE userId = ?
      ''',
        [userId],
      );
      if (result.isNotEmpty && result[0]['earliestWatched'] != null) {
        return DateTime.parse(result[0]['earliestWatched'].toString());
      }
      return null;
    } catch (e) {
      ('Error getting earliest watched date: $e');
      return null;
    }
  }
}
