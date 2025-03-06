import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      print('로그인 성공');

      // 응답 데이터에서 사용자 ID 추출
      final Map<String, dynamic> responseData = json.decode(response.body);
      final String userId = responseData['user_id'];

      // 홈 화면으로 이동하면서 사용자 ID를 전달
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'userId': userId,
        },
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
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
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : const Text('로그인하기',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}