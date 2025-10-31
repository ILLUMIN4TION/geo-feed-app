// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart'; // 이름 변경 반영
import 'package:geofeed/utils/view_state.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    // 상태 변화(로딩, 에러)를 UI에 반영하기 위해 watch 사용
    final authProvider = context.watch<MyAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '환영합니다!',
                  style: TextStyle(
                    fontSize: 28,
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
                const SizedBox(height: 20),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 확인',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 30),
                
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
                            // 1. 비밀번호 확인
                            if (passwordController.text != confirmPasswordController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("비밀번호가 일치하지 않습니다."),
                                  backgroundColor: Colors.orangeAccent,
                                ),
                              );
                              return; // 함수 종료
                            }

                            // 2. 회원가입 시도 (Provider 호출은 read)
                            bool success = await context.read<MyAuthProvider>().signUp(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                );

                            if (success && context.mounted) {
                              // 성공 시: 로그인 화면으로 자동 복귀 (AuthWrapper가 홈으로 보내줌)
                              Navigator.pop(context);
                            } else if (!success && context.mounted) {
                              // 실패 시: 에러 메시지 표시
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.read<MyAuthProvider>().errorMessage ?? "알 수 없는 오류"
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          child: const Text('회원가입 완료', style: TextStyle(fontSize: 18)),
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