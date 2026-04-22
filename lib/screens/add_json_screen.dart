import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../db/database_helper.dart';
import '../db/watch_history.dart';
import '../db/jsons.dart';
import '../utils/utils.dart';
import '../services/import_service.dart';

//jsonを読み込むスクリーン

class AddJsonScreen extends StatefulWidget {
  AddJsonScreen();

  @override
  _AddJsonScreenState createState() => _AddJsonScreenState();
}

class _AddJsonScreenState extends State<AddJsonScreen> {
  bool _showTextInput = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ImportService の状態変化を購読して画面を再描画
    ImportService.instance.currentEvent.addListener(_onImportEvent);
  }

  @override
  void dispose() {
    ImportService.instance.currentEvent.removeListener(_onImportEvent);
    _textController.dispose();
    super.dispose();
  }

  void _onImportEvent() {
    final event = ImportService.instance.currentEvent.value;
    if (!mounted) return;

    if (event is ImportDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${event.total}件の音楽データを処理しました'),
          backgroundColor: Colors.green,
        ),
      );
      ImportService.instance.reset();
    } else if (event is ImportError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: ${event.message}'),
          backgroundColor: Colors.red,
        ),
      );
      ImportService.instance.reset();
    }

    // 再描画
    setState(() {});
  }

  // ─────────────────────────────
  // ファイル選択 → インポート開始
  // ─────────────────────────────
  Future<void> _pickAndStartImport(BuildContext context) async {
    if (ImportService.instance.isRunning) return;

    try {
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

      if (file == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ファイル選択がキャンセルされました')));
        return;
      }

      final bytes = await file.readAsBytes();
      String contents;
      try {
        contents = utf8.decode(bytes);
      } catch (_) {
        try {
          contents = utf8.decode(latin1.encode(latin1.decode(bytes)));
        } catch (_) {
          contents = utf8.decode(bytes, allowMalformed: true);
        }
      }
      if (contents.startsWith('\uFEFF')) contents = contents.substring(1);

      // ファイル情報をDBに保存
      await _saveJsonFileInfo(file, contents);

      // 大量データ警告
      final jsonData = jsonDecode(contents);
      int musicCount = 0;
      if (jsonData is List) {
        musicCount = jsonData.where((item) {
          if (item is! Map<String, dynamic>) return false;
          final header = (item['header'] ?? '').toString();
          final url = (item['titleUrl'] ?? '').toString();
          return header == 'YouTube Music' || url.contains('music.youtube.com');
        }).length;
      }

      if (musicCount > 1000) {
        final ok = await _showLargeDataWarning(musicCount);
        if (!ok) return;
      }

      // 日付範囲を取得
      final userId = await getOrCreateUserId();
      final db = await DatabaseHelper().database;
      final repo = WatchHistoryRepository(db);
      final latest = await repo.getLatestWatchedDate(userId);
      final earliest = await repo.getEarliestWatchedDate(userId);

      // バックグラウンドでインポート開始（unawaited）
      // ignore: unawaited_futures
      ImportService.instance.runImport(
        contents: contents,
        latestWatchedDate: latest,
        earliestWatchedDate: earliest,
        userId: userId,
      );

      // ← インポートが始まったらホームに戻れるようにする
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('バックグラウンドでデータを処理しています。他の画面を操作できます。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
    }
  }

  Future<bool> _showLargeDataWarning(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('大量データの処理'),
            content: Text('$count件のデータが見つかりました。\nバックグラウンドで処理されます。続行しますか？'),
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

  void _processTextInput() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSONテキストを入力してください')));
      return;
    }
    if (ImportService.instance.isRunning) return;

    final contents = _textController.text.trim();
    _textController.clear();
    setState(() => _showTextInput = false);

    final userId = await getOrCreateUserId();
    final db = await DatabaseHelper().database;
    final repo = WatchHistoryRepository(db);
    final latest = await repo.getLatestWatchedDate(userId);
    final earliest = await repo.getEarliestWatchedDate(userId);

    // ignore: unawaited_futures
    ImportService.instance.runImport(
      contents: contents,
      latestWatchedDate: latest,
      earliestWatchedDate: earliest,
      userId: userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('バックグラウンドでデータを処理しています。'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveJsonFileInfo(XFile file, String contents) async {
    try {
      final db = await DatabaseHelper().database;
      final jsonsRepository = JsonsRepository(db);
      final fileSize = await file.length();

      final jsonData = jsonDecode(contents);
      int musicEntriesCount = 0;
      if (jsonData is List) {
        musicEntriesCount = jsonData.where((item) {
          if (item is! Map<String, dynamic>) return false;
          final header = (item['header'] ?? '').toString();
          final url = (item['titleUrl'] ?? '').toString();
          return header == 'YouTube Music' || url.contains('music.youtube.com');
        }).length;
      }

      await jsonsRepository.insertJson(
        Jsons(
          userId: await getOrCreateUserId(),
          filename: file.name,
          filesize: fileSize,
          entriesCount: musicEntriesCount,
          addDate: DateTime.now(),
        ),
      );
    } catch (e) {
      print('JSONファイル情報の保存に失敗: $e');
    }
  }

  // ─────────────────────────────
  // 進捗ウィジェット（バナー表示用）
  // ─────────────────────────────
  Widget _buildProgressBanner() {
    return ValueListenableBuilder<ImportEvent?>(
      valueListenable: ImportService.instance.currentEvent,
      builder: (context, event, _) {
        if (event is! ImportProgress) return SizedBox.shrink();
        final progress = event.total > 0 ? event.processed / event.total : null;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.blue.shade50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.total > 0
                          ? 'バックグラウンド処理中: ${event.processed} / ${event.total} 件'
                          : 'データを解析中...',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ImportService.instance.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: Text('JSONデータを追加'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          // ← ローディング中でも戻れるようにした
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // バックグラウンド進捗バナー
          _buildProgressBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_showTextInput) ...[
                    Icon(
                      Icons.upload_file,
                      size: 64,
                      color: isRunning ? Colors.grey : Colors.blue,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Google TakeoutからJSONをダウンロードしアップロードしてください。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: isRunning
                          ? null
                          : () => _pickAndStartImport(context),
                      icon: Icon(Icons.folder_open),
                      label: Text(isRunning ? '処理中...' : 'ファイルを選択'),
                    ),
                    SizedBox(height: 16),
                    Text('または'),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isRunning
                          ? null
                          : () => setState(() => _showTextInput = true),
                      icon: Icon(Icons.paste),
                      label: Text('JSONテキストを貼り付け'),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('ホームに戻る'),
                    ),
                  ] else ...[
                    Text(
                      'JSONテキストを下記に貼り付けてください',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: isRunning ? null : _processTextInput,
                          child: Text('処理実行'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _showTextInput = false;
                            _textController.clear();
                          }),
                          child: Text('キャンセル'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
