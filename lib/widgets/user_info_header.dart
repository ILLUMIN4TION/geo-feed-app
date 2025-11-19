import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/screens/profile_screen.dart';
import 'package:geofeed/widgets/location_text.dart';

class UserInfoHeader extends StatefulWidget {
  final Post post;
  const UserInfoHeader({super.key, required this.post});

  @override
  State<UserInfoHeader> createState() => _UserInfoHeaderState();
}

class _UserInfoHeaderState extends State<UserInfoHeader> {
  late Future<DocumentSnapshot> _userFuture;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // 데이터 로드 로직 분리
  void _loadUser() {
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.userId)
        .get();
  }

  // (핵심) 부모 위젯(PostCard)이 새로운 post 데이터를 주면 감지해서 업데이트
  @override
  void didUpdateWidget(covariant UserInfoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 유저 ID가 바뀌었다면 데이터 새로고침
    if (oldWidget.post.userId != widget.post.userId) {
      _loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey),
            title: Text("..."),
            subtitle: Text("..."),
          );
        }

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
          title: Text(username,
              style: const TextStyle(fontWeight: FontWeight.bold)),

          // 위치 정보 표시
          subtitle: widget.post.location != null
              ? LocationText(location: widget.post.location!)
              : const Text("위치 정보 없음",
              style: TextStyle(fontSize: 12, color: Colors.grey)),

          trailing: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () { /* 옵션 메뉴 */ },
          ),
        );
      },
    );
  }
}