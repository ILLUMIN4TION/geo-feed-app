// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart'; // 이름 변경 반영
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/screens/register_screen.dart'; // (다음 단계에서 생성)
import 'package:provider/provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    // Provider의 '상태'를 구독(watch)하여 UI를 변경
    final authProvider = context.watch<MyAuthProvider>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Geo-Feed',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 30),
                
                // 1. 로딩 상태에 따라 버튼 또는 인디케이터 표시
                (authProvider.state == ViewState.Loading)
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            bool success = await context.read<MyAuthProvider>().signIn(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                );
                            
                            // 3. 로그인 실패 시 (Error 상태일 때) 스낵바 표시
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    // 에러 메시지 변수에서 가져오기
                                    context.read<MyAuthProvider>().errorMessage ?? 
                                    "알 수 없는 오류"
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                            // 성공 시 AuthWrapper가 알아서 HomeScreen으로 이동시킴
                          },
                          child: const Text('로그인', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // 4. 회원가입 화면으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text('아직 계정이 없으신가요? 회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}