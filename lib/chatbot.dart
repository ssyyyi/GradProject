import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> messages = [
    {"sender": "bot", "text": "안녕하세요. AI 큐레이터봇 입니다."},
    {"sender": "bot", "text": "원하는 서비스를 선택하거나 메시지를 입력해주세요."},
  ];

  final TextEditingController _controller = TextEditingController();

  void _sendMessage(String text) {
    if (text.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": text});
      messages.add({"sender": "bot", "text": "메시지를 분석 중입니다..."}); // 임시 메시지
    });

    // 챗봇 응답 요청
    _getBotResponse(text);
  }

  void _getBotResponse(String userInput) async {
    // 서버 API 호출 로직 (추후 구현)
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      messages.removeLast(); // "메시지를 분석 중입니다..." 제거
      messages.add({"sender": "bot", "text": "추천된 스타일을 분석 중입니다!"}); // 임시 응답
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chatbot"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                bool isUser = msg["sender"] == "user";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(msg["text"]!, style: TextStyle(color: isUser ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),

          // 추천 키워드 버튼
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              _buildOptionButton("제품 재추천"),
            ],
          ),

          // 입력창 + 전송 버튼
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "메시지를 입력하세요",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    _sendMessage(_controller.text);
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String text) {
    return ElevatedButton(
      onPressed: () => _sendMessage(text),
      child: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

