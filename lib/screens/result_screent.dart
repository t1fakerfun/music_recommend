//視聴履歴とおすすめの曲を月毎に表示するスクリーン

//dbから持ってきたデータをmapを使ってグループごとに分けてそのグループを表示する。
//視聴履歴グループが選ばれたときその月の視聴履歴を表示する。
//おすすめの曲グループが選ばれたときその月のおすすめの曲を表示する。

import 'package:flutter/material.dart';
import 'package:music_recommend_app/screens/recommend_screen.dart';
import 'package:music_recommend_app/screens/watch_history_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('履歴・おすすめ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WatchHistoryScreen()),
                );
              },
              child: Text('視聴履歴'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RecommendScreen()),
                );
              },
              child: Text('おすすめの曲'),
            ),
          ],
        ),
      ),
    );
  }
}
