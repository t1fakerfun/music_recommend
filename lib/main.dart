import 'package:flutter/material.dart';
import 'screens/result_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_json_screen.dart';
import 'screens/imported_jsons_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Recommendation App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/result': (context) => ResultScreen(),
        '/add': (context) => AddJsonScreen(),
        '/imported_jsons': (context) => ImportedJsonsScreen(),
      },
    );
  }
}
