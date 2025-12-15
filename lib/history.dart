import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class FittingHistoryScreen extends StatefulWidget {
  const FittingHistoryScreen({super.key});

  @override
  State<FittingHistoryScreen> createState() => _FittingHistoryScreenState();
}

Future<String?> getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('userId');
}

class _FittingHistoryScreenState extends State<FittingHistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;

  Future<List<Map<String, dynamic>>> fetchFittingHistory(String userId) async {
    try {
      final response = await Dio().get(
        '$serverUrl/outfit/history',
        queryParameters: {
          'userId': userId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        print('히스토리 로드 실패: ${response.data['message']}');
        return [];
      }
    } catch (e) {
      print('히스토리 요청 오류: $e');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = await getUserId();
    if (userId == null) {
      print("SharedPreferences에서 userId를 찾을 수 없습니다.");
      setState(() {
        isLoading = false;
      });
      return;
    }

    final result = await fetchFittingHistory(userId);
    setState(() {
      history = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Fitting History')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
          ? const Center(child: Text('피팅 기록이 없습니다.'))
          : Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          itemCount: history.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.55, // 카드 비율
          ),
          itemBuilder: (context, index) {
            final item = history[index];
            final imageUrl = item['image_url'];
            final date = item['timestamp'].toString().split('T')[0];
            final user = item['user_id'];
            final situation = item['situation'] ?? 'Unknown';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("날짜: $date", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                    Text("상황: $situation", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

