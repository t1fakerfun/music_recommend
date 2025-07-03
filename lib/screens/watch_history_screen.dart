//視聴履歴を表示

//result_screenからどの月の視聴履歴か選択されているのでそれに応じてdbからデータを取得する

import 'package:flutter/material.dart';
import '../db/watch_history.dart';
import '../db/database_helper.dart';
import '../utils/utils.dart';

class WatchHistoryScreen extends StatefulWidget {
  final String monthYear;
  const WatchHistoryScreen({required this.monthYear});
  //　月別の視聴履歴を表示するスクリーン
  // dbから月毎に視聴履歴を取得する
  @override
  _WatchHistoryScreenState createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  late WatchHistoryRepository watchHistoryRepository;
  List<WatchHistory> watchHistories = [];
  bool isLoading = true;
  int? userId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // ユーザーIDを取得
      userId = await getOrCreateUserId();
      // データベースを初期化
      final db = await DatabaseHelper().database;
      watchHistoryRepository = WatchHistoryRepository(db);
      // 月毎の視聴履歴を取得
      if (userId != null) {
        watchHistories = await watchHistoryRepository.getWatchHistoryByMonth(
          userId!,
          widget.monthYear,
        );
      }
    } catch (e) {
      print('データ初期化エラー: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Future<void> _showRatingDialog(WatchHistory history) async {
    int selectedRating = history.evaluation;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('評価を変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                history.title,
                style: TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16),
              Text('評価を選択してください'),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedRating = starValue;
                      });
                    },
                    child: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              SizedBox(height: 8),
              Text('${selectedRating}つ星'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedRating),
              child: Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != history.evaluation) {
      await _updateRating(history, result);
    }
  }

  Future<void> _updateRating(WatchHistory history, int newRating) async {
    try {
      // 新しい評価でWatchHistoryオブジェクトを作成
      final updatedHistory = WatchHistory(
        userId: history.userId,
        id: history.id,
        title: history.title,
        views: history.views,
        evaluation: newRating,
        url: history.url,
        watchedAt: history.watchedAt,
        monthYear: history.monthYear,
        channel: history.channel,
      );

      // データベースを更新
      await watchHistoryRepository.updateWatchHistory(updatedHistory);

      // ローカルリストを更新
      setState(() {
        final index = watchHistories.indexWhere((h) => h.id == history.id);
        if (index != -1) {
          watchHistories[index] = updatedHistory;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('評価を${newRating}つ星に更新しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('評価更新エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('評価の更新に失敗しました'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.monthYear}月の視聴履歴')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : watchHistories.isEmpty
          ? Center(child: Text('この月の視聴履歴はありません。'))
          : ListView.builder(
              itemCount: watchHistories.length,
              itemBuilder: (context, index) {
                final history = watchHistories[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      history.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('チャンネル: ${history.channel}'),
                        Text('視聴回数: ${history.views}回'),
                        if (history.watchedAt != null)
                          Text('最終視聴: ${_formatDate(history.watchedAt!)}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStarRating(history.evaluation),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showRatingDialog(history),
                          child: Text(
                            '評価変更',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
