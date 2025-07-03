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
                return ListTile(
                  title: Text(history.title),
                  subtitle: Text('視聴回数: ${history.views}'),
                  trailing: Text('評価: ${history.evaluation}'),
                );
              },
            ),
    );
  }
}
