import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/upload_screen.dart';
import 'package:geofeed/screens/main_map_screen.dart';
import 'package:geofeed/screens/main_feed_screen.dart';
import 'package:geofeed/screens/profile_screen.dart';
import 'package:geofeed/screens/search_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  static final GlobalKey<HomeScreenState> homeKey = GlobalKey<HomeScreenState>();

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isInitialLoading = true;

  final List<Widget> _screens = const [
    MainMapScreen(),
    MainFeedScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _checkLostDataAndRedirect();
    });
  }

  Future<void> _checkLostDataAndRedirect() async {
    final uploadProvider = context.read<UploadProvider>();
    await uploadProvider.checkLostData();

    if (uploadProvider.pickedImageFile != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("촬영된 사진을 복구했습니다."),
          duration: Duration(seconds: 2),
        ),
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UploadScreen()),
      );
    }
  }

  Future<void> _loadInitialData() async {
    final postProvider = context.read<PostProvider>();

    try {
      await Future.wait([
        postProvider.fetchPosts(refresh: true),
        postProvider.fetchMapPosts(),
      ]);
    } catch (e) {
      print("Initial data load error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  // ★ 탭 변경 시 데이터 강제 새로고침
  void changeTab(int index) {
    if (index == 0) {
      // 지도로 갈 때: 지도 데이터 새로고침
      context.read<PostProvider>().fetchMapPosts();
    } else if (index == 1) {
      // 피드로 갈 때: 피드 데이터 새로고침 (필요하다면 주석 해제)
      // context.read<PostProvider>().fetchPosts(refresh: true);
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Geo-Feed')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('불러오는 중...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? '포토스팟 지도' : 'Geo-Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
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

      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          // 여기서 changeTab을 호출해야 로직이 수행됨
          changeTab(index);
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4.0,
        child: const Icon(Icons.add_a_photo),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}