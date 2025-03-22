import 'package:flutter/material.dart';
import 'package:wearly/3d_model.dart';
import 'package:wearly/chatbot.dart';
//import 'package:wearly/closet_content_screen.dart';
import 'package:wearly/closet_tab.dart';
import 'package:wearly/weather.dart';
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

class SmartClosetUI extends StatelessWidget {
  final String userId; // 사용자 ID 필드 추가

  const SmartClosetUI({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('스마트 옷장'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.checkroom_sharp), text: '옷장'),
              Tab(icon: Icon(Icons.style), text: '스타일 추천'),
              Tab(icon: Icon(Icons.chat), text: '챗봇'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ClosetContentScreen(
              //onBack: () => Navigator.pop(context),
              userId: userId,
            ), // 옷장 화면
            ModelLoad(), // 스타일 추천 화면
            //const ChatbotScreen(), // 챗봇 화면
          ],
        ),
      ),
    );
  }
}
