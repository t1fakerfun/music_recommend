import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../db/watch_history.dart';
import '../utils/utils.dart';

// ──────────────────────────────────────────────
// Isolate に渡すパラメータ（シリアライズ可能な型のみ）
// ──────────────────────────────────────────────
class _ParseParams {
  final String contents;
  final String? latestWatchedIso;
  final String? earliestWatchedIso;

  _ParseParams({
    required this.contents,
    this.latestWatchedIso,
    this.earliestWatchedIso,
  });
}

// ──────────────────────────────────────────────
// Isolate 内で実行する純粋な計算処理
// JSON文字列 → 挿入すべきエントリのリスト（Map形式）
// ──────────────────────────────────────────────
List<Map<String, dynamic>> _parseAndFilter(_ParseParams params) {
  final dynamic jsonData = jsonDecode(params.contents);
  if (jsonData is! List) return [];

  final latestWatched = params.latestWatchedIso != null
      ? DateTime.parse(params.latestWatchedIso!)
      : null;
  final earliestWatched = params.earliestWatchedIso != null
      ? DateTime.parse(params.earliestWatchedIso!)
      : null;

  final results = <Map<String, dynamic>>[];

  for (final item in jsonData) {
    if (item is! Map<String, dynamic>) continue;
    final header = (item['header'] ?? '').toString();
    final url = (item['titleUrl'] ?? '').toString();
    if (header != 'YouTube Music' && !url.contains('music.youtube.com')) {
      continue;
    }

    final timeStr = item['time']?.toString();
    final watchedAt = timeStr != null ? DateTime.tryParse(timeStr) : null;
    if (watchedAt == null) continue;

    // 範囲チェック（初回 or 新しい/古いデータのみ）
    if (latestWatched != null && earliestWatched != null) {
      if (!watchedAt.isAfter(latestWatched) &&
          !watchedAt.isBefore(earliestWatched)) {
        continue;
      }
    }

    // タイトル・チャンネルの文字化け修正
    String title = (item['title'] ?? '').toString().replaceAll('を視聴しました', '');
    title = _fixGarbledText(title);
    String channel = item['subtitles']?[0]?['name']?.toString() ?? '不明';
    channel = _fixGarbledText(channel);

    results.add({
      'title': title,
      'url': url,
      'channel': channel,
      'watchedAt': watchedAt.toIso8601String(),
    });
  }

  return results;
}

String _fixGarbledText(String text) {
  final patterns = [
    ['â€œ', '"'],
    ['â€', '"'],
    ['â€™', "'"],
    ['â€¦', '...'],
  ];
  String fixed = text;
  for (final p in patterns) {
    fixed = fixed.replaceAll(p[0], p[1]);
  }
  return fixed;
}

// ──────────────────────────────────────────────
// 進捗通知イベント
// ──────────────────────────────────────────────
sealed class ImportEvent {}

class ImportProgress extends ImportEvent {
  final int processed;
  final int total;
  ImportProgress(this.processed, this.total);
}

class ImportDone extends ImportEvent {
  final int total;
  ImportDone(this.total);
}

class ImportError extends ImportEvent {
  final String message;
  ImportError(this.message);
}

// ──────────────────────────────────────────────
// ImportService — シングルトン
// ──────────────────────────────────────────────
class ImportService {
  ImportService._();
  static final ImportService instance = ImportService._();

  // 現在の状態を外部から購読できる ValueNotifier
  final ValueNotifier<ImportEvent?> currentEvent = ValueNotifier(null);

  bool get isRunning => currentEvent.value is ImportProgress;

  // メインのエントリーポイント
  // awaitせず呼び出すことでバックグラウンド実行になる
  Future<void> runImport({
    required String contents,
    required DateTime? latestWatchedDate,
    required DateTime? earliestWatchedDate,
    required int userId,
  }) async {
    if (isRunning) return; // 多重起動防止

    try {
      // Step 1: Isolate でJSON解析（UIスレッドをブロックしない）
      currentEvent.value = ImportProgress(0, 0);

      final entries = await Isolate.run(
        () => _parseAndFilter(
          _ParseParams(
            contents: contents,
            latestWatchedIso: latestWatchedDate?.toIso8601String(),
            earliestWatchedIso: earliestWatchedDate?.toIso8601String(),
          ),
        ),
      );

      if (entries.isEmpty) {
        currentEvent.value = ImportDone(0);
        return;
      }

      // Step 2: DB挿入（メインIsolateで行う必要あり、進捗を通知）
      final db = await DatabaseHelper().database;
      final repo = WatchHistoryRepository(db);

      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        final watchedAt = DateTime.parse(e['watchedAt'] as String);
        final history = WatchHistory(
          userId: userId,
          title: e['title'] as String,
          totalViews: 1,
          evaluation: 0,
          url: e['url'] as String,
          channel: e['channel'] as String,
        );

        await repo.insertOrUpdateWithDate(history, watchedAt);

        // 10件ごとに進捗通知＋UIに制御を返す
        if (i % 10 == 0 || i == entries.length - 1) {
          currentEvent.value = ImportProgress(i + 1, entries.length);
          // ここで await することでイベントループに制御を戻す
          await Future.microtask(() {});
        }
      }

      currentEvent.value = ImportDone(entries.length);
    } catch (e) {
      currentEvent.value = ImportError(e.toString());
    }
  }

  void reset() {
    currentEvent.value = null;
  }
}
