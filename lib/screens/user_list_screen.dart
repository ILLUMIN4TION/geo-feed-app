// lib/screens/user_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/screens/profile_screen.dart';

class UserListScreen extends StatelessWidget {
  final String title;
  final List<dynamic> userIds; // 팔로워/팔로잉 UID 리스트

  const UserListScreen({
    super.key,
    required this.title,
    required this.userIds,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: userIds.isEmpty
          ? const Center(child: Text("사용자가 없습니다."))
          : ListView.builder(
        itemCount: userIds.length,
        itemBuilder: (context, index) {
          final String uid = userIds[index];

          // 각 유저 정보를 개별적으로 가져옴 (MVP 방식)
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(title: Text("로딩 중..."));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data == null) return const SizedBox.shrink();

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (data['profileImageUrl'] != null)
                      ? NetworkImage(data['profileImageUrl'])
                      : const AssetImage('assets/images/default_user_image.png') as ImageProvider,
                ),
                title: Text(data['username'] ?? '알 수 없음'),
                onTap: () {
                  // 리스트에서 유저 클릭 시 해당 프로필로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: uid),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}