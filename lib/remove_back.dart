import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'config.dart';

class RemoveBgService {
  final String serverurl = '$serverUrl/closet/bgremoved';
  //late String userId;

  Future<Map<String, String>?> removeBackground(File imageFile, String userId) async {
    try {
      if (!imageFile.existsSync()) {
        print('파일이 존재하지 않습니다.');
        return null;
      }

      var request = http.MultipartRequest('POST', Uri.parse(serverurl));

      var multipartFile =
      await http.MultipartFile.fromPath('image', imageFile.path);
      request.files.add(multipartFile);

      request.fields['userId'] = userId;
      //request.fields['user_Id'] = userId;

      var response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(responseData);

        print('스타일: $data[predicted_style]');

        if (data.containsKey('bg_removed_image_url') && data.containsKey('predicted_style')) {
          return {
            'bg_removed_image_url': data['bg_removed_image_url'],
            'predicted_style': data['predicted_style'],
          };
        } else {
          print('배경 제거 성공했지만 필요한 데이터를 찾을 수 없음.');
          return null;
        }
      } else {
        print('배경 제거 실패: ${response.statusCode} - ${response.reasonPhrase}');
        final responseData = await response.stream.bytesToString();
        print('응답 데이터: $responseData');
        return null;
      }
    } catch (e) {
      if (e is SocketException) {
        print('네트워크 연결 실패: $e');
      } else if (e is TimeoutException) {
        print('요청 시간이 초과되었습니다.');
      } else {
        print('오류 발생: $e');
      }
      return null;
    }
  }
}
