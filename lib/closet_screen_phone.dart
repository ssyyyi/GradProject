import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:wearly/remove_back.dart';
import 'package:wearly/state_management/closet_provider.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'package:dio/dio.dart';


final categoryMap = {
  "재킷": 0, "조거팬츠": 1, "짚업": 2, "스커트": 3, "가디건": 4,
  "점퍼": 5, "티셔츠": 6, "셔츠": 7, "팬츠": 8, "드레스": 9,
  "패딩": 10, "청바지": 11, "점프수트": 12, "니트웨어": 13, "베스트": 14,
  "코트": 15, "브라탑": 16, "블라우스": 17, "탑": 18, "후드티": 19, "래깅스": 20
};

final styleMap = {
  "traditional": 0, "manish": 1, "feminine": 2, "ethnic": 3,
  "contemporary": 4, "natural": 5, "genderless": 6, "sporty": 7,
  "subculture": 8, "casual": 9
};

class ClosetScreen extends StatefulWidget {
  final String userId;
  const ClosetScreen({super.key, required this.userId});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  final ImagePicker _picker = ImagePicker();
  final RemoveBgService _removeBgService = RemoveBgService();

  List<Map<String, dynamic>> clothingItems = [];
  bool isLoading = true;
  bool isClosetOpen = false;

  void _showEditDialog(int index, String currentStyle, String currentCategory, String imageUrl) {
    String? selectedStyle = currentStyle;
    String? selectedCategory = currentCategory;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("스타일/카테고리 수정"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStyle,
                items: styleMap.keys
                    .map((style) => DropdownMenuItem(
                  value: style,
                  child: Text(style),
                ))
                    .toList(),
                onChanged: (val) {
                  selectedStyle = val!;
                },
                decoration: const InputDecoration(labelText: "스타일"),
              ),
              DropdownButtonFormField<String>(
                //value: selectedCategory,
                value: selectedCategory == 'Unknown' ? null : selectedCategory,
                items: categoryMap.keys
                    .map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                ))
                    .toList(),
                onChanged: (val) {
                  selectedCategory = val!;
                },
                decoration: const InputDecoration(labelText: "카테고리"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("취소"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("저장"),
              onPressed: () async {

                final response = await Dio().put(
                  '$serverUrl/closet/modify',
                  data: {
                    "userId": widget.userId,
                    "imageUrl": imageUrl,
                    "category": selectedCategory,
                    "style": selectedStyle
                  },
                );

                if (response.statusCode == 200) {
                  print("수정 완료");
                  final closetProvider = Provider.of<ClosetProvider>(context, listen: false);
                  await closetProvider.loadFromServer();
                  Navigator.of(context).pop();
                  // 갱신
                } else {
                  print("수정 실패: ${response.data}");
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();



    Future.microtask(() async {
      final closetProvider = Provider.of<ClosetProvider>(context, listen: false);
      await closetProvider.switchUser(widget.userId);
      await closetProvider.loadFromServer();
      setState(() {});
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      final closetProvider = Provider.of<ClosetProvider>(context, listen: false);

      closetProvider.addImage(imageFile.path, "처리 중...");

      Map<String, String>? result = await _removeBgService.removeBackground(imageFile, widget.userId);
      if (result != null) {
        closetProvider.updateLastImage(
          result['bg_removed_image_url']!,
          result['predicted_style']!,
          result['predicted_category']!,
        );
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

  @override
  Widget build(BuildContext context) {
    final closetProvider = context.watch<ClosetProvider>();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await closetProvider.loadFromServer();
          },
          child: GridView.builder(
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
              var category = closetProvider.categories.length > index
                  ? closetProvider.categories[index]
                  : 'Unknown';

              return GestureDetector(
                onTap: () => _showEditDialog(index, style, category, image),
                child: Stack(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            Text(
                              category,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => closetProvider.removeImage(index),
                        child: const Icon(Icons.remove_circle, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

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
    );
  }
}
