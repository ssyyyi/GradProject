import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

// void main() {
//   runApp(MaterialApp(
//     debugShowCheckedModeBanner: false,
//     home: ModelLoad(),
//   ));
// }

class ModelLoad extends StatelessWidget {
  const ModelLoad({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Model Viewer')),
        body: const ModelViewer(
          backgroundColor: Color.fromARGB(0xFF, 0xEE, 0xEE, 0xEE),
          src: 'assets/models/standing_collada.glb',
          alt: 'A 3D model',
          //ar: true,
          autoRotate: false,
          disableZoom: true,
        ),
      ),
    );
  }
}