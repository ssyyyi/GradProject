import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wearly/closet_ws_screen.dart';
import 'package:wearly/history.dart';
import 'package:wearly/tab_fitting.dart';
import 'package:wearly/Tab_login.dart';

void main() {
  runApp(const SmartClosetApp());
}

class SmartClosetApp extends StatelessWidget {
  const SmartClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginView(), // 로그인 화면에서 시작
    );
  }
}

class SmartClosetUI extends StatefulWidget {
  const SmartClosetUI({super.key});

  @override
  State<SmartClosetUI> createState() => _SmartClosetUIState();
}

class _SmartClosetUIState extends State<SmartClosetUI> {
  String? userId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userId');
    print('📦 SharedPreferences에서 불러온 userId: $storedUserId');

    setState(() {
      userId = storedUserId;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userId == null) {
      // userId가 없으면 다시 로그인 화면으로 이동
      return const LoginView();
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SmartCloset'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.checkroom_sharp), text: 'closet'),
              Tab(icon: Icon(Icons.accessibility_sharp), text: 'style'),
              Tab(icon: Icon(Icons.history), text: 'history'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ClosetContentScreen(),
            const ModelLoad(),
            const FittingHistoryScreen(),
          ],
        ),
      ),
    );
  }
}
