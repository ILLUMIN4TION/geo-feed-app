// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/home_screen.dart';   // (5단계에서 생성)
import 'package:geofeed/screens/login_screen.dart';  // (5단계에서 생성)
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  //비동기 작업(FireBase)에서 플러터 프레임워크 사용을 위한 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // Provider 여러 개
    MultiProvider(
      providers: [

        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),

        ChangeNotifierProvider(
          create: (_) => MyAuthProvider(),
        ),
        
         ChangeNotifierProvider(
          create: (_) => UploadProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo-Feed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      // 3. 앱의 첫 진입점
      home: const AuthWrapper(),
    );
  }
}

// 4. 인증 상태에 따라 화면을 분기하는 Wrapper
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamProvider가 제공하는 User? 값을 구독
    final firebaseUser = context.watch<User?>();

    if (firebaseUser != null) {
      return const HomeScreen(); // 로그인 시 홈으로
    } else {
      return const LoginScreen(); // 로그아웃 시 로그인으로
    }
  }
}