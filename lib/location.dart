import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화
  await initializeDateFormatting('ko', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String _apiKey = "3bb7713e73b2e507852b313c7c89f002";
  String location = "위치 확인 중...";
  double currentTemp = 0.0;
  String weatherCondition = "";
  String weatherIcon = "";
  List<dynamic> hourlyForecast = [];
  List<dynamic> dailyForecast = [];
  String currentDate = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    getLocationAndWeather();
  }

  Future<void> getLocationAndWeather() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      double lat = position.latitude;
      double lon = position.longitude;

      await fetchCurrentWeather(lat, lon);
      await fetchForecast(lat, lon);
    } catch (e) {
      print("위치 및 날씨 정보를 가져오는 중 오류 발생: $e");
    }
  }

  Future<void> fetchCurrentWeather(double lat, double lon) async {
    try {
      String url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&lang=kr&appid=$_apiKey';

      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        setState(() {
          currentTemp = (data['main']['temp']).toDouble();
          weatherCondition = data['weather'][0]['main'];

          String iconCode = data['weather'][0]['icon'] ?? "01d";
          weatherIcon = "https://openweathermap.org/img/wn/$iconCode@2x.png";

          location = data['name'] ?? "현재 위치";
        });
      } else {
        print("현재 날씨 데이터를 가져오는 데 실패했습니다. 상태 코드: ${response.statusCode}");
      }
    } catch (e) {
      print("현재 날씨 API 요청 중 오류 발생: $e");
    }
  }

  Future<void> fetchForecast(double lat, double lon) async {
    try {
      String url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&units=metric&appid=$_apiKey';

      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        setState(() {
          hourlyForecast = data['list'].sublist(0, 8);
          dailyForecast = _groupDailyForecast(data['list']);
        });
      } else {
        print("예보 데이터를 가져오는 데 실패했습니다. 상태 코드: ${response.statusCode}");
      }
    } catch (e) {
      print("예보 API 요청 중 오류 발생: $e");
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
        if (temp < dailyMap[dayKey]!["temp_min"]) {
          dailyMap[dayKey]!["temp_min"] = temp;
        }
        if (temp > dailyMap[dayKey]!["temp_max"]) {
          dailyMap[dayKey]!["temp_max"] = temp;
        }
      }
    }

    dailyMap.remove(todayKey);
    return dailyMap.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 현재 날씨 카드
            Card(
              //color: Color(0xC7BCE8CD),
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
                    Column(
                      children: [
                        Text(currentDate, style: TextStyle(fontSize: 20, color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${currentTemp.toStringAsFixed(1)}°C",
                          style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 10),
                        weatherIcon.isNotEmpty
                            ? Icon(Icons.wb_sunny, size: 50, color: Colors.orange) //Image.network(weatherIcon, width: 50, height: 50)
                            : Icon(Icons.wb_sunny, size: 50, color: Colors.orange),
                      ],
                    ),
                    Text(weatherCondition, style: TextStyle(fontSize: 25, color: Colors.white)),
                    SizedBox(height: 20),

                    // 시간별 날씨 예보
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
                            Text("${time.hour}:00", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,)),
                            Image.network(iconUrl, width: 40, height: 40),
                            Text("${temp.toStringAsFixed(1)}°C", style: TextStyle(color: Colors.white),),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // 5일간 날씨 예보
            Expanded(
              child: ListView.builder(
                itemCount: dailyForecast.length,
                itemBuilder: (context, index) {
                  var dayData = dailyForecast[index];
                  String weekday = DateFormat('E', 'ko').format(dayData['date']);

                  return Card(
                    //color: Color(0xFFF5F5F5),
                    color: Colors.purpleAccent[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                    child: ListTile(
                      leading: Image.network(
                        "https://openweathermap.org/img/wn/${dayData['icon']}@2x.png",
                        width: 50,
                        height: 50,
                      ),
                      title: Text("${dayData['date'].month}/${dayData['date'].day} ($weekday)", style: TextStyle(color: Colors.blueGrey[700],),),
                      subtitle: Text("🌡️ 최저: ${dayData['temp_min']}°C | 최고: ${dayData['temp_max']}°C", style: TextStyle(color: Colors.blueGrey[600],),),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
