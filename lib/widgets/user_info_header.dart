import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart'; // 1. Post 모델 임포트
import 'package:geofeed/widgets/location_text.dart'; // 2. LocationText 임포트

class UserInfoHeader extends StatelessWidget {
  // 3. userId 대신 Post 객체 전체를 받도록 수정
  final Post post; 
  const UserInfoHeader({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // 4. userId는 post 객체에서 가져옴
    final userFuture =
        FirebaseFirestore.instance.collection('users').doc(post.userId).get();

    return FutureBuilder<DocumentSnapshot>(
      future: userFuture,
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey),
            title: Text("..."),
            subtitle: Text("..."),
          );
        }

        // 데이터가 없거나 에러 발생 시
        if (!snapshot.hasData || snapshot.hasError) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey),
            title: Text("알 수 없는 사용자"),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final username = userData['username'] ?? '사용자';
        final profileImageUrl = userData['profileImageUrl'];

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (profileImageUrl != null)
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/images/default_user_image.png')
                    as ImageProvider,
            backgroundColor: Colors.grey[200],
          ),
          title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          
          // 5. (수정) subtitle에 LocationText 위젯 적용
          subtitle: post.location != null
              ? LocationText(location: post.location!) // 위치가 있으면 주소 변환
              : const Text("위치 정보 없음", style: TextStyle(fontSize: 12, color: Colors.grey)), // 위치가 없으면 텍스트 표시

          trailing: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () { /* TODO: 옵션 메뉴 */ },
          ),
        );
      },
    );
  }
}