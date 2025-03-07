import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: VirtualFittingScreen(),
  ));
}

class VirtualFittingScreen extends StatefulWidget {
  @override
  _VirtualFittingScreenState createState() => _VirtualFittingScreenState();
}

class _VirtualFittingScreenState extends State<VirtualFittingScreen> {
  String selectedTop = "assets/clothes/green_knit.png"; // 추천된 상의
  String selectedBottom = "assets/clothes/slacks.png"; // 기본 하의
  double topTopOffset = 200;
  double bottomTopOffset = 680;
  double topWidth = 200;
  double topHeight = 200;
  double bottomWidth = 200;
  double bottomHeight = 200;

  List<String> bottomList = [
    "assets/clothes/slacks.png",
    "assets/clothes/jeans.png",
    "assets/clothes/long_skirt.png",
    "assets/clothes/mini_skirt.png",
    "assets/clothes/training.png",
  ];

  @override
  void initState() {
    super.initState();
    loadPoseData();
  }

  Future<void> loadPoseData() async {
    String jsonString = await rootBundle.loadString("assets/avatarF_keypoints.json");
    Map<String, dynamic> data = jsonDecode(jsonString);

    double leftShoulderY = data["people"][0]["pose_keypoints_2d"][5];
    double rightShoulderY = data["people"][0]["pose_keypoints_2d"][2];
    double leftHipY = data["people"][0]["pose_keypoints_2d"][12];
    double rightHipY = data["people"][0]["pose_keypoints_2d"][9];

    double shoulderY = (leftShoulderY + rightShoulderY) / 2;
    double waistY = (leftHipY + rightHipY) / 2;
    double torsoHeight = waistY - shoulderY; // 상체 길이 계산

    setState(() {
      topTopOffset = shoulderY + 240; // 어깨보다 살짝 아래 배치
      bottomTopOffset = waistY + 160; // 허리보다 살짝 아래로 배치 (수정)
      topWidth = 220;
      topHeight = torsoHeight * 1.3;
      bottomWidth = 250;
      bottomHeight = (waistY - shoulderY) * 1.8; // 하체 길이를 고려한 크기 조정 (수정)
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("가상 피팅")),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/avatarF.png",
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: topTopOffset,
            left: MediaQuery.of(context).size.width / 2 - topWidth / 2,
            child: Image.asset(
              selectedTop,
              width: topWidth,
              height: topHeight,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: bottomTopOffset, // 수정된 하의 위치
            left: MediaQuery.of(context).size.width / 2 - bottomWidth / 2,
            child: Image.asset(
              selectedBottom,
              width: bottomWidth,
              height: bottomHeight,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: 20,
            child: Container(
              height: 120,
              width: MediaQuery.of(context).size.width,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: bottomList.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedBottom = bottomList[index];
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Image.asset(bottomList[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
