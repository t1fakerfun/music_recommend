import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialScreen extends StatefulWidget {
  @override
  _TutorialScreenState createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildPage(
                title: "MyMusicLogへようこそ",
                description: "あなたのYouTube視聴履歴から\n音楽を記録し、新しい音楽に出会うことができます。",
                icon: Icons.music_note,
              ),
              _buildPage(
                title: "データを読み込む",
                description:
                    "Googleデータエクスポートから\n視聴履歴(JSON)をダウンロードして\nアプリに追加しましょう。",
                imagePath: "assets/images/how_use.png",
              ),
              _buildPage(
                title: "音楽を評価",
                description: "月毎に分けられた音楽の中から音楽を評価して、AIにおすすめの音楽を教えましょう。",
                imagePath: "assets/images/Good.png",
              ),
              _buildPage(
                title: "AIおすすめ",
                description: "読み込んだ履歴をもとに、\nAIがあなたにぴったりの\nプレイリストを提案します。",
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => _onIntroEnd(context),
                  child: Text("スキップ", style: TextStyle(color: Colors.grey)),
                ),
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.0),
                      width: _currentPage == index ? 12.0 : 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    );
                  }),
                ),
                TextButton(
                  onPressed: () {
                    if (_currentPage == 3) {
                      _onIntroEnd(context);
                    } else {
                      _pageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                  child: Text(
                    _currentPage == 3 ? "始める" : "次へ",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String description,
    IconData? icon,
    String? imagePath,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          if (imagePath != null)
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 400),
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
          SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 60), // Space for bottom navigation
        ],
      ),
    );
  }
}
