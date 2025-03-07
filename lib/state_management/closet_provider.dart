import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClosetProvider extends ChangeNotifier {
  List<String> _uploadedImages = [];
  List<String> _predictedStyles = [];

  List<String> get uploadedImages => _uploadedImages;
  List<String> get predictedStyles => _predictedStyles;

  ClosetProvider() {
    _loadImages(); // 앱 실행 시 저장된 데이터 불러오기
  }

  Future<void> _loadImages() async {
    final prefs = await SharedPreferences.getInstance();
    _uploadedImages = prefs.getStringList('uploadedImages') ?? [];
    _predictedStyles = prefs.getStringList('predictedStyles') ?? [];
    notifyListeners();
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
    await prefs.setStringList('uploadedImages', _uploadedImages);
    await prefs.setStringList('predictedStyles', _predictedStyles);
  }
}
