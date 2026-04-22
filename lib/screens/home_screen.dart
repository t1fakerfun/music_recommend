import 'package:flutter/material.dart';
import '../services/import_service.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MyMusicLog')),
      body: Column(
        children: [
          // バックグラウンドインポート進捗バナー
          ValueListenableBuilder<ImportEvent?>(
            valueListenable: ImportService.instance.currentEvent,
            builder: (context, event, _) {
              if (event is! ImportProgress) return SizedBox.shrink();
              final progress = event.total > 0
                  ? event.processed / event.total
                  : null;
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            event.total > 0
                                ? 'バックグラウンド処理中: ${event.processed} / ${event.total} 件'
                                : 'データを解析中...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                  ],
                ),
              );
            },
          ),
          // メインコンテンツ
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '🎵 MyMusicLog',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'YouTube視聴履歴から音楽を記録・再発見',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add');
                    },
                    child: Text('JSONファイルを追加'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/result');
                    },
                    child: Text('履歴・おすすめを見る'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/tutorial');
                    },
                    child: Text('使い方を見る'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
