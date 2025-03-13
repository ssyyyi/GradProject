import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final String _openweatherKey = "3bb7713e73b2e507852b313c7c89f002";
  String locationMessage = "위치 정보를 가져오는 중...";
  String weatherMessage = "날씨 정보를 가져오는 중...";

  @override
  void initState() {
    super.initState();
    getPosition();
  }

  Future<void> getPosition() async {
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      Position? lastPosition = await Geolocator.getLastKnownPosition();

      setState(() {
        locationMessage =
        "현재 위치:\n위도: ${currentPosition.latitude}, 경도: ${currentPosition.longitude}";
      });

      print("📍 현재 위치: $currentPosition");
      print("📍 마지막 위치: $lastPosition");

      getWeatherData(
        lat: currentPosition.latitude.toString(),
        lon: currentPosition.longitude.toString(),
      );
    } catch (e) {
      setState(() {
        locationMessage = "위치 정보를 가져올 수 없습니다: $e";
      });
      print("❌ 위치 정보를 가져오는 중 오류 발생: $e");
    }
  }

  Future<void> getWeatherData({required String lat, required String lon}) async {
    try {
      final String url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_openweatherKey&units=metric';

      print("🔗 API 요청 URL: $url");

      var response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var dataJson = jsonDecode(response.body);

        double temperature = dataJson['main']['temp']; // 현재 온도 (°C)
        String weatherCondition = dataJson['weather'][0]['main']; // 날씨 상태 (Clear, Rain 등)
        int humidity = dataJson['main']['humidity']; // 습도 (%)

        setState(() {
          weatherMessage = "🌡️ 온도: ${temperature}°C\n🌧️ 날씨: $weatherCondition\n💧 습도: $humidity%";
        });

        print("🌡현재 온도: $temperature°C");
        print("🌧날씨 상태: $weatherCondition");
        print("습도: $humidity%");
      } else {
        print("응답 오류: 상태 코드 ${response.statusCode}");
        setState(() {
          weatherMessage = "날씨 정보를 가져오는 데 실패했습니다. (코드: ${response.statusCode})";
        });
      }
    } catch (e) {
      print("날씨 API 요청 중 오류 발생: $e");
      setState(() {
        weatherMessage = "날씨 정보를 가져올 수 없습니다.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("위치 및 날씨 테스트")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              locationMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20), // 간격 추가
            Text(
              weatherMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
