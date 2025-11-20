import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/confirm_upload_screen.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/loading_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController = TextEditingController();
    final uploadProvider = context.watch<UploadProvider>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("새 게시물"),
            actions: [
              // 로딩 상태가 아닐 때만 '다음' 버튼 활성화
              if (uploadProvider.state != ViewState.Loading)
                TextButton(
                  onPressed: () async {
                    // 키보드 숨기기
                    FocusScope.of(context).unfocus();

                    // 'prepare' 메서드 호출
                    bool success = await context.read<UploadProvider>().prepareUploadData(
                      caption: captionController.text.trim(),
                    );

                    // Provider 내부에서 에러 발생 시 setState(ViewState.Error)를 호출하므로
                    // success가 false라면 로딩 상태는 이미 해제되었을 것입니다.
                    // 따라서 별도의 finally 블록이나 추가적인 상태 변경은 필요하지 않습니다.

                    if (success && context.mounted) {
                      // 확인 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConfirmUploadScreen()),
                      );
                    } else if (!success && context.mounted) {
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
                    "다음",
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
                  const SizedBox(height: 10),

                  // 이미지 미리보기 및 선택 영역
                  GestureDetector(
                    onTap: () {
                      // 선택 팝업 띄우기
                      _showImageSourceActionSheet(context, uploadProvider);
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
        ),

        // 로딩 중일 때 오버레이 표시 (Provider 상태에 따라 제어)
        if (uploadProvider.state == ViewState.Loading)
          const LoadingOverlay(),
      ],
    );
  }

  // 갤러리/카메라 선택 바텀 시트
  void _showImageSourceActionSheet(BuildContext context, UploadProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(ctx);
                // 갤러리 소스 전달
                context.read<UploadProvider>().pickImageForPreview(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                // 카메라 소스 전달
                context.read<UploadProvider>().pickImageForPreview(source: ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}