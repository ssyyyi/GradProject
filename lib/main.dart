import 'package:flutter/material.dart';
import 'package:wearly/firstscreen.dart';
import 'package:wearly/homescreen.dart';
import 'package:wearly/signup.dart';
import 'package:wearly/login.dart';
import 'package:provider/provider.dart';
import 'package:wearly/state_management/closet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('userId');

  print("앱 시작 시 SharedPreferences에서 불러온 userId: $userId");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ClosetProvider()),
      ],
      child: MyApp(initialUserId: userId),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? initialUserId;

  const MyApp({super.key, this.initialUserId});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.initialUserId;
  }

  Future<void> _updateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? updatedUserId = prefs.getString('userId');

    if (mounted) {
      setState(() {
        _userId = updatedUserId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("MyApp에서 초기 userId: $_userId");

    return MaterialApp(
      title: 'WEarly',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: _userId != null ? HomeScreen(userId: _userId!) : const FirstScreen(),
      routes: {
        '/home': (context) {
          _updateUserId();
          return _userId != null ? HomeScreen(userId: _userId!) : const FirstScreen();
        },
        '/signup': (context) => const AuthView(),
        '/login': (context) => const LoginView(),
      },
    );
  }
}
