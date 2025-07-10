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
          size: 14,
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
        totalViews: history.totalViews,
        evaluation: newRating,
        url: history.url,
        channel: history.channel,
        thumbnail: history.thumbnail,
        createdAt: history.createdAt,
        updatedAt: DateTime.now(),
        monthlyViews: history.monthlyViews,
        lastWatchedInMonth: history.lastWatchedInMonth,
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

  // サムネイルをフルサイズで表示する関数
  void _showFullSizeThumbnail(WatchHistory history) {
    if (history.thumbnail == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(history.thumbnail!, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      history.channel,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // サムネイル部分
                          GestureDetector(
                            onTap: () => _showFullSizeThumbnail(history),
                            child: Container(
                              width: 80,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade200,
                              ),
                              child: history.thumbnail != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        history.thumbnail!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              print('サムネイル表示エラー: $error');
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey.shade600,
                                                  size: 30,
                                                ),
                                              );
                                            },
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.music_note,
                                        color: Colors.grey.shade600,
                                        size: 30,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // 中央のコンテンツ部分
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  history.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'チャンネル: ${history.channel}',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '今月: ${history.monthlyViews ?? 0}回',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '（総計: ${history.totalViews}回）',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    _buildStarRating(history.evaluation),
                                    SizedBox(width: 8),
                                    Text(
                                      '${history.evaluation}つ星',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (history.lastWatchedInMonth != null) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    '今月の最終視聴: ${_formatDate(history.lastWatchedInMonth!)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 右側のボタン部分
                          SizedBox(
                            width: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18),
                                  onPressed: () => _showRatingDialog(history),
                                  tooltip: '評価変更',
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                                Text(
                                  '評価変更',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 9,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
