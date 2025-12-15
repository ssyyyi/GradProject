import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wearly/tablet_main.dart';
import 'dart:convert';
import 'config.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwdController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  Future<void> _showErrorDialog(String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _loginUser() async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('$serverUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': emailController.text,
        'password': pwdController.text,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final String userId = responseData['user_id'];

      print('유저 아이디: $userId');

      // ✅ SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);

      // ✅ SmartClosetUI로 이동 (userId 전달 없이)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SmartClosetUI()),
      );
    } else {
      _showErrorDialog('로그인 실패: 이메일이나 비밀번호를 확인하세요.');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('로그인', style: TextStyle(fontSize: 24))),
            const SizedBox(height: 20),
            const Text('이메일'),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            const Text('비밀번호'),
            TextField(
              controller: pwdController,
              obscureText: true,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: isLoading ? null : _loginUser,
              child: Container(
                height: 50,
                color: Colors.blue,
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    '로그인하기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
