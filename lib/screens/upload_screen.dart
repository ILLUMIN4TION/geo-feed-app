import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/confirm_upload_screen.dart';
import 'package:geofeed/utils/theme.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/loading_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// 상태 관리를 위해 StatefulWidget으로 변경
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 화면 진입 시, 혹시 카메라 앱에 다녀오면서 앱이 재시작되었는지 확인하여 데이터 복구
    // 빌드 후에 실행하기 위해 addPostFrameCallback 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UploadProvider>().checkLostData();
    });
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("새 게시물"),
            actions: [
              if (uploadProvider.state != ViewState.Loading)
                TextButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();

                    bool success = await context.read<UploadProvider>().prepareUploadData(
                      caption: captionController.text.trim(),
                    );

                    if (success && context.mounted) {
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
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "다음",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
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
                  GestureDetector(
                    onTap: () {
                      _showImageSourceActionSheet(context);
                    },
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: uploadProvider.pickedImageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                uploadProvider.pickedImageFile!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 60, color: AppTheme.textHint.withOpacity(0.6)),
                                const SizedBox(height: 8),
                                Text("탭하여 사진 선택", style: TextStyle(color: AppTheme.textHint)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: captionController,
                    decoration: InputDecoration(
                      hintText: "문구 입력...",
                      border: InputBorder.none,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  Divider(height: 32, color: AppTheme.borderLight),
                ],
              ),
            ),
          ),
        ),
        if (uploadProvider.state == ViewState.Loading)
          const LoadingOverlay(),
      ],
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryColor, size: 20),
              title: Text('갤러리에서 선택', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<UploadProvider>().pickImageForPreview(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primaryColor, size: 20),
              title: Text('카메라로 촬영', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<UploadProvider>().pickImageForPreview(source: ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}