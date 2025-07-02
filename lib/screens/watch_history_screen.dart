//視聴履歴を表示

//result_screenからどの月の視聴履歴か選択されているのでそれに応じてdbからデータを取得する

import 'package:flutter/material.dart';

class WatchHistoryScreen extends StatelessWidget {
  const WatchHistoryScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('視聴履歴')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '視聴履歴',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('ここに視聴履歴の内容が表示されます。'),
          ],
        ),
      ),
    );
  }
}
