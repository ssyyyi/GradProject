import 'package:flutter/material.dart';
import 'package:wearly/firstscreen.dart';
import 'package:wearly/homescreen.dart';
import 'package:wearly/signup.dart';
import 'package:wearly/login.dart';
import 'package:provider/provider.dart';
import 'package:wearly/state_management/closet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 비동기 초기화
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('userId');
  print("앱 시작 시 SharedPreferences에서 불러온 userId: $userId");

  runApp(MyApp(initialUserId: userId));
}

class MyApp extends StatelessWidget {
  final String? initialUserId;

  const MyApp({super.key, this.initialUserId});

  @override
  Widget build(BuildContext context) {
    print("MyApp에서 초기 userId: $initialUserId");

    return MaterialApp(
      title: 'WEarly',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: initialUserId != null ? HomeScreen(userId: initialUserId!) : const FirstScreen(),
      routes: {
        '/home': (context) => HomeScreen(userId: initialUserId!),
        '/signup': (context) => const AuthView(),
        '/login': (context) => const LoginView(),
      },
    );
  }
}
