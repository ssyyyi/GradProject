import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wearly/remove_back.dart';
import 'package:provider/provider.dart';
import 'package:wearly/state_management/closet_provider.dart';

import 'firstscreen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();
  final RemoveBgService _removeBgService = RemoveBgService();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      final closetProvider = Provider.of<ClosetProvider>(context, listen: false);

      // 먼저 로컬 이미지 추가 (배경 제거 전)
      closetProvider.addImage(imageFile.path, "처리 중...");

      // 배경 제거 및 스타일 예측 요청
      Map<String, String>? result = await _removeBgService.removeBackground(imageFile, widget.userId);
      if (result != null) {
        // 업데이트된 이미지와 스타일 정보 반영
        closetProvider.updateLastImage(result['bg_removed_image_url']!, result['predicted_style']!);
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('앨범에서 선택하기'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('취소'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const FirstScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final closetProvider = Provider.of<ClosetProvider>(context);

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
      body: Stack(
        children: [
          if (_currentIndex == 0)
            GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: closetProvider.uploadedImages.length,
              itemBuilder: (context, index) {
                var image = closetProvider.uploadedImages[index];
                var style = closetProvider.predictedStyles[index];

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    image.startsWith('http')
                        ? Image.network(image, fit: BoxFit.cover)
                        : Image.file(File(image), fit: BoxFit.cover),
                    Positioned(
                      bottom: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.black54,
                        child: Text(
                          style,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => closetProvider.removeImage(index),
                        child: const Icon(Icons.remove_circle, color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Center(
              child: Text(
                _currentIndex == 1 ? '추천 기록 페이지' : '마이 페이지',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          if (_currentIndex == 0)
            Positioned(
              bottom: 70,
              left: MediaQuery.of(context).size.width / 2 - 35,
              child: FloatingActionButton(
                onPressed: _showImageSourceSheet,
                backgroundColor: Colors.blueGrey,
                child: const Icon(Icons.add_a_photo),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: '옷장'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '추천 기록'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이 페이지'),
        ],
      ),
    );
  }
}
