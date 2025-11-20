import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/screens/profile_screen.dart';
import 'package:geofeed/widgets/location_text.dart';
import 'package:provider/provider.dart';

class UserInfoHeader extends StatefulWidget {
  final Post post;
  // (신규) 상세 화면에서 직접 수정/삭제 후 처리를 위한 콜백
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteFinished;

  const UserInfoHeader({
    super.key,
    required this.post,
    this.onEdit,
    this.onDeleteFinished,
  });

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

  // (핵심) 리스트뷰 재사용 시 데이터 갱신을 위해 didUpdateWidget 사용
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
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey),
            title: Text("..."),
            subtitle: Text("..."),
          );
        }

        // 데이터가 없거나 에러 발생 시
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
          // 1. 프로필 화면으로 이동
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: widget.post.userId),
              ),
            );
          },
          // 2. 프로필 이미지
          leading: CircleAvatar(
            backgroundImage: (profileImageUrl != null)
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/images/default_user_image.png')
            as ImageProvider,
            backgroundColor: Colors.grey[200],
          ),
          // 3. 닉네임
          title: Text(username,
              style: const TextStyle(fontWeight: FontWeight.bold)),

          // 4. 위치 정보 (LocationText 위젯 사용)
          subtitle: widget.post.location != null
              ? LocationText(location: widget.post.location!)
              : const Text("위치 정보 없음",
              style: TextStyle(fontSize: 12, color: Colors.grey)),

          // 5. 작성자 본인일 경우 '더보기(...)' 버튼 표시
          trailing: (FirebaseAuth.instance.currentUser?.uid == widget.post.userId)
              ? IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showMoreOptions(context),
          )
              : null,
        );
      },
    );
  }

  // 옵션 바텀 시트
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정하기'),
                onTap: () {
                  Navigator.pop(ctx); // 시트 닫기

                  // (수정) 콜백이 있으면(상세화면) 콜백 실행, 없으면(피드) 다이얼로그 실행
                  if (widget.onEdit != null) {
                    widget.onEdit!();
                  } else {
                    _showEditDialog(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제하기', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx); // 시트 닫기
                  _showDeleteConfirmDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("게시물 삭제"),
        content: const Text("정말로 이 게시물을 삭제하시겠습니까?\n복구할 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // 다이얼로그 닫기

              // Provider를 통해 삭제 실행
              bool success = await context.read<PostProvider>().deletePost(
                  widget.post.id,
                  widget.post.imageUrl
              );

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("게시물이 삭제되었습니다.")),
                );

                // (신규) 삭제 완료 후 추가 작업(화면 닫기 등) 실행
                if (widget.onDeleteFinished != null) {
                  widget.onDeleteFinished!();
                }
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 수정 입력 다이얼로그 (피드 화면에서 사용)
  void _showEditDialog(BuildContext context) {
    final TextEditingController controller =
    TextEditingController(text: widget.post.caption);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("게시물 수정"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "새로운 캡션을 입력하세요"),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () async {
              final newCaption = controller.text.trim();
              Navigator.pop(ctx); // 다이얼로그 닫기

              await context.read<PostProvider>().updatePost(
                  widget.post.id,
                  newCaption
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("게시물이 수정되었습니다.")),
                );
              }
            },
            child: const Text("저장"),
          ),
        ],
      ),
    );
  }
}