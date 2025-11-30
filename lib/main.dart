import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/home_screen.dart';
import 'package:geofeed/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  //비동기 작업(FireBase)에서 플러터 프레임워크 사용을 위한 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, //현재 기기에 맞춰서 기본파이어베이스 옵션 설정
  );

  runApp(
    // Provider 여러 개
    MultiProvider(
      providers: [
        //로그인 상태만 관리하는 프로바이더 User객체가 존재/null인지(로그인여부)만 확인하여 AuthWrapper 화면 분기 
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
        // 2. PostProvider 등록 (이 부분 추가)
        ChangeNotifierProvider(
          create: (_) => PostProvider(),
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 데이터 로드
    Future.microtask(() {
      context.read<PostProvider>().fetchPosts(refresh: true);
      context.read<PostProvider>().fetchMapPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();

    if (firebaseUser != null) {
      return HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}