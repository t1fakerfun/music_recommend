import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/result_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_json_screen.dart';
import 'screens/imported_jsons_screen.dart';
import 'screens/tutorial_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;

  const MyApp({Key? key, required this.isFirstLaunch}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Recommendation App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: isFirstLaunch ? '/tutorial' : '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/tutorial': (context) => TutorialScreen(),
        '/result': (context) => ResultScreen(),
        '/add': (context) => AddJsonScreen(),
        '/imported_jsons': (context) => ImportedJsonsScreen(),
      },
    );
  }
}
