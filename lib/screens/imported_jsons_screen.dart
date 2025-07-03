import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../db/jsons.dart';
import '../utils/utils.dart';

class ImportedJsonsScreen extends StatefulWidget {
  @override
  _ImportedJsonsScreenState createState() => _ImportedJsonsScreenState();
}

class _ImportedJsonsScreenState extends State<ImportedJsonsScreen> {
  List<Jsons> _jsonFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJsonFiles();
  }

  Future<void> _loadJsonFiles() async {
    try {
      final db = await DatabaseHelper().database;
      final jsonsRepository = JsonsRepository(db);
      final userId = await getOrCreateUserId();

      final jsonFiles = await jsonsRepository.getJsons(userId);

      setState(() {
        _jsonFiles = jsonFiles;
        _isLoading = false;
      });
    } catch (e) {
      print('JSONファイル一覧の読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('インポート済みJSONファイル'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _jsonFiles.isEmpty
          ? _buildEmptyState()
          : _buildJsonList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'まだJSONファイルがインポートされていません',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'JSONファイルをインポートして視聴履歴を管理しましょう',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonList() {
    return RefreshIndicator(
      onRefresh: _loadJsonFiles,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _jsonFiles.length,
        itemBuilder: (context, index) {
          final jsonFile = _jsonFiles[index];
          return _buildJsonCard(jsonFile);
        },
      ),
    );
  }

  Widget _buildJsonCard(Jsons jsonFile) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    jsonFile.filename,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              Icons.storage,
              'ファイルサイズ',
              _formatFileSize(jsonFile.filesize),
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.music_note,
              'エントリ数',
              '${jsonFile.entriesCount}件',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'インポート日時',
              _formatDate(jsonFile.addDate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
