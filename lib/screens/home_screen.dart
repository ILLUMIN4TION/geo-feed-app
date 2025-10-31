// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/upload_screen.dart'; // 1. UploadScreen 임포트
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<MyAuthProvider>().signOut();
            },
          )
        ],
      ),
      body: const Center(
        // TODO: (W4/W5) 여기에 피드 목록 또는 지도 표시
        child: Text('로그인 성공! 피드/지도 영역'),
      ),
      
      // 2. 새 게시물 작성 버튼 (FAB) 추가
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 3. UploadScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
        },
        child: const Icon(Icons.add_a_photo),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}