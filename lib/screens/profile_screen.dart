import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/widgets/user_info_header.dart'; 

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 현재 로그인한 사용자 UID 가져오기
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    // 2. 현재 사용자의 정보 (헤더용)
    final userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    // 3. 현재 사용자의 게시물만 가져오는 스트림
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: currentUserId) // (핵심) UID로 필터링
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text("내 프로필"),
      ),
      body: StreamBuilder<List<Post>>(
        stream: postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("게시물을 불러오는데 실패했습니다."));
          }

          final posts = snapshot.data ?? [];

          // 4. GridView를 CustomScrollView와 Sliver로 구성 (헤더 + 그리드)
          return CustomScrollView(
            slivers: [
              // 5. 프로필 헤더 (FutureBuilder 사용)
              SliverToBoxAdapter(
                child: FutureBuilder<DocumentSnapshot>(
                  future: userFuture,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final username = userData['username'] ?? '사용자';
                    // TODO: 프로필 수정 기능
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            // (수정) 동일한 로직 적용
                            backgroundImage: (userData['profileImageUrl'] != null)
                                ? NetworkImage(userData['profileImageUrl'])
                                : const AssetImage('assets/images/default_user_image.png') as ImageProvider,
                            backgroundColor: Colors.grey[300],
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Text("게시물 ${posts.length}개"),
                              // TODO: 프로필 수정 버튼
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SliverToBoxAdapter(child: Divider()),

              // 6. 게시물이 없을 때
              if (posts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(
                      child: Text("업로드한 게시물이 없습니다.", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ),

              // 7. 내 게시물 그리드
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 한 줄에 3개
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = posts[index];
                    return GestureDetector(
                      onTap: () {
                        // 그리드 아이템 클릭 시 상세 페이지로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailScreen(post: post),
                          ),
                        );
                      },
                      child: Image.network(
                        post.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                  childCount: posts.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}