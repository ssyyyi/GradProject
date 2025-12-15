import 'package:flutter/material.dart';

class HomeImage extends StatefulWidget {
  const HomeImage({super.key});

  @override
  State<HomeImage> createState() => _HomeImageState();
}

class _HomeImageState extends State<HomeImage> {
  final List<String> imageList = [
    'assets/clothes/cloth_1.jpg',
    'assets/clothes/cloth_2.jpg',
    'assets/clothes/cloth_3.jpg',
    'assets/clothes/cloth_4.jpg',
    'assets/clothes/cloth_5.jpg',
  ];

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 슬라이더 박스
        SizedBox(
          height: 250,
          child: PageView.builder(
            //controller: PageController(viewportFraction: 1.1),
            itemCount: imageList.length,
            onPageChanged: (value) {
              setState(() {
                selectedIndex = value;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    imageList[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // 인디케이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(imageList.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 10,
              width: index == selectedIndex ? 20 : 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: index == selectedIndex
                    ? Colors.blueGrey
                    : Colors.grey.shade400,
              ),
            );
          }),
        ),
      ],
    );
  }
}
