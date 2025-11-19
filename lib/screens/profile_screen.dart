import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/screens/edit_profile_screen.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  // 1. userId를 외부에서 받을 수 있게 변경
  // 만약 null이면 '내 프로필'로  <- 이 프로필이 내 프로필인지 다른 유저의 프로필인지 확인하기 위해 필요함
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    // 2. 보여줄 대상 ID 결정 (전달받은 ID가 없으면 내 ID 사용)
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final String targetUserId = userId ?? currentAuthUser?.uid ?? "";
    final bool isMe = (currentAuthUser != null && targetUserId == currentAuthUser.uid);

    // 3. 유저 정보 스트림 (실시간 팔로워 수 반영을 위해 StreamBuilder)
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .snapshots();

    // 4. 게시물 스트림 (해당 프로필의 게시글만 표시)
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
      ),
      body: StreamBuilder<List<Post>>(
        stream: postsStream,
        builder: (context, postSnapshot) {
          //TODO ... (로딩/에러 처리는 동일, 간단히 생략)
          final posts = postSnapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                // 5. 유저 정보 헤더 (StreamBuilder로 변경)
                child: StreamBuilder<DocumentSnapshot>(
                  stream: userStream,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final username = userData['username'] ?? '알 수 없음';
                    final profileImageUrl = userData['profileImageUrl'];

                    // 팔로워/팔로잉 리스트 가져오기
                    final List followers = userData['followers'] ?? [];
                    final List following = userData['following'] ?? [];

                    // 내가 이 사람을 팔로우 중인지 확인
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
                              //TODO  스탯 (게시물, 팔로워, 팔로잉) , 내 프로필에서 내가 좋아요한 게시글을 불러올 수 있도록 해보기
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn("게시물", posts.length),
                                    _buildStatColumn("팔로워", followers.length),
                                    _buildStatColumn("팔로잉", following.length),
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

                              // 6. (핵심) 버튼 분기 처리
                              if (isMe)
                                OutlinedButton(
                                  onPressed: () {
                                    // 2. (수정) 프로필 수정 화면으로 이동
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
                                    // 팔로우 토글 실행
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

              // 게시물 그리드 (기존과 동일)
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

  // 스탯 표시 헬퍼
  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}