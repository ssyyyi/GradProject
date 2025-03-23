import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firstscreen.dart';
import 'closet_screen_phone.dart';
import 'package:wearly/chatbot.dart';
import 'package:provider/provider.dart';
import 'package:wearly/state_management/closet_provider.dart';

import 'outfit_ui.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId;

    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      String? savedUserId = prefs.getString('userId');

      if (savedUserId != null && savedUserId.isNotEmpty) {
        _currentUserId = savedUserId;
        //debugPrint("[HomeScreen] 최신 로그인된 계정: $_currentUserId");
      } else {
        //debugPrint("[HomeScreen] 저장된 userId 없음. 로그인 필요!");
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeUser();
      });
    });
  }

  Future<void> _initializeUser() async {
    final closetProvider = Provider.of<ClosetProvider>(context, listen: false);

    //debugPrint("[initializeUser] 계정 데이터 불러오기 시작 ($_currentUserId)");

    await closetProvider.switchUser(_currentUserId);
    Future.microtask(() => setState(() {}));

    //debugPrint("[initializeUser] 계정 데이터 불러오기 완료 ($_currentUserId)");
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');

    final closetProvider = Provider.of<ClosetProvider>(context, listen: false);

    //debugPrint("[logout] 로그아웃 실행. 기존 데이터 초기화 시작...");

    await closetProvider.clearCloset();

    setState(() {
      _currentUserId = "";
    });

    //debugPrint("[logout] 데이터 초기화 완료. 로그인 화면으로 이동.");

    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const FirstScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      ClosetScreen(userId: _currentUserId),
      WeatherAndOutfitScreen(),
      Center(child: Text('추천 기록 페이지', style: TextStyle(fontSize: 20))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('WEarly'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'cloth'),
          BottomNavigationBarItem(icon: Icon(Icons.accessibility_sharp), label: 'outfit'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'history'),
        ],
      ),
    );
  }
}
