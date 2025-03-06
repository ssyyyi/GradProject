import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class WeatherClothingRecommendation extends StatefulWidget {
  final String userId;

  const WeatherClothingRecommendation({super.key, required this.userId});

  @override
  State<WeatherClothingRecommendation> createState() =>
      _WeatherClothingRecommendationState();
}

class _WeatherClothingRecommendationState
    extends State<WeatherClothingRecommendation> {
  double? currentTemperature;
  List<Map<String, dynamic>> userClothes = [];
  List<String> recommendedClothes = [];
  bool isFetchingData = false;

  @override
  void initState() {
    super.initState();
    fetchWeatherAndClothes();
  }

  // 위치 권한 요청 및 현재 위치 가져오기
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 비활성화되어 있습니다.');
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.');
    }

    // 현재 위치 가져오기
    return await Geolocator.getCurrentPosition();
  }

  // 날씨 및 옷 데이터를 서버에서 가져오기
  Future<void> fetchWeatherAndClothes() async {
    setState(() {
      isFetchingData = true;
    });

    try {
      // 위치 가져오기
      final position = await _determinePosition();
      if (position == null) {
        throw '위치 정보를 가져올 수 없습니다.';
      }

      final lat = position.latitude;
      final lon = position.longitude;

      // 1. 날씨 데이터 가져오기
      const String weatherApiUrl = '$serverUrl/weather/current';
      final weatherResponse =
          await http.get(Uri.parse('$weatherApiUrl?lat=$lat&lon=$lon'));
      print('Weather API Response Code: ${weatherResponse.statusCode}');
      print('Weather API Response Body: ${weatherResponse.body}');

      if (weatherResponse.statusCode == 200) {
        final weatherData = jsonDecode(weatherResponse.body);
        currentTemperature = weatherData['temperature'];
      } else {
        throw '날씨 정보를 가져오는 데 실패했습니다.';
      }

      // 2. 사용자의 옷 데이터 가져오기
      const String closetApiUrl = '$serverUrl/outfit/images';
      final closetResponse =
          await http.get(Uri.parse('$closetApiUrl?userId=${widget.userId}'));
      print('Outfit API Response Code: ${closetResponse.statusCode}');
      print('Outfit API Response Body: ${closetResponse.body}');

      if (closetResponse.statusCode == 200) {
        final List<dynamic> clothesData = jsonDecode(closetResponse.body);
        userClothes = clothesData.cast<Map<String, dynamic>>();
      } else {
        throw '옷 정보를 가져오는 데 실패했습니다.';
      }

      if (kDebugMode) {
        print('Weather API URL: $weatherApiUrl?lat=$lat&lon=$lon');
      }
      if (kDebugMode) {
        print('Closet API URL: $closetApiUrl?userId=${widget.userId}');
      }

      // 3. 옷 추천
      recommendClothes();
    } catch (e) {
      print('데이터 가져오기 실패: $e');
    } finally {
      setState(() {
        isFetchingData = false;
      });
    }
  }

  // 기온별 옷차림표 조건 설정 및 추천
  void recommendClothes() {
    if (currentTemperature == null || userClothes.isEmpty) return;

    String clothingCategory;
    if (currentTemperature! >= 27) {
      clothingCategory = '민소매/반팔';
    } else if (currentTemperature! >= 23) {
      clothingCategory = '반팔';
    } else if (currentTemperature! >= 20) {
      clothingCategory = '얇은 가디건';
    } else if (currentTemperature! >= 17) {
      clothingCategory = '얇은 니트/맨투맨';
    } else if (currentTemperature! >= 12) {
      clothingCategory = '자켓/가디건';
    } else if (currentTemperature! >= 9) {
      clothingCategory = '야상/트렌치코트';
    } else if (currentTemperature! >= 5) {
      clothingCategory = '코트/가죽자켓';
    } else {
      clothingCategory = '패딩';
    }

    // 사용자가 업로드한 옷 중에서 적합한 옷 필터링
    final filteredClothes = userClothes.where((item) {
      return item['category'] == clothingCategory;
    }).toList();

    setState(() {
      recommendedClothes =
          filteredClothes.map((item) => item['imageUrl'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 추천 옷')),
      body: isFetchingData
          ? const Center(child: CircularProgressIndicator())
          : currentTemperature == null
              ? const Center(child: Text('날씨 정보를 불러올 수 없습니다.'))
              : recommendedClothes.isEmpty
                  ? const Center(
                      child: Text(
                        '추천할 옷이 없습니다. 옷을 업로드해주세요!',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: recommendedClothes.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          recommendedClothes[index],
                          fit: BoxFit.cover,
                        );
                      },
                    ),
    );
  }
}
