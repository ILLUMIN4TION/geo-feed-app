import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/screens/edit_profile_screen.dart';
import 'package:geofeed/screens/liked_posts_screen.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/screens/user_list_screen.dart';
import 'package:geofeed/utils/theme.dart';
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
        title: Text(isMe ? "내 프로필" : "프로필", style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
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
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)));
          }
          if (postSnapshot.hasError) {
            return Center(child: Text("데이터 오류: ${postSnapshot.error}", style: TextStyle(color: AppTheme.textSecondary)));
          }

          final posts = postSnapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: userStream,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor))),
                      );
                    }
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final username = userData['username'] ?? '알 수 없음';
                    final profileImageUrl = userData['profileImageUrl'];

                    final List followers = userData['followers'] ?? [];
                    final List following = userData['following'] ?? [];

                    final bool isFollowing = followers.contains(currentAuthUser?.uid);

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.bgSurface,
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: (profileImageUrl != null)
                                    ? ClipOval(child: Image.network(profileImageUrl, fit: BoxFit.cover))
                                    : Icon(Icons.person, size: 40, color: AppTheme.textHint),
                              ),
                              const SizedBox(width: 20),

                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn(context, "게시물", posts.length),
                                    _buildStatColumn(context, "팔로워", followers.length, onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => UserListScreen(title: "팔로워", userIds: followers)),
                                      );
                                    }),
                                    _buildStatColumn(context, "팔로잉", following.length, onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => UserListScreen(title: "팔로잉", userIds: following)),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Text(username, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              const Spacer(),

                              if (isMe)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                                    );
                                  },
                                  child: Text("프로필 수정", style: TextStyle(color: AppTheme.primaryColor)),
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing ? AppTheme.borderLight : AppTheme.primaryColor,
                                    foregroundColor: isFollowing ? AppTheme.textSecondary : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

              if (posts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(child: Text("게시물이 없습니다.", style: TextStyle(color: Colors.grey))),
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
                            MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
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

  Widget _buildStatColumn(BuildContext context, String label, int count, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onTap != null ? AppTheme.primaryColor : AppTheme.textHint,
              fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}