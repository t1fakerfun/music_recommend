import 'package:flutter/material.dart';
import '../utils/utils.dart';
import '../db/watch_history.dart';
import '../db/database_helper.dart';

class ResultScreen extends StatefulWidget {
  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late WatchHistoryRepository watchHistoryRepository;
  List<String> availableMonths = [];
  bool isLoading = true;
  int? userId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('ResultScreen: データ初期化開始');
    try {
      // ユーザーIDを取得
      userId = await getOrCreateUserId();
      print('ResultScreen: ユーザーID取得完了 - $userId');

      // データベースを初期化
      final db = await DatabaseHelper().database;
      watchHistoryRepository = WatchHistoryRepository(db);
      print('ResultScreen: データベース初期化完了');

      // 利用可能な月のリストを取得
      if (userId != null) {
        availableMonths = await watchHistoryRepository.getAvailableMonths(
          userId!,
        );
        print('ResultScreen: 利用可能な月の数 - ${availableMonths.length}');
        print('ResultScreen: 月リスト - $availableMonths');
      }
    } catch (e) {
      print('データ初期化エラー: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
      print('ResultScreen: データ初期化完了、画面更新');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('履歴・おすすめ')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : availableMonths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'まだ音楽データがありません',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('JSONファイルを追加してください'),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/add'),
                    child: Text('JSONファイルを追加'),
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('ホームに戻る'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '月別履歴',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableMonths.length,
                      itemBuilder: (context, index) {
                        final month = availableMonths[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.calendar_month),
                            title: Text('$month'),
                            subtitle: Text('この月の音楽履歴を確認'),
                            trailing: Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              print('ResultScreen: 月詳細タップ - $month');
                              // 月別詳細画面に遷移（後で実装）
                              _showMonthDetail(month);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('ホームに戻る'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showMonthDetail(String monthYear) {
    print('ResultScreen: 月詳細表示 - $monthYear');
    // 月別詳細を表示するダイアログやボトムシートを表示
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '$monthYear の音楽履歴',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('※詳細画面は後で実装予定'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('ResultScreen: 月詳細ダイアログ閉じる');
                Navigator.pop(context);
              },
              child: Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
