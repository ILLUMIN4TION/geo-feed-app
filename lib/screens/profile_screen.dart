import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/edit_profile_screen.dart';
import 'package:geofeed/screens/liked_posts_screen.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/screens/user_list_screen.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  // userId가 null이면 '내 프로필'로 간주
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    // 1. 보여줄 대상 ID 결정
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final String targetUserId = userId ?? currentAuthUser?.uid ?? "";
    final bool isMe = (currentAuthUser != null && targetUserId == currentAuthUser.uid);

    // 2. 유저 정보 스트림
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .snapshots();

    // 3. 게시물 스트림 (해당 유저의 글만)
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: targetUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? "내 프로필" : "프로필"),
        actions: [
          // 4. (신규) '내 프로필'일 때만 '좋아요 목록' 버튼 표시
          if (isMe)
            IconButton(
              icon: const Icon(Icons.favorite_border),
              tooltip: "좋아요한 게시물",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LikedPostsScreen()),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: postsStream,
        builder: (context, postSnapshot) {
          if (postSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (postSnapshot.hasError) {
            return Center(child: Text("데이터 오류: ${postSnapshot.error}"));
          }

          final posts = postSnapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                // 5. 유저 정보 헤더
                child: StreamBuilder<DocumentSnapshot>(
                  stream: userStream,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final username = userData['username'] ?? '알 수 없음';
                    final profileImageUrl = userData['profileImageUrl'];

                    // 팔로워/팔로잉 리스트
                    final List followers = userData['followers'] ?? [];
                    final List following = userData['following'] ?? [];

                    // 팔로우 여부 확인
                    final bool isFollowing = followers.contains(currentAuthUser?.uid);

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // 프로필 이미지
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: (profileImageUrl != null)
                                    ? NetworkImage(profileImageUrl)
                                    : const AssetImage('assets/images/default_user_image.png') as ImageProvider,
                                backgroundColor: Colors.grey[300],
                              ),
                              const SizedBox(width: 20),

                              // 스탯 (게시물, 팔로워, 팔로잉)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn(context, "게시물", posts.length), // 클릭 안됨

                                    // 팔로워 클릭 -> 리스트 이동
                                    _buildStatColumn(context, "팔로워", followers.length, onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserListScreen(
                                            title: "팔로워",
                                            userIds: followers,
                                          ),
                                        ),
                                      );
                                    }),

                                    // 팔로잉 클릭 -> 리스트 이동
                                    _buildStatColumn(context, "팔로잉", following.length, onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserListScreen(
                                            title: "팔로잉",
                                            userIds: following,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 닉네임 & 버튼
                          Row(
                            children: [
                              Text(username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Spacer(),

                              // 버튼 분기 처리
                              if (isMe)
                                OutlinedButton(
                                  onPressed: () {
                                    // 프로필 수정 화면으로 이동
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                                    );
                                  },
                                  child: const Text("프로필 수정"),
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                                    foregroundColor: isFollowing ? Colors.black : Colors.white,
                                  ),
                                  onPressed: () {
                                    context.read<MyAuthProvider>().toggleFollow(targetUserId);
                                  },
                                  child: Text(isFollowing ? "언팔로우" : "팔로우"),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: Divider()),

              // 6. 게시물 그리드
              if (posts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(child: Text("게시물이 없습니다.")),
                  ),
                )
              else
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final post = posts[index];
                      return GestureDetector(
                        onTap: () {
                          // 상세 페이지 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PostDetailScreen(post: post)),
                          );
                        },
                        child: Image.network(post.imageUrl, fit: BoxFit.cover),
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

  // 스탯 표시 헬퍼 (onTap 지원)
  Widget _buildStatColumn(BuildContext context, String label, int count, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onTap != null ? Colors.black87 : Colors.grey, // 클릭 가능하면 진하게
              fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}