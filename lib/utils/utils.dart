import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

Future<int> getOrCreateUserId() async {
  //　SharedPreferencesを使用してユーザーIDを取得
  final prefs = await SharedPreferences.getInstance();
  int? userId = prefs.getInt('userId');
  // ユーザーIDが存在しない場合は新しいIDを生成
  if (userId == null) {
    userId = Uuid().v4().hashCode; // Generate a unique user ID
    await prefs.setInt('userId', userId);

    //　初期データを挿入
  }
  return userId;
}
