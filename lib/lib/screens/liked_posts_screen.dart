// lib/screens/liked_posts_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/screens/post_detail_screen.dart';

class LikedPostsScreen extends StatelessWidget {
  const LikedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const Scaffold(body: Center(child: Text("로그인이 필요합니다.")));

    return Scaffold(
      appBar: AppBar(title: const Text("좋아요한 게시물")),
      body: StreamBuilder<QuerySnapshot>(
        // 쿼리: likes 배열에 내 ID(myUid)가 포함된 게시물 찾기
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('likes', arrayContains: myUid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // 복합 색인이 필요할 수 있음 (콘솔 확인 필요)
            return Center(child: Text("데이터를 불러오는데 실패했습니다.\n${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("좋아요한 게시물이 없습니다."));
          }

          final posts = docs.map((doc) => Post.fromFirestore(doc)).toList();

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(post: posts[index]),
                    ),
                  );
                },
                child: Image.network(posts[index].imageUrl, fit: BoxFit.cover),
              );
            },
          );
        },
      ),
    );
  }
}