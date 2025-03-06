import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ClosetContentScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String userId; // 사용자 ID 필드 추가

  const ClosetContentScreen({
    super.key,
    required this.onBack,
    required this.userId,
  });

  @override
  State<ClosetContentScreen> createState() => _ClosetContentScreenState();
}

class _ClosetContentScreenState extends State<ClosetContentScreen> {
  final WebSocketChannel _channel =
      WebSocketChannel.connect(Uri.parse('ws://http://172.20.40.38:3000')); // 서버 연결
  final List<String> _clothingImages = [];
  bool isClosetOpen = false;

  @override
  void initState() {
    super.initState();
    _listenForUpdates();
    _requestClosetData(); // 초기 옷장 데이터 요청
  }

  @override
  void dispose() {
    _channel.sink.close(status.normalClosure);
    super.dispose();
  }

  // WebSocket 연결로 실시간 데이터 수신
  void _listenForUpdates() {
    _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);

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

  // WebSocket을 통해 옷장 데이터를 요청
  void _requestClosetData() {
    final request = jsonEncode({
      "action": "fetch_clothes",
      "userId": widget.userId, // 사용자 ID 전송
    });

    _channel.sink.add(request);
  }

  void toggleCloset() {
    setState(() {
      isClosetOpen = !isClosetOpen;
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
      body: Center(
        child: isClosetOpen
            ? (_clothingImages.isEmpty
                ? const Text(
                    "옷 리스트가 없습니다.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
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
                        title: Text("옷 ${index + 1}"),
                      );
                    },
                  ))
            : GestureDetector(
                onTap: toggleCloset,
                child: Image.asset(
                  'assets/images/closet.png',
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }
}
