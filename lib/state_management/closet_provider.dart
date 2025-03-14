import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClosetProvider extends ChangeNotifier {
  List<String> _uploadedImages = [];
  List<String> _predictedStyles = [];
  String _currentUserId = "";

  List<String> get uploadedImages => _uploadedImages;
  List<String> get predictedStyles => _predictedStyles;
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
    notifyListeners();
    await _saveImages();
  }

  Future<void> updateLastImage(String newImageUrl, String newStyle) async {
    if (_uploadedImages.isNotEmpty) {
      _uploadedImages[_uploadedImages.length - 1] = newImageUrl;
      _predictedStyles[_predictedStyles.length - 1] = newStyle;
      notifyListeners();
      await _saveImages();

    }
  }

  Future<void> removeImage(int index) async {
    if (index < _uploadedImages.length && index < _predictedStyles.length) {
      _uploadedImages.removeAt(index);
      _predictedStyles.removeAt(index);
      notifyListeners();
      await _saveImages();
    }
  }


  Future<void> _saveImages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('uploadedImages_$_currentUserId', _uploadedImages);
    await prefs.setStringList('predictedStyles_$_currentUserId', _predictedStyles);

    //debugPrint(" [saveImages] 계정 ($_currentUserId) 데이터 저장 완료");
  }

  Future<void> clearCloset() async {
    _uploadedImages = [];
    _predictedStyles = [];
    notifyListeners();

   // debugPrint(" [clearCloset] 메모리에서 옷장 데이터 초기화됨");
  }
}
