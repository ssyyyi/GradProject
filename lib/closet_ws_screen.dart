import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wearly/config.dart';

class ClosetContentScreen extends StatefulWidget {
  const ClosetContentScreen({super.key});

  @override
  State<ClosetContentScreen> createState() => _ClosetContentScreenState();
}

class _ClosetContentScreenState extends State<ClosetContentScreen> {
  List<Map<String, dynamic>> clothingItems = [];
  bool isLoading = true;
  bool isClosetOpen = false;
  WebSocketChannel? channel;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    if (userId == null) {
      print("userId 없음");
      setState(() => isLoading = false);
      return;
    }

    try {
      final wsUrl = '$wsBaseUrl';
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      print('WebSocket 연결됨, user_id 전송: $userId');
      channel!.sink.add(jsonEncode({'type': "closet",'user_id': userId}));

      channel!.stream.listen(
            (message) {
          print('옷장 데이터 수신: $message');
          try {
            final decoded = jsonDecode(message);

            if (decoded['action'] == 'refresh') {
              print('🔄 새로고침 요청 수신');
              _requestClosetData();
              return;
            }

            if (decoded['image_urls'] != null && decoded['image_urls'] is List) {
              setState(() {
                clothingItems = List<String>.from(decoded['image_urls'])
                    .map((url) => {'image_url': url})
                    .toList();
                isLoading = false;
              });
            } else {
              print('서버 응답 오류 또는 데이터 없음');
            }
          } catch (e) {
            print('JSON 파싱 오류: $e');
          }
        },
        onError: (error) {
          print('WebSocket 오류: $error');
          setState(() => isLoading = false);
        },
        onDone: () {
          print('WebSocket 연결 종료');
        },
      );
    } catch (e) {
      print('WebSocket 연결 실패: $e');
      setState(() => isLoading = false);
    }
  }

  // 옷장 데이터 요청용 함수
  Future<void> _requestClosetData() async {
    if (userId != null && channel != null) {
      print('🔁 옷장 데이터 재요청');
      channel!.sink.add(jsonEncode({'type': 'closet', 'user_id': userId}));
    }
  }

  void toggleCloset() {
    setState(() {
      isClosetOpen = !isClosetOpen;
    });

    if (isClosetOpen) {
      _requestClosetData();
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      //appBar: AppBar(title: const Text("My Closet")),
      body: Center(
        child: isClosetOpen
            ? RefreshIndicator(
          onRefresh: _requestClosetData,
          child: clothingItems.isEmpty
              ? ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text("옷 리스트가 없습니다.")),
              ),
            ],
          )
              : GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: clothingItems.length,
            itemBuilder: (context, index) {
              final item = clothingItems[index];
              return Column(
                children: [
                  Expanded(
                    child: Image.network(
                      item['image_url'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              );
            },
          ),
        )
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
