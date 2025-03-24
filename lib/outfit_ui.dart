import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wearly/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


class WeatherAndOutfitScreen extends StatefulWidget {
  @override
  _WeatherAndOutfitScreenState createState() => _WeatherAndOutfitScreenState();
}

class _WeatherAndOutfitScreenState extends State<WeatherAndOutfitScreen> {
  final String _apiKey = "3bb7713e73b2e507852b313c7c89f002";

  // 공통 위치
  double? latitude;
  double? longitude;

  // 날씨 정보
  String location = "위치 확인 중...";
  double currentTemp = 0.0;
  String weatherCondition = "";
  String weatherIcon = "";
  List<dynamic> hourlyForecast = [];
  List<dynamic> dailyForecast = [];
  String currentDate = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(DateTime.now());

  // 추천 정보
  String? userId;
  String selectedSituation = "CasualMeeting";
  List<Map<String, dynamic>> recommendedOutfits = [];
  bool isLoading = false;
  WebSocketChannel? fittingChannel;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    super.dispose();
    fittingChannel?.sink.close();
  }

  Future<void> initialize() async {
    await _loadUserId();
    await _getCurrentLocation();
    if (latitude != null && longitude != null) {
      await fetchCurrentWeather();
      await fetchForecast();
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });
  }

  Future<void> fetchCurrentWeather() async {
    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&units=metric&lang=kr&appid=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          currentTemp = (data['main']['temp']).toDouble();
          weatherCondition = data['weather'][0]['main'];
          String iconCode = data['weather'][0]['icon'] ?? "01d";
          weatherIcon = "https://openweathermap.org/img/wn/$iconCode@2x.png";
          location = data['name'] ?? "현재 위치";
        });
      }
    } catch (e) {
      print("날씨 오류: $e");
    }
  }

  Future<void> fetchForecast() async {
    try {
      final url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          hourlyForecast = data['list'].sublist(0, 6);
          dailyForecast = _groupDailyForecast(data['list']);
        });
      }
    } catch (e) {
      print("예보 오류: $e");
    }
  }

  List<dynamic> _groupDailyForecast(List<dynamic> forecastList) {
    Map<String, Map<String, dynamic>> dailyMap = {};
    DateTime now = DateTime.now();
    String todayKey = "${now.year}-${now.month}-${now.day}";

    for (var item in forecastList) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      String dayKey = "${date.year}-${date.month}-${date.day}";

      double temp = (item['main']['temp']).toDouble();
      String icon = item['weather'][0]['icon'] ?? "01d";

      if (!dailyMap.containsKey(dayKey)) {
        dailyMap[dayKey] = {
          "temp_min": temp,
          "temp_max": temp,
          "icon": icon,
          "date": date,
        };
      } else {
        if (temp < dailyMap[dayKey]!['temp_min']) dailyMap[dayKey]!['temp_min'] = temp;
        if (temp > dailyMap[dayKey]!['temp_max']) dailyMap[dayKey]!['temp_max'] = temp;
      }
    }

    dailyMap.remove(todayKey);
    return dailyMap.values.toList();
  }

  Future<void> fetchRecommendations() async {
    if (latitude == null || longitude == null || userId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await Dio().get(
        '$serverUrl/outfit/recommend',
        queryParameters: {
          'userId': userId,
          'situation': selectedSituation,
          'lat': latitude.toString(),
          'lon': longitude.toString(),
        },
      );

      if (response.statusCode == 200 && response.data['success']) {
        print("추천 응답: ${response.data}");

        final item = response.data['data'];

        setState(() {
          recommendedOutfits = [
            {
              'image_url': item['image_url']?.toString() ?? '',
            }
          ];
        });
      }
    } catch (e) {
      print("추천 오류: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> sendToFittingServer(String clothImagePath) async {
    final String wsUrl = '$wsBaseUrl';
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        print("사용자 ID 없음");
        return;
      }

      final response = await Dio().post(
        '$serverUrl/outfit/fitting',
        data: {
          'userId': userId,
          'clothImagePath': clothImagePath,
          'situation': selectedSituation,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final fittedUrl = response.data['data']['image_url'];
        print("피팅 이미지 URL: ${response.data['data']['image_url']}");

        try {
          fittingChannel ??= WebSocketChannel.connect(Uri.parse(wsUrl));
          print("✅ WebSocket 연결 시도: $wsUrl");

          final payload = jsonEncode({
            'type': 'fitting',
            'user_id': userId,
            'image_url': fittedUrl,
            'device_id': 'smartphone'
          });

          fittingChannel!.sink.add(payload);
          print("✅ WebSocket 전송 성공: $payload");
        } catch (e) {
          print("❌ WebSocket 연결 또는 전송 중 에러: $e");
        }

      } else {
        print("전송 실패: ${response.data['message']}");
      }
    } catch (e) {
      print("전송 오류: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: Text("")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // 날씨 카드
                Card(
                  color: Colors.lightBlue[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(currentDate, style: TextStyle(fontSize: 20, color: Colors.white)),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("${currentTemp.toStringAsFixed(1)}°C",
                                style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                            SizedBox(width: 10),
                            weatherIcon.isNotEmpty
                                ? Image.network(weatherIcon, width: 50, height: 50)
                                : Icon(Icons.wb_sunny, size: 50, color: Colors.orange),
                          ],
                        ),
                        Text(weatherCondition, style: TextStyle(fontSize: 25, color: Colors.white)),
                        SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 10,
                          children: hourlyForecast.map((hourData) {
                            DateTime time = DateTime.fromMillisecondsSinceEpoch(hourData['dt'] * 1000);
                            String icon = hourData['weather'][0]['icon'] ?? "01d";
                            String iconUrl = "https://openweathermap.org/img/wn/$icon@2x.png";
                            double temp = (hourData['main']['temp']).toDouble();

                            return Column(
                              children: [
                                Text("${time.hour}:00",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Image.network(iconUrl, width: 40, height: 40),
                                Text("${temp.toStringAsFixed(1)}°C", style: TextStyle(color: Colors.white)),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Expanded 안에 스크롤 가능한 영역만 남김
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 상황 선택
                        //Text("오늘의 TPO 선택", style: TextStyle(fontSize: 18, color: Colors.blueGrey[600]),),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, color: Colors.blueGrey[600], size: 20),
                            SizedBox(width: 6),
                            Text(
                              "오늘 어떤 일정이 있으신가요?",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey[700],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['CasualMeeting', 'FormalEvent', 'Sports', 'Date'].map((situation) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(situation, style: TextStyle(fontSize: 12)),
                                  selected: selectedSituation == situation,
                                  onSelected: (bool selected) {
                                    setState(() {
                                      selectedSituation = situation;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: fetchRecommendations,
                          child: Text("OOTD 추천받기"),
                        ),

                        SizedBox(height: 10),

                        if (isLoading)
                          Center(child: CircularProgressIndicator())
                        else if (recommendedOutfits.isEmpty)
                          Center(child: Text("추천된 옷이 없습니다 "))
                        else
                          Column(
                            children: recommendedOutfits.take(3).map((outfit) {
                              final imageUrl = outfit['image_url']?.toString() ?? '';
                              print(imageUrl);

                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                child: Container(
                                  width: 160, // 카드 너비 조절
                                  height: 160, // 카드 높이 조절
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                      imageUrl,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 48),
                                    )
                                        : Icon(Icons.image_not_supported, size: 48),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            final imageUrl = recommendedOutfits[0]['image_url']?.toString() ?? '';
                            if (imageUrl.isNotEmpty) {
                              print(imageUrl);
                              sendToFittingServer(imageUrl);
                            } else {
                              print("이미지 URL이 비어 있습니다.");
                            }
                          },
                          child: Text("피팅하기"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}