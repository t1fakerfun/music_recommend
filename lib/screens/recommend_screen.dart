//おすすめの曲を表示するスクリーン

//result_screenからどの月のおすすめの曲か選択されているのでそれに応じてdbからデータを取得する
//AIが視聴履歴から曲をおすすめする。

import 'package:flutter/material.dart';
import '../db/watch_history.dart';
import '../db/database_helper.dart';
import '../utils/utils.dart';
import '../db/recommendation.dart';
import 'package:url_launcher/url_launcher.dart';

class RecommendScreen extends StatefulWidget {
  final String monthYear;
  const RecommendScreen({required this.monthYear});

  @override
  _RecommendScreenState createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  late WatchHistoryRepository watchHistoryRepository;
  late RecommendationRepository recommendationRepository;
  List<Recommendation> recommendations = [];
  List<WatchHistory> watchHistories = [];
  bool isLoading = true;
  bool isGenerating = false;
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
      recommendationRepository = RecommendationRepository(db);

      // 月毎のおすすめと視聴履歴を取得
      if (userId != null) {
        recommendations = await recommendationRepository.getRecommendedByMonth(
          userId!,
          widget.monthYear,
        );
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

  // AIに新しい推薦を生成してもらう
  Future<void> _generateRecommendations() async {
    if (watchHistories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('この月の視聴履歴がありません')));
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      // 評価の高い曲から推薦を生成
      final highRatedHistories = watchHistories
          .where((history) => history.evaluation >= 4)
          .toList();

      if (highRatedHistories.isEmpty) {
        // 評価の高い曲がない場合は視聴回数の多い曲から選ぶ
        watchHistories.sort((a, b) => b.views.compareTo(a.views));
        highRatedHistories.addAll(watchHistories.take(3));
      }

      int generatedCount = 0;
      for (final history in highRatedHistories.take(3)) {
        try {
          final success = await watchHistoryRepository.generaterecommend(
            history,
          );
          if (success) {
            generatedCount++;
          }
        } catch (e) {
          print('推薦生成エラー: $e');
        }
      }

      if (generatedCount > 0) {
        // 新しい推薦を取得
        await _initializeData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$generatedCount件の推薦を生成しました！')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('推薦の生成に失敗しました')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  // 推薦を削除する関数を追加
  Future<void> _deleteRecommendation(Recommendation recommendation) async {
    // 確認ダイアログを表示
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('推薦を削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下の推薦を削除しますか？'),
            SizedBox(height: 8),
            Text(
              '♪ ${recommendation.title}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'by ${recommendation.artist}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // データベースから削除
        await recommendationRepository.deleteRecommendation(recommendation.id!);

        // リストを更新
        await _initializeData();

        // 成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${recommendation.title}」を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // URLを開く（詳細デバッグ版）
  Future<void> _launchURL(String url) async {
    try {
      print('=== URL起動デバッグ開始 ===');
      print('起動しようとするURL: $url');
      
      final Uri uri = Uri.parse(url);
      print('パース後のURI: $uri');
      print('URI scheme: ${uri.scheme}');
      print('URI host: ${uri.host}');
      print('URI query: ${uri.query}');
      
      // canLaunchUrlをチェック
      final canLaunch = await canLaunchUrl(uri);
      print('canLaunchUrl結果: $canLaunch');
    } catch (e) {
      print('❌ URL起動エラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      
      // ブラウザで開くことを提案
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('アプリでURLを開けませんでした。ブラウザでお試しください。'),
          action: SnackBarAction(
            label: 'コピー',
            onPressed: () {
              // クリップボードにURLをコピー（オプション）
              print('URLをクリップボードにコピー: $url');
            },
          ),
        ),
      );
    }
  }

  // 一括削除機能を追加
  Future<void> _clearAllRecommendations() async {
    if (recommendations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除する推薦がありません')));
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('全ての推薦を削除'),
        content: Text(
          '${widget.monthYear}の全ての推薦（${recommendations.length}件）を削除しますか？\n\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('全て削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      try {
        // 全ての推薦を削除
        for (final recommendation in recommendations) {
          if (recommendation.id != null) {
            await recommendationRepository.deleteRecommendation(
              recommendation.id!,
            );
          }
        }

        // リストを更新
        await _initializeData();

        // 成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('全ての推薦を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 複数の音楽サービスで開く機能を修正
  Future<void> _showMusicServiceOptions(Recommendation recommendation) async {
    final title = recommendation.title;
    final artist = recommendation.artist;
    
    // Uri.encodeQueryComponent を使用して正しくエンコード
    final query = Uri.encodeQueryComponent('$artist $title');
    
    print('検索対象: $artist $title');
    print('エンコード後: $query');

    final services = [
      {
        'name': 'YouTube Music',
        'url': 'https://music.youtube.com/search?q=$query',
        'icon': Icons.music_note,
        'color': Colors.red,
      },
      {
        'name': 'Spotify',
        'url': 'https://open.spotify.com/search/$query',
        'icon': Icons.audiotrack,
        'color': Colors.green,
      },
      {
        'name': 'Apple Music',
        'url': 'https://music.apple.com/search?term=$query',
        'icon': Icons.music_video,
        'color': Colors.black,
      },
      {
        'name': 'Google検索',
        'url': 'https://www.google.com/search?q=$query',
        'icon': Icons.search,
        'color': Colors.blue,
      },
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '「$title」を検索',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'by $artist',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            ...services.map(
              (service) => ListTile(
                leading: Icon(
                  service['icon'] as IconData,
                  color: service['color'] as Color,
                ),
                title: Text(service['name'] as String),
                onTap: () {
                  Navigator.pop(context);
                  _launchURL(service['url'] as String);
                },
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
      appBar: AppBar(
        title: Text('${widget.monthYear} のおすすめ'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeData,
            tooltip: '更新',
          ),
          if (recommendations.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear_all') {
                  _clearAllRecommendations();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      Text('全て削除'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 統計情報
                _buildStatistics(),
                // 推薦生成ボタン
                _buildGenerateButton(),
                // 推薦リスト
                Expanded(
                  child: recommendations.isEmpty
                      ? _buildEmptyState()
                      : _buildRecommendationList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('視聴履歴', '${watchHistories.length}曲'),
          _buildStatItem('推薦数', '${recommendations.length}曲'),
          _buildStatItem(
            '高評価',
            '${watchHistories.where((h) => h.evaluation >= 4).length}曲',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isGenerating ? null : _generateRecommendations,
        label: Text(isGenerating ? 'AI推薦生成中...' : 'AIに新しい推薦を生成してもらう'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'まだ推薦がありません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'AIに推薦を生成してもらいましょう！',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // 推薦リストのUI修正
  Widget _buildRecommendationList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final recommendation = recommendations[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              recommendation.title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  'by ${recommendation.artist}',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  recommendation.description,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.smart_toy, size: 16, color: Colors.purple),
                    SizedBox(width: 4),
                    Text(
                      'AI推薦',
                      style: TextStyle(color: Colors.purple, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'search') {
                  _showMusicServiceOptions(recommendation);
                } else if (value == 'delete') {
                  _deleteRecommendation(recommendation);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('音楽サービスで検索'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('削除'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showMusicServiceOptions(recommendation),
          ),
        );
      },
    );
  }
}
