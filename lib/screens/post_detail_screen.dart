import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:io'; 
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geofeed/screens/camera_recipe_screen.dart';
import 'package:provider/provider.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isEditing = false;
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.post.caption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> exifWidgets = widget.post.exifData.entries
        .where((entry) => entry.value != null && entry.value.toString().isNotEmpty)
        .map((entry) => Chip(label: Text("${entry.key}: ${entry.value}")))
        .toList();

    final Set<Marker> markers = {};
    if (widget.post.location != null) {
      markers.add(
        Marker(
          markerId: MarkerId(widget.post.id),
          position: LatLng(
            widget.post.location!.latitude,
            widget.post.location!.longitude,
          ),
        ),
      );
    }

    final imageUrl = widget.post.getImageUrl(useThumbnail: false);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context, {"reopenPreview": true});
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("포스트 상세 정보"),
          actions: _isEditing
              ? [
            TextButton(
              onPressed: () async {
                final updatedPost =
                await context.read<PostProvider>().updatePost(
                  widget.post.id,
                  _captionController.text.trim(),
                );

                setState(() {
                  _isEditing = false;
                });

                if (mounted) {
                  Navigator.pop(context, updatedPost);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("수정 완료!")),
                  );
                }
              },
              child: const Text(
                "완료",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          ]
              : null,
        ),

        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserInfoHeader(
                post: widget.post,
                onEdit: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                onDeleteFinished: () {
                  Navigator.of(context).pop(null);
                },
              ),

              // ★ [수정됨] 이미지 클릭 시 전체 화면 뷰어로 이동
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
                    ),
                  );
                },
                child: Hero(
                  // Hero 태그를 사용하여 화면 전환 시 이미지가 자연스럽게 확대되는 효과 적용
                  tag: imageUrl,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl, // 원본 사용
                    fit: BoxFit.cover,
                    width: double.infinity,
                    // 메모리 최적화 (뷰어용이 아니므로 적당히 제한)
                    memCacheWidth: 1080,
                    placeholder: (c, _) =>
                    const Center(child: CircularProgressIndicator()),
                    errorWidget: (c, _, __) => const Icon(Icons.error),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isEditing
                    ? TextField(
                  controller: _captionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "내용을 입력하세요",
                    filled: true,
                  ),
                  maxLines: null,
                  autofocus: true,
                )
                    : Text(
                  widget.post.caption.isEmpty
                      ? "(캡션 없음)"
                      : widget.post.caption,
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _captionController.text = widget.post.caption;
                        });
                      },
                      child:
                      const Text("취소", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ),

              const Divider(),

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("촬영 정보 (EXIF)",
                    style: Theme.of(context).textTheme.titleMedium),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: exifWidgets.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      "이 사진에는 촬영 정보가 없습니다.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
                    : Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: exifWidgets,
                ),
              ),

              const Divider(),

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("포토스팟 위치",
                    style: Theme.of(context).textTheme.titleMedium),
              ),

              widget.post.location == null
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text("이 사진에는 위치 정보가 없습니다.")),
              )
                  : Container(
                height: 250,
                margin: const EdgeInsets.all(16.0),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.post.location!.latitude,
                      widget.post.location!.longitude,
                    ),
                    zoom: 15,
                  ),
                  markers: markers,
                  // 스크롤 뷰 안에 지도가 있으므로 제스처 충돌 방지
                  gestureRecognizers: {}, 
                  liteModeEnabled: Platform.isAndroid, // 안드로이드 성능 최적화
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.yellowAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_enhance),
                    label: const Text(
                      "이 설정값으로 촬영하기 (Beta)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CameraRecipeScreen(targetPost: widget.post),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ★ [추가됨] 전체 화면 이미지 뷰어 위젯
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // 화면 전체 크기를 가져옵니다.
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black, // 검은 배경
      extendBodyBehindAppBar: true, // 앱바 뒤로 내용 확장
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 기존 Center 위젯을 제거하고 InteractiveViewer를 body에 바로 배치
      body: InteractiveViewer(
        panEnabled: true, // 이동 가능
        minScale: 0.5,    // 최소 축소 배율
        maxScale: 4.0,    // 최대 확대 배율
        
        // ★ [핵심 변경] InteractiveViewer의 자식 영역을 화면 전체 크기로 설정
        child: Container(
          width: screenSize.width,
          height: screenSize.height,
          alignment: Alignment.center, // 컨테이너 내부에서 이미지를 중앙 정렬
          child: Hero(
            tag: imageUrl, // 상세 페이지와 동일한 태그로 애니메이션 연결
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain, // 비율 유지하며 화면 안에 다 들어오게 (초기 상태)
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.error,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
      ),
    );
  }
}