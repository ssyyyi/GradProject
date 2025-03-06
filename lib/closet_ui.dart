import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  runApp(const SmartClosetApp());
}

class SmartClosetApp extends StatelessWidget {
  const SmartClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SmartClosetUI(userId: '',),
    );
  }
}

class SmartClosetUI extends StatefulWidget {
  final String userId;
  const SmartClosetUI({super.key, required this.userId});

  @override
  _SmartClosetUIState createState() => _SmartClosetUIState();
}

class _SmartClosetUIState extends State<SmartClosetUI>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool isClosetOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    // 유저 아이디를 확인하는 로그 추가
    print("로그인한 유저 ID: ${widget.userId}");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleCloset() {
    if (isClosetOpen) {
      Navigator.pop(context);
      setState(() {
        isClosetOpen = false;
      });
    } else {
      _controller.forward().then((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClosetContentScreen(
              onBack: () {
                Navigator.pop(context);
                setState(() {
                  isClosetOpen = false;
                  _controller.reverse();
                });
              }, userId: widget.userId,
            ),
          ),
        );
        setState(() {
          isClosetOpen = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: GestureDetector(
          onTap: toggleCloset,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Image.asset(
              'assets/images/closet.png',
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class ClosetContentScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String userId;

  const ClosetContentScreen(
      {super.key, required this.onBack, required this.userId,});

  @override
  State<ClosetContentScreen> createState() => _ClosetContentScreenState();
}

class _ClosetContentScreenState extends State<ClosetContentScreen> {
  final WebSocketChannel _channel =
      WebSocketChannel.connect(Uri.parse('ws://0f01-61-40-226-235.ngrok-free.app')); // 서버 연결
  final List<String> _clothingImages = [];

  @override
  void initState() {
    super.initState();
    _listenForUpdates();

    // 디버깅: userId 확인
    print("ClosetContentScreen에 전달된 유저 ID: ${widget.userId}");
  }

  @override
  void dispose() {
    _channel.sink.close(status.normalClosure);
    super.dispose();
  }

  void _listenForUpdates() {
    _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);

        // 이미지를 포함한 메시지 필터링
        if (data.containsKey('imageUrl')) {
          setState(() {
            _clothingImages.add(data['imageUrl']);
          });
        } else {
          print("알 수 없는 데이터 형식: $data");
        }
      } catch (e) {
        print("WebSocket 데이터 처리 오류: $e");
      }
    }, onError: (error) {
      print("WebSocket 에러: $error");
    }, onDone: () {
      print("WebSocket 연결 종료됨");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Closet"),
        backgroundColor: Colors.blueGrey,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: _clothingImages.isEmpty
          ? const Center(
              child: Text(
                "옷 리스트가 없습니다.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
              ),
            )
          : ListView.builder(
              itemCount: _clothingImages.length,
              itemBuilder: (context, index) {
                final imageUrl = _clothingImages[index];
                return ListTile(
                  leading: Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: const Text("새로운 옷"),
                );
              },
            ),
    );
  }
}
