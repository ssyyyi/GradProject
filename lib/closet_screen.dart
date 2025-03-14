import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:wearly/remove_back.dart';
import 'package:wearly/state_management/closet_provider.dart';

class ClosetScreen extends StatefulWidget {
  final String userId;
  const ClosetScreen({super.key, required this.userId});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  final ImagePicker _picker = ImagePicker();
  final RemoveBgService _removeBgService = RemoveBgService();

  @override
  void initState() {
    super.initState();


    Future.microtask(() async {
      final closetProvider = Provider.of<ClosetProvider>(context, listen: false);
      await closetProvider.switchUser(widget.userId);
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

  @override
  Widget build(BuildContext context) {
    final closetProvider = Provider.of<ClosetProvider>(context);

    return Stack(
      children: [
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
