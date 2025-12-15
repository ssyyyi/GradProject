import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class StyleSelectorScreen extends StatefulWidget {
  final String userId;

  const StyleSelectorScreen({
    super.key,
    required this.userId,
  });

  @override
  StyleSelectorScreenState createState() => StyleSelectorScreenState();
}

class StyleSelectorScreenState extends State<StyleSelectorScreen> {
  final List<Map<String, dynamic>> styles = [
    {'name': '미니멀', 'image': 'assets/images/minimal.png', 'selected': false},
    {'name': '스트릿', 'image': 'assets/images/street.png', 'selected': false},
    {'name': '캐주얼', 'image': 'assets/images/casual.png', 'selected': false},
    {'name': '모던', 'image': 'assets/images/modern.png', 'selected': false},
    {'name': '러블리', 'image': 'assets/images/lovely.png', 'selected': false},
    {'name': '빈티지', 'image': 'assets/images/vintage.png', 'selected': false},
  ];

  List<String> selectedStyles = [];

  void toggleStyle(int index) {
    setState(() {
      styles[index]['selected'] = !styles[index]['selected'];
      if (styles[index]['selected']) {
        selectedStyles.add(styles[index]['name']);
      } else {
        selectedStyles.remove(styles[index]['name']);
      }
    });
  }

  Future<void> sendSelectedStylesToServer(
      String userId, List<String> styles) async {
    const String apiUrl = "$serverUrl/auth/prefer";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "prefer": styles,
        }),
      );

      if (response.statusCode == 200) {
        print("스타일 데이터 전송 성공: ${response.body}");
      } else {
        print("스타일 데이터 전송 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("서버 요청 중 오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스타일 선택'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                "업로드한 옷의 스타일을 선택해주세요!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: styles.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => toggleStyle(index),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: styles[index]['selected']
                                    ? Colors.blue
                                    : Colors.grey,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: AssetImage(styles[index]['image']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          styles[index]['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStyles.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('스타일을 최소 하나 선택해주세요!')),
                  );
                  return;
                }

                print('선택된 스타일: $selectedStyles');

                Navigator.pop(context);

                await sendSelectedStylesToServer(widget.userId, selectedStyles);
              },
              child: const Text('선택 완료'),
            ),
          ],
        ),
      ),
    );
  }
}