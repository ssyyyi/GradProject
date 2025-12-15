import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:wearly/config.dart';

// void main() {
//   runApp(MaterialApp(
//     debugShowCheckedModeBanner: false,
//     home: ModelLoad(),
//   ));
// }

class ModelLoad extends StatefulWidget {
  const ModelLoad({super.key});

  @override
  State<ModelLoad> createState() => _ModelLoadState();
}

class _ModelLoadState extends State<ModelLoad> {
  WebSocketChannel? channel;
  String? fittingImageUrl;
  bool isConnected = false;

  final wsUrl = '$wsBaseUrl';

  @override
  void initState() {
    super.initState();
    connectWebSocket();
  }

  void connectWebSocket() async {
    print('WebSocket 연결 시도...');
    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      isConnected = true;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      // if (userId != null) {
      //   print('WebSocket으로 user_id 전송 중: $userId');
      //   channel!.sink.add(jsonEncode({'user_id': userId}));
      // } else {
      //   print('SharedPreferences에 userId 없음');
      // }

      channel!.stream.listen(
            (message) {
          print('메시지 수신: $message');
          try {
            final data = jsonDecode(message);
            print('[WebSocket] JSON 파싱 성공: $data');
            final type = data['type'];
            final url = data['image_url'];
            if (url != null && url is String && url.startsWith('http')) {
              setState(() {
                fittingImageUrl = url;
              });
              print('피팅 이미지 적용 완료: $url');
            } else {
              print('image_url 없음 또는 잘못됨: $url');
            }

          } catch (e) {
            print('JSON 파싱 오류: $e');
          }
        },
        onError: (error) {
          print('WebSocket 오류 발생: $error');
          handleDisconnection();
        },
        onDone: () {
          print('WebSocket 연결 종료됨');
          handleDisconnection();
        },
      );


      setState(() {
        isConnected = true;
      });
    } catch (e) {
      print('WebSocket 연결 실패: $e');
      handleDisconnection();
    }
  }

  void handleDisconnection() {
    if (!mounted) return;
    isConnected = false;
    channel?.sink.close();
    showDisconnectedDialog();
    setState(() {}); // 상태 반영
  }

  void showDisconnectedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('연결 끊김'),
        content: const Text('서버와의 연결이 끊겼습니다.\n 다시 연결해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Fitting Viewer'),
          actions: [
            if (fittingImageUrl != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '3D 모델로 돌아가기',
                onPressed: () {
                  setState(() {
                    fittingImageUrl = null;
                  });
                },
              ),
            if (!isConnected)
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: '서버 재연결',
                onPressed: () {
                  connectWebSocket();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('서버 재연결 시도 중...')),
                  );
                },
              ),

            // 연결 상태 표시 아이콘
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Tooltip(
                message: isConnected ? '서버 연결됨' : '서버 연결 끊김',
                child: Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: fittingImageUrl == null
              ? SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.6,
            child: const ModelViewer(
              src: 'assets/models/standing_collada.glb',
              alt: '3D avatar model',
              autoRotate: true,
              disableZoom: true,
              backgroundColor: Color.fromARGB(255, 238, 238, 238),
            ),
          )
              : Image.network(
            fittingImageUrl!,
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 64),
          ),
        ),
      ),
    );
  }
}
