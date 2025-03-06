import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wearly/selected_style.dart';
import 'dart:convert';
import 'config.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController birthYearController = TextEditingController();
  final TextEditingController birthMonthController = TextEditingController();
  final TextEditingController birthDayController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  bool? isMale = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    pwdController.dispose();
    nameController.dispose();
    birthYearController.dispose();
    birthMonthController.dispose();
    birthDayController.dispose();
    ageController.dispose();
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

  Future<void> _showSuccessDialog(String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성공'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }


  Future<void> _registerUser() async {
    if (emailController.text.isEmpty) {
      _showErrorDialog('이메일을 입력해주세요.');
      return;
    }
    if (pwdController.text.isEmpty) {
      _showErrorDialog('비밀번호를 입력해주세요.');
      return;
    }
    if (nameController.text.isEmpty) {
      _showErrorDialog('이름을 입력해주세요.');
      return;
    }
    if (isMale == null) {
      _showErrorDialog('성별을 선택해주세요.');
      return;
    }
    if (birthYearController.text.isEmpty ||
        birthMonthController.text.isEmpty ||
        birthDayController.text.isEmpty) {
      _showErrorDialog('생년월일을 입력해주세요.');
      return;
    }
    if (ageController.text.isEmpty) {
      _showErrorDialog('나이를 입력해주세요.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('$serverUrl/auth/signup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': emailController.text,
        'password': pwdController.text,
        'name': nameController.text,
        'gender': isMale == true ? 'M' : 'F',
        'birthdate':
            '${birthYearController.text}-${birthMonthController.text}-${birthDayController.text}',
        'age': ageController.text,
      }),
    );

    if (response.statusCode == 201) {
      final String userEmail = emailController.text;

      print('회원가입 성공: $userEmail');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StyleSelectorScreen(
            userId: userEmail,
          ),
        ),
      );
    } else {
      _showErrorDialog('회원가입 실패: ${response.body}');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: const Text('회원가입'),
            backgroundColor: Colors.blue,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const Text('이름'),
                TextField(
                  controller: nameController,
                ),
                const SizedBox(height: 20),
                const Text('성별'),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('남'),
                        value: true,
                        groupValue: isMale,
                        onChanged: (value) {
                          setState(() {
                            isMale = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('여'),
                        value: false,
                        groupValue: isMale,
                        onChanged: (value) {
                          setState(() {
                            isMale = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('생년월일'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: birthYearController,
                        decoration: const InputDecoration(hintText: '년 (YYYY)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: birthMonthController,
                        decoration: const InputDecoration(hintText: '월 (MM)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: birthDayController,
                        decoration: const InputDecoration(hintText: '일 (DD)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('나이'),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '나이'),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: isLoading ? null : _registerUser,
                  child: Container(
                    height: 50,
                    color: Colors.blue,
                    child: Center(
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('가입하기',
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
