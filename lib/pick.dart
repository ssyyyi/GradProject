// import 'package:flutter/material.dart';
//
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//           body: SingleChildScrollView(
//             child: ConstrainedBox(
//               constraints:
//               BoxConstraints(minHeight: MediaQuery.of(context).size.height),
//               child: IntrinsicHeight(
//                 child: Stack(children: <Widget>[
//                   Divider(
//                     color: Colors.white, //color of divider
//                     height: 150, //height spacing of divider
//                     thickness: 2, //thickness of divier line
//                   ),
//                   Divider(
//                     color: Colors.white,
//                     height: 158,
//                     thickness: 2,
//                   ),
//                   VerticalDivider(
//                     width: 35,
//                     thickness: 2,
//                     color: Colors.white,
//                   ),
//                   Container(
//                     height: 70,
//                     width: double.infinity,
//                     // color: Colors.amber,
//                     child: const Padding(
//                       padding: EdgeInsets.fromLTRB(30, 30, 0, 0),
//                       child: Text('Select Image !',
//                           style: TextStyle(
//                             fontSize: 32,
//                             fontFamily: 'PautaOne',
//                           )),
//                     ),
//                   ),
//                   Positioned(
//                     top: 81,
//                     left: 19,
//                     child: Container(
//                       width: MediaQuery.of(context).size.width * 0.7,
//                       height: MediaQuery.of(context).size.height * 0.7,
//                       // color: Colors.redAccent,
//                       child: Column(
//                         children: [
//                           Flexible(
//                               child: Container(
//                                 // color: Colors.green,
//                                 child: Column(
//                                   children: [
//                                     Container(
//                                       width: MediaQuery.of(context).size.width *
//                                           0.7,
//                                       height: 50,
//                                       // color: Colors.blue,
//                                       child: Stack(children: [
//                                         Positioned(
//                                             bottom: 5,
//                                             left: 20,
//                                             child: Text('Model Image',
//                                                 style: TextStyle(
//                                                     fontSize: 32,
//                                                     fontFamily: 'PautaOne',
//                                                     fontWeight:
//                                                     FontWeight.w100)))
//                                       ]),
//                                     ),
//                                     Padding(
//                                       padding: const EdgeInsets.all(8.0),
//                                       child: Container(
//                                           child: DecoratedBox(
//                                               child: Column(
//                                                 mainAxisAlignment:
//                                                 MainAxisAlignment.center,
//                                               ),
//                                               decoration: BoxDecoration(
//                                                   border: Border.all(
//                                                     color:
//                                                     Colors.black, // 점선의 색상 설정
//                                                     style: BorderStyle
//                                                         .solid, // 실선 대신 점선으로 설정,
//                                                   ))),
//                                           // color: Colors.pink,
//                                           width: MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.5,
//                                           height: 135),
//                                     ),
//                                     Container(
//                                       child: TextButton(
//                                           style: TextButton.styleFrom(
//                                             minimumSize: Size(260, 20),
//                                             shape: RoundedRectangleBorder(
//                                               borderRadius:
//                                               BorderRadius.circular(20),
//                                             ),
//                                           ),
//                                           onPressed: () {
//                                             print('Select a model image');
//                                           },
//                                           child: Text('Select a model image',
//                                               style: TextStyle(
//                                                   color: Colors.black))),
//                                       color: Color.fromRGBO(184, 206, 182, 100),
//                                       // color: Colors.purple,
//                                       height: 25,
//                                     )
//                                   ],
//                                 ),
//                               ),
//                               flex: 10),
//                           Flexible(
//                               child: Container(
//                                 // color: Colors.green,
//                                 child: Column(
//                                   children: [
//                                     Container(
//                                       width: MediaQuery.of(context).size.width *
//                                           0.7,
//                                       height: 50,
//                                       // color: Colors.blue,
//                                       child: Stack(children: [
//                                         Positioned(
//                                             bottom: 5,
//                                             left: 20,
//                                             child: Text('Clothes Image',
//                                                 style: TextStyle(
//                                                   fontSize: 32,
//                                                   fontFamily: 'PautaOne',
//                                                 )))
//                                       ]),
//                                     ),
//                                     Padding(
//                                       padding: const EdgeInsets.all(8.0),
//                                       child: Container(
//                                           child: DecoratedBox(
//                                               child: Column(
//                                                 mainAxisAlignment:
//                                                 MainAxisAlignment.center,
//                                               ),
//                                               decoration: BoxDecoration(
//                                                   border: Border.all(
//                                                     color:
//                                                     Colors.black, // 점선의 색상 설정
//                                                     style: BorderStyle
//                                                         .solid, // 실선 대신 점선으로 설정,
//                                                   ))),
//                                           // color: Colors.pink,
//                                           width: MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.5,
//                                           height: 135),
//                                     ),
//                                     Container(
//                                       child: TextButton(
//                                           style: TextButton.styleFrom(
//                                             minimumSize: Size(260, 20),
//                                             shape: RoundedRectangleBorder(
//                                               borderRadius:
//                                               BorderRadius.circular(20),
//                                             ),
//                                           ),
//                                           onPressed: () {
//                                             print(
//                                                 'Select an image of your clothes');
//                                           },
//                                           child: Text(
//                                               'Select an image of your clothes',
//                                               style: TextStyle(
//                                                   color: Colors.black))),
//                                       color: Color.fromRGBO(184, 206, 182, 100),
//                                       height: 25,
//                                     )
//                                   ],
//                                 ),
//                               ),
//                               flex: 10),
//                           Flexible(
//                               child: Container(
//                                 child: TextButton(
//                                     style: TextButton.styleFrom(
//                                       minimumSize: Size(260, 20),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(20),
//                                       ),
//                                     ),
//                                     onPressed: () {
//                                     },
//                                     child: Text(
//                                       'Image Upload',
//                                       style: TextStyle(color: Colors.black),
//                                     )),
//                                 color: Color.fromRGBO(108, 138, 105, 100),
//                               ),
//                               flex: 2)
//                         ],
//                       ),
//                     ),
//                   ),
//                 ]),
//               ),
//             ),
//           ),
//           backgroundColor: Color.fromRGBO(184, 206, 182, 100)),
//     );
//   }
// }
//
// // 해야할거
// // 버튼 수정 (둥글게)
// // 규격 수정 (반응형 ?????)