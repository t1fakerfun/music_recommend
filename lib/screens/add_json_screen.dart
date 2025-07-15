import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../db/database_helper.dart';
import '../utils/utils.dart';
import '../db/watch_history.dart';
import '../db/jsons.dart';
//jsonを読み込むスクリーン

//jsonをとってくる
//フィルタリングする
//データベースに挿入する
//headerがYoutube Musicなら無条件で入れる。

class MusicEntry {
  final String title;
  final String url;
  final String channel;
  final DateTime? watchedAt;

  MusicEntry({
    required this.title,
    required this.url,
    required this.channel,
    this.watchedAt,
  });
  factory MusicEntry.fromJson(Map<String, dynamic> json) {
    return MusicEntry(
      title: json['title'] as String,
      url: json['titleUrl'] as String,
      channel: json['subtitles']?[0]?['name'] as String? ?? '不明',
      watchedAt: DateTime.tryParse(json['time'] as String),
    );
  }
}

List<MusicEntry> extractMusicEntries(List<dynamic> jsonData) {
  return jsonData
      .where((entry) {
        final header = entry['header'] ?? '';
        final url = entry['titleUrl'] ?? '';
        return header == "YouTube Music" || url.contains("music.youtube.com");
      })
      .map((entry) {
        // タイトルの文字化け修正
        String title = (entry['title'] as String).replaceAll(" を視聴しました", "");
        title = _fixGarbledText(title);

        final url = entry['titleUrl'] ?? '';

        // チャンネル名の文字化け修正
        String channel = entry['subtitles']?[0]?['name'] ?? '不明';
        channel = _fixGarbledText(channel);

        final watchedAt = DateTime.parse(entry['time']);
        return MusicEntry(
          title: title,
          url: url,
          channel: channel,
          watchedAt: watchedAt,
        );
      })
      .toList();
}

// 文字化け修正用のヘルパー関数（簡易版）
String _fixGarbledText(String text) {
  // 基本的な文字化けパターンを修正
  String fixed = text;

  // よくある文字化けパターン
  final patterns = [
    ['â€œ', '"'],
    ['â€', '"'],
    ['â€™', "'"],
    ['â€¦', '...'],
  ];

  for (final pattern in patterns) {
    fixed = fixed.replaceAll(pattern[0], pattern[1]);
  }

  return fixed;
}

class AddJsonScreen extends StatefulWidget {
  AddJsonScreen();

  @override
  _AddJsonScreenState createState() => _AddJsonScreenState();
}

class _AddJsonScreenState extends State<AddJsonScreen> {
  bool _isLoading = false;
  bool _showTextInput = false;
  final TextEditingController _textController = TextEditingController();

  // 進捗表示用
  int _processedCount = 0;
  int _totalCount = 0;

  Future<void> addJsonFile(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // JSONファイルを選択（より汎用的な設定）
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'すべてのファイル',
        extensions: <String>['json', 'txt'],
        uniformTypeIdentifiers: <String>[
          'public.json',
          'public.plain-text',
          'public.text',
          'public.data',
        ],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (file != null) {
        // ファイル内容をバイト列として読み込み
        final bytes = await file.readAsBytes();
        String contents;

        try {
          // まずUTF-8として試行
          contents = utf8.decode(bytes);
        } catch (e) {
          try {
            // UTF-8で失敗した場合、latin1（ISO-8859-1）で読み込んでからUTF-8に変換
            contents = utf8.decode(latin1.encode(latin1.decode(bytes)));
          } catch (e2) {
            // それでも失敗した場合、エラーを無視してUTF-8で強制デコード
            contents = utf8.decode(bytes, allowMalformed: true);
          }
        }

        // BOM（Byte Order Mark）を除去
        if (contents.startsWith('\uFEFF')) {
          contents = contents.substring(1);
        }

        // ファイル情報をjsonsテーブルに保存
        await _saveJsonFileInfo(file, contents);
        await _processJsonData(contents);
      } else {
        // ファイル選択がキャンセルされた場合
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ファイル選択がキャンセルされました')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processJsonData(String contents) async {
    try {
      final userId = await getOrCreateUserId();
      final db = await DatabaseHelper().database;
      final watchHistoryRepository = WatchHistoryRepository(db);
      final latestWatchedDate = await watchHistoryRepository
          .getLatestWatchedDate(userId);
      final earliestWatchedDate = await watchHistoryRepository
          .getEarliestWatchedDate(userId);
      final jsonData = jsonDecode(contents);
      final newEntries = <MusicEntry>[];
      for (final item in jsonData) {
        if (item is Map<String, dynamic>) {
          final entry = MusicEntry.fromJson(item);

          // 🔥 null check を追加
          if (entry.watchedAt != null) {
            // データベースにデータがない場合（初回）は全て追加
            if (latestWatchedDate == null || earliestWatchedDate == null) {
              newEntries.add(entry);
            } else {
              // 最新日時より新しい OR 最古日時より古い場合に追加
              if (entry.watchedAt!.isAfter(latestWatchedDate) ||
                  entry.watchedAt!.isBefore(earliestWatchedDate)) {
                newEntries.add(entry);
              }
            }
          }
        }
      }
      if (jsonData is! List) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('無効なJSONファイルです')));
        return;
      }

      final entries = extractMusicEntries(newEntries);

      setState(() {
        _totalCount = entries.length;
        _processedCount = 0;
      });

      // 大量データの場合は警告を表示
      if (entries.length > 1000) {
        final shouldContinue = await _showLargeDataWarning(entries.length);
        if (!shouldContinue) return;
      }
      // バッチ処理でデータを処理
      await _processBatch(entries);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSON解析エラー: $e')));
    }
  }

  Future<bool> _showLargeDataWarning(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('大量データの処理'),
            content: Text('$count件のデータが見つかりました。\n処理に時間がかかる可能性があります。続行しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('続行'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _processBatch(List<MusicEntry> entries) async {
    const batchSize = 50; // 50件ずつ処理

    for (int i = 0; i < entries.length; i += batchSize) {
      final batch = entries.skip(i).take(batchSize).toList();

      // バッチ処理（現在はログ出力のみ、将来DB保存処理を追加）
      for (final entry in batch) {
        // 現在は進捗カウントのみ
        final db = await DatabaseHelper().database;
        final watchHistoryRepository = WatchHistoryRepository(db);
        final watchHistory = WatchHistory(
          userId: await getOrCreateUserId(),
          title: entry.title,
          totalViews: 1, // 初回視聴なので1
          evaluation: 0, // 評価は初期値0
          url: entry.url,
          channel: entry.channel,
          // 新しいデータモデルでは、watchedDatesは不要
        );

        print('処理中: ${entry.title} (サムネイルダウンロード含む)'); // デバッグ用

        // 実際の視聴日時を使用してデータを挿入
        final watchedDate = entry.watchedAt ?? DateTime.now();
        await watchHistoryRepository.insertOrUpdateWithDate(
          watchHistory,
          watchedDate,
        );
        _processedCount++;
      }

      // UI更新（進捗表示）
      setState(() {});

      // UIスレッドを解放（重要！）
      await Future.delayed(Duration(milliseconds: 10));
    }

    // 処理完了
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entries.length}件の音楽を検出し、サムネイルもダウンロードしました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _processTextInput() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSONテキストを入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _processJsonData(_textController.text.trim());
      _textController.clear();
      setState(() {
        _showTextInput = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveJsonFileInfo(XFile file, String contents) async {
    try {
      final db = await DatabaseHelper().database;
      final jsonsRepository = JsonsRepository(db);

      // ファイルサイズを取得
      final fileSize = await file.length();

      // JSONエントリ数を取得
      final jsonData = jsonDecode(contents);
      final entries = extractMusicEntries(jsonData);

      // jsonsテーブルに保存
      await jsonsRepository.insertJson(
        Jsons(
          userId: await getOrCreateUserId(),
          filename: file.name,
          filesize: fileSize,
          entriesCount: entries.length,
          addDate: DateTime.now(),
        ),
      );

      print(
        'JSONファイル情報を保存: ${file.name}, サイズ: $fileSize, エントリ数: ${entries.length}',
      );
    } catch (e) {
      print('JSONファイル情報の保存に失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JSONデータを追加'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_showTextInput) ...[
              Icon(
                Icons.upload_file,
                size: 64,
                color: _isLoading ? Colors.grey : Colors.blue,
              ),
              SizedBox(height: 20),
              Text(
                'Google TakeoutからJSONをダウンロードしアップロードしてください。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Container(
                width: 450,
                height: 350,
                child: Image.asset(
                  'assets/images/how_use.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 40),
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    if (_totalCount > 0)
                      Column(
                        children: [
                          Text('処理中: $_processedCount / $_totalCount'),
                          Text(
                            'サムネイルダウンロード中...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _totalCount > 0
                                ? _processedCount / _totalCount
                                : 0,
                          ),
                          SizedBox(height: 16),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Text('ファイルを処理中...'),
                          SizedBox(height: 4),
                          Text(
                            'サムネイルをダウンロードしています',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ],
                      ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('キャンセルして戻る'),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => addJsonFile(context),
                      icon: Icon(Icons.folder_open),
                      label: Text('ファイルを選択'),
                    ),
                    SizedBox(height: 16),
                    Text('または'),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showTextInput = true;
                        });
                      },
                      icon: Icon(Icons.paste),
                      label: Text('JSONテキストを貼り付け'),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('ホームに戻る'),
                    ),
                  ],
                ),
            ] else ...[
              // テキスト入力モード
              Text(
                'JSONテキストを下記に貼り付けてください',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'JSONデータをここに貼り付け...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('処理中...'),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _processTextInput,
                      child: Text('処理実行'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showTextInput = false;
                          _textController.clear();
                        });
                      },
                      child: Text('キャンセル'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
