// lib/screens/upload_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/confirm_upload_screen.dart'; // 1. (신규) 확인 화면
import 'package:geofeed/utils/view_state.dart';
import 'package:provider/provider.dart';
import 'dart:io'; // File 사용

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController = TextEditingController();
    
    // UI 갱신(이미지 미리보기)을 위해 watch 사용
    final uploadProvider = context.watch<UploadProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("새 게시물"),
        actions: [
          // 2. 로딩 상태가 아닐 때만 '다음' 버튼 활성화
          if (uploadProvider.state != ViewState.Loading)
            TextButton(
              onPressed: () async {
                // 3. (수정) 'prepare' 메서드 호출
                bool success = await context.read<UploadProvider>().prepareUploadData(
                      caption: captionController.text.trim(),
                    );

                if (success && context.mounted) {
                  // 4. (수정) '확인 화면'으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConfirmUploadScreen()),
                  );
                } else if (!success && context.mounted) {
                  // 5. 실패 시(이미지 미선택 등) 에러 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.read<UploadProvider>().errorMessage ?? "데이터 준비 실패"
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text(
                "다음", // (수정) '공유' -> '다음'
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (uploadProvider.state == ViewState.Loading)
                const LinearProgressIndicator(),
              
              const SizedBox(height: 10),

              // (신규) 이미지 미리보기 및 선택 영역
              GestureDetector(
                onTap: () {
                  // Provider의 이미지 선택 함수 호출
                  context.read<UploadProvider>().pickImageForPreview();
                },
                child: Container(
                  height: 300,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: uploadProvider.pickedImageFile != null
                      ? Image.file(
                          uploadProvider.pickedImageFile!, // 선택된 이미지 표시
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Icon(Icons.add_a_photo, size: 60, color: Colors.grey),
                        ),
                ),
              ),
              
              const SizedBox(height: 10),
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  hintText: "문구 입력...",
                  border: InputBorder.none,
                ),
                maxLines: 5,
              ),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }
}