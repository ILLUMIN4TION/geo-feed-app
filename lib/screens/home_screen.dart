import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/upload_screen.dart';
import 'package:geofeed/screens/main_map_screen.dart';
import 'package:geofeed/screens/main_feed_screen.dart';
import 'package:geofeed/screens/profile_screen.dart';
import 'package:geofeed/screens/search_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  // 외부에서 접근할 수 있는 static 키
  static final GlobalKey<HomeScreenState> homeKey = GlobalKey<HomeScreenState>();

  // 1. 'const' 키워드 삭제
  // 2. '{super.key}' 삭제 (외부에서 키를 받지 않고 우리가 만든 homeKey를 강제로 씀)
  HomeScreen() : super(key: homeKey);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

// 2. 외부에서 접근해야 하므로 클래스 이름 앞의 '_' 제거 (Public 클래스)
class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 0: Map, 1: Feed

  final List<Widget> _screens = const [
    MainMapScreen(),
    MainFeedScreen(),
  ];

  // 3. 탭을 변경하는 메서드 (외부 호출용)
  void changeTab(int index) {
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
          //검색 버튼
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          // 프로필 버튼
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          // 로그아웃 버튼 (다이얼로그 포함)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text("로그아웃"),
                    content: const Text("정말로 로그아웃 하시겠습니까?"),
                    actions: [
                      TextButton(
                        child: const Text("취소"),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      TextButton(
                        child: const Text("로그아웃", style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          context.read<MyAuthProvider>().signOut();
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),

      // 탭 전환 시 화면 유지
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
        },
        // (수정) 교수님 피드백: 가독성을 위해 흰색 배경 + 검정 아이콘
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4.0, // 그림자 추가로 돋보이게
        child: const Icon(Icons.add_a_photo),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}