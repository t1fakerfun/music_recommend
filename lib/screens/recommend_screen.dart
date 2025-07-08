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

  // URLを開く
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('URLを開けませんでした: $url')));
      }
    } catch (e) {
      print('URL起動エラー: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('URLの起動に失敗しました: $e')));
    }
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
        icon: isGenerating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.auto_awesome),
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

  Widget _buildRecommendationList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final recommendation = recommendations[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 3,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: Icon(Icons.music_note, color: Colors.purple),
                      radius: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recommendation.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            recommendation.artist,
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.open_in_new, color: Colors.purple),
                      onPressed: () => _launchURL(recommendation.url),
                      tooltip: 'YouTube Musicで開く',
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    recommendation.description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
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
                    Spacer(),
                    TextButton(
                      onPressed: () => _launchURL(recommendation.url),
                      child: Text('YouTube Musicで聴く'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.purple,
                        textStyle: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
