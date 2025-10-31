// lib/screens/upload_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:provider/provider.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController = TextEditingController();
    final uploadProvider = context.watch<UploadProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("새 게시물"),
        actions: [
          // 2. 로딩 상태가 아닐 때만 '업로드' 버튼 활성화
          if (uploadProvider.state != ViewState.Loading)
            TextButton(
              onPressed: () async {
                // 3. 업로드 프로바이더 실행
                bool success = await context.read<UploadProvider>().pickAndUploadImage(
                      caption: captionController.text.trim(),
                      // TODO: (W4) GPS 위치도 함께 전달해야 함
                    );

                if (success && context.mounted) {
                  // 4. 성공 시 홈 화면으로 복귀
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("업로드 성공!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                } else if (!success && context.mounted) {
                  // 5. 실패 시 에러 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.read<UploadProvider>().errorMessage ?? "업로드 실패"
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text(
                "공유",
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
        child: Column(
          children: [
            // 1. 로딩 중일 때 프로그레스 바 표시
            if (uploadProvider.state == ViewState.Loading)
              const LinearProgressIndicator(),
            
            const SizedBox(height: 10),
            
            // 캡션 입력 필드
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                hintText: "문구 입력...",
                border: InputBorder.none,
              ),
              maxLines: 5, // 여러 줄 입력 가능
            ),
            
            const Divider(),
            
            // TODO: (W3) image_picker로 선택한 이미지 미리보기 위젯
            // Container(
            //   height: 200,
            //   width: double.infinity,
            //   color: Colors.grey[300],
            //   child: const Center(child: Text("이미지 미리보기 영역")),
            // )
          ],
        ),
      ),
    );
  }
}