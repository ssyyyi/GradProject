import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:wearly/remove_back.dart';
import 'package:wearly/selected_style.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:wearly/state_management/closet_provider.dart';
//import 'closet_provider.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId,});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<String> _uploadedImages = [];
  final List<String> _predictedStyles = [];
  final ImagePicker _picker = ImagePicker();
  final RemoveBgService _removeBgService = RemoveBgService();

  @override
  void initState() {
    super.initState();
  }


  Future<void> _pickImage(ImageSource source) async {
    //final closetProvider = Provider.of<ClosetProvider>(context, listen: false);
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      //상태관리 되면 아래 지워도 됨
      setState(() {
        _uploadedImages.add(imageFile.path);
      });

      Map<String, String>? result = await _removeBgService.removeBackground(imageFile, widget.userId);
      if (result != null) {
        //closetProvider.addImage(result['bg_removed_image_url']!, result['predicted_style']!);
        //상태관리 되면 아래 setState 부분 지워도 됨
        setState(() {
          _uploadedImages[_uploadedImages.length - 1] = result['bg_removed_image_url']!;
          _predictedStyles.add(result['predicted_style']!);
        });
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => StyleSelectorScreen(
        //       imageUrl: result['bg_removed_image_url']!,
        //       predictedStyle: result['predicted_style']!, // 스타일 정보 추가 전달
        //       userId: widget.userId,
        //     ),
        //   ),
        // );

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
  //상태관리 되면 아래 지워도 됨
  void _removeImage(int index) {
    setState(() {
      _uploadedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    //final closetProvider = Provider.of<ClosetProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('WEarly'),
      ),
      body: Stack(
        children: [
          if (_currentIndex == 0) GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            //itemCount: closetProvider.uploadedImages.length,
            itemCount: _uploadedImages.length,
            itemBuilder: (context, index) {
              //var image = closetProvider.uploadedImages[index];
              var image = _uploadedImages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  image.startsWith('http')
                      ? Image.network(image, fit: BoxFit.cover)
                      : Image.file(File(image), fit: BoxFit.cover),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: GestureDetector(
                      //onTap: () => closetProvider.removeImage(index),
                      onTap: () => _removeImage(index),
                      child: const Icon(Icons.remove_circle,
                          color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          ) else Center(
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
