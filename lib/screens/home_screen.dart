// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/main_feed_screen.dart';
import 'package:geofeed/screens/upload_screen.dart';
import 'package:provider/provider.dart';
import 'package:geofeed/screens/main_map_screen.dart';
// TODO: (2단계에서 생성)
// import 'main_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 2. 탭에 연결할 스크린 목록 (수정)
  final List<Widget> _screens = [
    const MainMapScreen(), // 0번 (W4)
    const MainFeedScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? '포토스팟 지도' : 'Geo-Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<MyAuthProvider>().signOut();
            },
          )
        ],
      ),
      
      // 1. 선택된 인덱스에 따라 바디(화면)가 변경됨
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // 2. 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
        ],
      ),
      
      // 3. 업로드 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
        },
        child: const Icon(Icons.add_a_photo),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // (선택) FAB 위치
    );
  }
}