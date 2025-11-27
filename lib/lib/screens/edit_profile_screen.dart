// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/providers/my_auth_provider.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/loading_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  File? _pickedImage;
  String? _currentImageUrl; // 기존 이미지 URL (보여주기용)

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  // 기존 정보 불러오기
  void _loadCurrentUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _usernameController.text = data['username'] ?? '';
      setState(() {
        _currentImageUrl = data['profileImageUrl'];
      });
    }
  }

  // 이미지 선택
  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<MyAuthProvider>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("프로필 수정"),
            actions: [
              TextButton(
                onPressed: () async {
                  if (_usernameController.text.trim().isEmpty) return;

                  // 프로필 업데이트 실행
                  bool success = await context.read<MyAuthProvider>().updateProfile(
                    newUsername: _usernameController.text.trim(),
                    newProfileImage: _pickedImage,
                  );

                  if (success && context.mounted) {
                    Navigator.pop(context); // 성공 시 뒤로가기
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("프로필이 수정되었습니다.")),
                    );
                  }
                },
                child: const Text("저장", style: TextStyle(color: Colors.blue, fontSize: 16)),
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 프로필 이미지 선택 영역
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        // 1. 새 이미지를 골랐으면 그걸 보여줌
                        // 2. 아니면 기존 URL 이미지
                        // 3. 둘 다 없으면 기본 이미지
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : (_currentImageUrl != null
                            ? NetworkImage(_currentImageUrl!)
                            : const AssetImage('assets/images/default_user_image.png')) as ImageProvider,
                      ),
                      // 카메라 아이콘 배지
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 닉네임 입력
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "닉네임",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 로딩 오버레이
        if (authProvider.state == ViewState.Loading)
          const LoadingOverlay(),
      ],
    );
  }
}