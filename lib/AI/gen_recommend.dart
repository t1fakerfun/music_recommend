import 'dart:convert'; // JSON解析用
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/utils.dart';
import '../db/watch_history.dart';
import '../db/recommendation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

Future<Recommendation> genRecommendBysongTitle(
  WatchHistory watchHistory,
) async {
  try {
    // .envファイルを読み込み
    await dotenv.load();

    final apiKey = dotenv.env['API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      ('エラー: API_KEYが.envファイルに設定されていません');
      throw Exception('API_KEY is not set in .env file');
    }

    ('API_KEY読み込み成功: ${apiKey.substring(0, 10)}...');

    final userId = await getOrCreateUserId();
    final title = watchHistory.title;
    final totalViews = watchHistory.totalViews;
    final evaluation = watchHistory.evaluation;
    final lastWatchedInMonth = watchHistory.lastWatchedInMonth;

    // 最新の視聴日から月年を計算
    final monthYear = lastWatchedInMonth != null
        ? WatchHistory.getMonthYear(lastWatchedInMonth)
        : WatchHistory.getMonthYear(DateTime.now());

    ('AI推薦生成開始 - 曲: $title, 評価: $evaluation, 総視聴回数: $totalViews');

    final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
    final content = [
      Content.text('''
あなたは音楽レコメンドエンジンです。以下の情報に基づいて、類似したおすすめの曲を1曲提案してください。

入力情報:
- 曲名: $title
- 総視聴回数: $totalViews回
- 評価: $evaluation/5

以下のJSON形式で出力してください:
{
  "title": "おすすめの曲タイトル",
  "artist": "アーティスト名",
  "description": "この曲をおすすめする理由（100文字以内）"
}

注意事項:
- 実在する楽曲を推奨してください
- アーティスト名は正確に記載してください
- 説明は簡潔で魅力的にしてください
- JSON形式を厳密に守ってください
- URLは含めないでください（自動生成します）
    '''),
    ];

    try {
      final response = await model.generateContent(content);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception('AIからのレスポンスが空です');
      }

      ('AI推薦生成成功: ${responseText.substring(0, 50)}...');
      (responseText);
      ('=== AI完全応答 ===');

      // AIレスポンスからRecommendationオブジェクトを作成
      return _parseAIResponse(
        responseText,
        userId,
        watchHistory.id ?? 0,
        monthYear,
      );
    } catch (e) {
      // エラー時はデフォルトのRecommendationを返す
      ('AI推薦生成エラー: $e');
      return _createDefaultRecommendation(userId, watchHistory);
    }
  } catch (e) {
    // .env読み込みエラーなど、初期化エラーの場合
    ('推薦システム初期化エラー: $e');
    final userId = await getOrCreateUserId();
    return _createDefaultRecommendation(userId, watchHistory);
  }
}

// YouTube Music検索URLを生成する関数
String _generateYouTubeMusicSearchUrl(String title, String artist) {
  // 曲名とアーティスト名を組み合わせて検索クエリを作成
  final query = '$artist $title';

  // 特殊文字や空白を適切にエンコード
  final encodedQuery = Uri.encodeQueryComponent(query);

  ('検索クエリ: $query');
  ('エンコード後: $encodedQuery');

  // YouTube Music検索URL
  return 'https://music.youtube.com/search?q=$encodedQuery';
}

// AIレスポンスを解析してRecommendationオブジェクトを作成
Recommendation _parseAIResponse(
  String responseText,
  int userId,
  int parentId,
  String monthYear,
) {
  try {
    // JSON部分を抽出（マークダウン形式の場合もあるため）
    final jsonStart = responseText.indexOf('{');
    final jsonEnd = responseText.lastIndexOf('}') + 1;

    if (jsonStart == -1 || jsonEnd == 0) {
      throw Exception('JSON形式が見つかりません');
    }

    final jsonString = responseText.substring(jsonStart, jsonEnd);
    ('抽出されたJSON: $jsonString');

    final Map<String, dynamic> jsonData = json.decode(jsonString);

    final title = jsonData['title'] ?? 'おすすめの曲';
    final artist = jsonData['artist'] ?? '不明なアーティスト';

    // 検索URLを生成
    final searchUrl = _generateYouTubeMusicSearchUrl(title, artist);

    ('生成された検索URL: $searchUrl');

    return Recommendation(
      userId: userId,
      parentId: parentId,
      title: title,
      artist: artist,
      description: jsonData['description'] ?? 'AIが推奨する楽曲です',
      url: searchUrl,
      monthYear: monthYear,
      watchedAt: DateTime.now(),
    );
  } catch (e) {
    ('JSON解析エラー: $e');
    throw Exception('AIレスポンスの解析に失敗しました: $e');
  }
}

// エラー時のデフォルトRecommendation
Recommendation _createDefaultRecommendation(
  int userId,
  WatchHistory watchHistory,
) {
  final lastWatchedInMonth = watchHistory.lastWatchedInMonth;
  final monthYear = lastWatchedInMonth != null
      ? WatchHistory.getMonthYear(lastWatchedInMonth)
      : WatchHistory.getMonthYear(DateTime.now());

  return Recommendation(
    userId: userId,
    parentId: watchHistory.id ?? 0,
    title: '${watchHistory.title} に似た楽曲',
    artist: '様々なアーティスト',
    description: 'あなたの音楽の好みに基づいたおすすめです',
    url: 'https://music.youtube.com/',
    monthYear: monthYear,
    watchedAt: DateTime.now(),
  );
}
