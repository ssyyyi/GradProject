import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wearly/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'home_image.dart';

class WeatherAndOutfitScreen extends StatefulWidget {
  @override
  _WeatherAndOutfitScreenState createState() => _WeatherAndOutfitScreenState();
}

class _WeatherAndOutfitScreenState extends State<WeatherAndOutfitScreen> {
  final String _apiKey = "3bb7713e73b2e507852b313c7c89f002";

  double? latitude;
  double? longitude;

  String location = "위치 확인 중...";
  double currentTemp = 0.0;
  String weatherCondition = "";
  String weatherIcon = "";
  List<dynamic> hourlyForecast = [];
  List<dynamic> dailyForecast = [];
  String currentDate = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(DateTime.now());

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
        final item = response.data['data'];
        setState(() {
          recommendedOutfits = [
            {
              'id': item['id'],
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
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final fittedUrl = response.data['data']['image_url'];
        try {
          fittingChannel ??= WebSocketChannel.connect(Uri.parse(wsUrl));
          final payload = jsonEncode({
            'type': 'fitting',
            'user_id': userId,
            'image_url': fittedUrl,
            'device_id': 'smartphone'
          });
          fittingChannel!.sink.add(payload);
        } catch (e) {
          print("WebSocket 오류: $e");
        }
      } else {
        print("전송 실패: ${response.data['message']}");
      }
    } catch (e) {
      print("전송 오류: $e");
    }
  }

  Future<void> sendFeedback(String feedbackType) async {
    if (recommendedOutfits.isEmpty || userId == null) return;
    final itemId = recommendedOutfits[0]['id'];
    if (itemId == null) return;

    try {
      final response = await Dio().post(
        '$serverUrl/outfit/feedback',
        data: {
          'userId': userId,
          'itemId': itemId,
          'feedback': feedbackType,
        },
      );

      if (response.statusCode == 200 && response.data['success']) {
        final next = response.data['data'];

        if (feedbackType == "dislike") {
          setState(() {
            if (next != null) {
              recommendedOutfits = [
                {
                  'id': next['id'],
                  'image_url': next['image_url'],
                }
              ];
            } else {
              recommendedOutfits = [];
            }
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(feedbackType == "like"
              ? "좋아요가 반영되었습니다"
              : "다른 스타일로 넘어갑니다"),
        ));
      }
    } catch (e) {
      print("피드백 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                //color: Colors.lightBlue[200],
                //color: Colors.blueGrey[400],
                color: Colors.indigo[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, color: Colors.blueGrey[600], size: 20),
                  SizedBox(width: 6),
                  Text(
                    "오늘 어떤 일정이 있으신가요?",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey[600],
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
              HomeImage(),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: fetchRecommendations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFD1C4E9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: Text("OOTD 추천받기"),
              ),
              SizedBox(height: 10),
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else if (recommendedOutfits.isEmpty)
                Center(child: Text(""))
              else
                Column(
                  children: recommendedOutfits.take(3).map((outfit) {
                    final imageUrl = outfit['image_url']?.toString() ?? '';
                    final Color primaryColor = Color(0xFFB39DDB);

                    return Column(
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: Container(
                            width: 180,
                            height: 180,
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 48),
                              )
                                  : Icon(Icons.image_not_supported, size: 48),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => sendFeedback("like"),
                              icon: Icon(Icons.thumb_up_alt_outlined, color: primaryColor),
                              label: Text("좋아요", style: TextStyle(color: primaryColor)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: primaryColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => sendFeedback("dislike"),
                              icon: Icon(Icons.thumb_down_alt_outlined, color: primaryColor),
                              label: Text("다른 스타일", style: TextStyle(color: primaryColor)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: primaryColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            final imageUrl = recommendedOutfits[0]['image_url']?.toString() ?? '';
                            if (imageUrl.isNotEmpty) {
                              sendToFittingServer(imageUrl);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            shape: StadiumBorder(),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: Text("피팅하기", style: TextStyle(color: Colors.white,),),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
