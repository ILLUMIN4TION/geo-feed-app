// lib/widgets/user_info_header.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/screens/profile_screen.dart';
import 'package:geofeed/widgets/location_text.dart';

// 1. (수정) StatefulWidget으로 변경
class UserInfoHeader extends StatefulWidget {
  final Post post;
  const UserInfoHeader({super.key, required this.post});

  @override
  State<UserInfoHeader> createState() => _UserInfoHeaderState();
}

class _UserInfoHeaderState extends State<UserInfoHeader> {
  // 2. (신규) Future를 상태로 저장
  late Future<DocumentSnapshot> _userFuture;

  @override
  void initState() {
    super.initState();
    // 3. (핵심) 위젯이 처음 생성될 때 '딱 한 번만' 데이터를 요청함
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.userId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture, // 4. 저장해둔 Future 사용 (재호출 안 함)
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey),
            title: Text("..."),
            subtitle: Text("..."),
          );
        }

        // 에러 또는 데이터 없음
        if (snapshot.hasError || !snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey),
            title: Text("알 수 없는 사용자"),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final username = userData['username'] ?? '사용자';
        final profileImageUrl = userData['profileImageUrl'];

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                // post.userId를 넘겨줌 (내 아이디면 내 프로필, 남이면 남의 프로필이 됨)
                builder: (context) => ProfileScreen(userId: widget.post.userId),
              ),
            );
          },
          leading: CircleAvatar(
            backgroundImage: (profileImageUrl != null)
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/images/default_user_image.png')
            as ImageProvider,
            backgroundColor: Colors.grey[200],
          ),
          title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),

          // 위치 정보 (LocationText는 이미 StatefulWidget이라 깜빡이지 않음)
          subtitle: widget.post.location != null
              ? LocationText(location: widget.post.location!)
              : const Text("위치 정보 없음", style: TextStyle(fontSize: 12, color: Colors.grey)),

          trailing: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () { /* TODO: 옵션 메뉴 */ },
          ),
        );
      },
    );
  }
}