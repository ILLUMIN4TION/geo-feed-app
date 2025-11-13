// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/main_feed_screen.dart';
import 'package:geofeed/screens/upload_screen.dart';
import 'package:provider/provider.dart';
import 'package:geofeed/screens/main_map_screen.dart';
import 'package:geofeed/screens/profile_screen.dart'; // 1. ProfileScreen 임포트

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MainMapScreen(),
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
          // 2. (신규) 프로필 아이콘 버튼
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          
          // 3. 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<MyAuthProvider>().signOut();
            },
          ),
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