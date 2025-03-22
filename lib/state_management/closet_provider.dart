import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wearly/config.dart';

class ClosetProvider extends ChangeNotifier {
  List<String> _uploadedImages = [];
  List<String> _predictedStyles = [];
  List<String> _categories = [];
  String _currentUserId = "";
  final Dio _dio = Dio();

  List<String> get uploadedImages => _uploadedImages;
  List<String> get predictedStyles => _predictedStyles;
  List<String> get categories => _categories;
  String get currentUserId => _currentUserId;

  //계정별 옷장 데이터 불러오기
  Future<void> loadCloset(String userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();

    _uploadedImages = prefs.getStringList('uploadedImages_$userId') ?? [];
    _predictedStyles = prefs.getStringList('predictedStyles_$userId') ?? [];

    // debugPrint("[loadCloset] 계정 변경됨: $_currentUserId");
    // debugPrint("[loadCloset] 불러온 이미지 리스트: $_uploadedImages");
    // debugPrint("[loadCloset] 불러온 스타일 리스트: $_predictedStyles");

    notifyListeners();
  }

  Future<void> switchUser(String userId) async {
    _currentUserId = userId;
    _uploadedImages = [];
    _predictedStyles = [];
    notifyListeners();


    //debugPrint("[switchUser] 계정 전환 중: $_currentUserId");

    await Future.delayed(const Duration(milliseconds: 100));
    await loadCloset(userId);
  }

  Future<void> addImage(String imageUrl, String style) async {
    _uploadedImages.add(imageUrl);
    _predictedStyles.add(style);
    _categories.add('처리 중...');
    notifyListeners();
    await _saveImages();
  }

  Future<void> updateLastImage(String newImageUrl, String newStyle, String newCategory) async {
    if (_uploadedImages.isNotEmpty) {
      _uploadedImages[_uploadedImages.length - 1] = newImageUrl;
      _predictedStyles[_predictedStyles.length - 1] = newStyle;
      _categories[_categories.length - 1] = newCategory;
      notifyListeners();
      await _saveImages();

    }
  }
  Future<void> updateCategoryAndStyle(int index, String category, String style) async {
    if (index < _uploadedImages.length) {
      _categories[index] = category;
      _predictedStyles[index] = style;
      notifyListeners();
      await _saveImages();
    }
  }

  Future<void> removeImage(int index) async {
    if (index >= _uploadedImages.length || index >= _predictedStyles.length) return;

    final String imageUrl = _uploadedImages[index];

    try {
      final response = await _dio.delete(
        '$serverUrl/closet/delete',
        data: {
          'userId': currentUserId,
          'imageUrl': imageUrl,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        print("✅ 서버에서 이미지 삭제 성공");

        _uploadedImages.removeAt(index);
        _predictedStyles.removeAt(index);
        notifyListeners();
        await _saveImages();
      } else {
        print("⚠️ 서버에서 이미지 삭제 실패: ${response.data['message']}");
      }
    } catch (e) {
      print("❌ 서버 삭제 요청 중 오류 발생: $e");
    }
  }

  Future<void> loadFromServer() async {
    final String apiUrl = '$serverUrl/tablet/images?userId=$_currentUserId';

    try {
      final response = await Dio().get(apiUrl);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = List<Map<String, dynamic>>.from(response.data['data']);
        _uploadedImages = data.map((e) => e['image_url'].toString()).toList();
        _predictedStyles = data.map((e) => e['predicted_style']?.toString() ?? 'Unknown').toList();
        _categories = data.map((e) => e['category']?.toString() ?? 'Unknown').toList();
        notifyListeners();
        await _saveImages();
      }
    } catch (e) {
      print('서버에서 옷장 불러오기 실패: $e');
    }
  }



  Future<void> _saveImages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('uploadedImages_$_currentUserId', _uploadedImages);
    await prefs.setStringList('predictedStyles_$_currentUserId', _predictedStyles);
    await prefs.setStringList('categories_$_currentUserId', _categories);

    //debugPrint(" [saveImages] 계정 ($_currentUserId) 데이터 저장 완료");
  }

  Future<void> clearCloset() async {
    _uploadedImages = [];
    _predictedStyles = [];
    _categories = [];
    notifyListeners();

   // debugPrint(" [clearCloset] 메모리에서 옷장 데이터 초기화됨");
  }
}
