//おすすめの曲を表示するスクリーン

//result_screenからどの月のおすすめの曲か選択されているのでそれに応じてdbからデータを取得する
//AIが視聴履歴から曲をおすすめする。

import 'package:flutter/material.dart';
import '../db/watch_history.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('おすすめの曲')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'おすすめの曲',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('ここにおすすめの曲の内容が表示されます。'),
          ],
        ),
      ),
    );
  }
}
