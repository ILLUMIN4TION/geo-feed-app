// lib/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geofeed/screens/camera_recipe_screen.dart';
import 'package:provider/provider.dart';

// 1. StatefulWidget으로 변경 (수정 모드 상태 관리를 위해)
class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isEditing = false; // 수정 모드 상태
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
    // EXIF 위젯 생성
    final List<Widget> exifWidgets = widget.post.exifData.entries
        .where((entry) => entry.value != null && entry.value.toString().isNotEmpty)
        .map((entry) => Chip(label: Text("${entry.key}: ${entry.value}")))
        .toList();

    // 지도 마커
    final Set<Marker> markers = {};
    if (widget.post.location != null) {
      markers.add(
        Marker(
          markerId: MarkerId(widget.post.id),
          position: LatLng(widget.post.location!.latitude, widget.post.location!.longitude),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("포스트 상세 정보"),
        // (신규) 수정 모드일 때 상단에 '저장' 버튼 표시
        actions: _isEditing
            ? [
          TextButton(
            onPressed: () async {
              // 수정 내용 저장
              await context.read<PostProvider>().updatePost(
                widget.post.id,
                _captionController.text.trim(),
              );
              setState(() {
                _isEditing = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("수정 완료!")),
                );
              }
            },
            child: const Text("완료", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ]
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. UserInfoHeader에 콜백 전달
            UserInfoHeader(
              post: widget.post,
              // (핵심) 수정 버튼 누르면 -> 수정 모드 진입
              onEdit: () {
                setState(() {
                  _isEditing = true;
                });
              },
              // (핵심) 삭제 완료되면 -> 화면 닫기(Pop)
              onDeleteFinished: () {
                Navigator.of(context).pop();
              },
            ),

            Image.network(
              widget.post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

            // 3. 캡션 영역 (수정 모드에 따라 분기)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isEditing
                  ? TextField( // 수정 모드: 입력창
                controller: _captionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "내용을 입력하세요",
                  filled: true,
                ),
                maxLines: null,
                autofocus: true, // 바로 키보드 올라오게
              )
                  : Text( // 일반 모드: 텍스트
                widget.post.caption.isEmpty ? "(캡션 없음)" : widget.post.caption,
                style: const TextStyle(fontSize: 16),
              ),
            ),

            // (신규) 수정 모드일 때 취소 버튼 표시
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _captionController.text = widget.post.caption; // 원복
                      });
                    },
                    child: const Text("취소", style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),

            const Divider(),

            // ... (이하 EXIF 및 지도 코드는 기존과 동일)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("촬영 정보 (EXIF)", style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: exifWidgets.isEmpty
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text("이 사진에는 촬영 정보가 없습니다.", style: TextStyle(color: Colors.grey))),
              )
                  : Wrap(spacing: 8.0, runSpacing: 4.0, children: exifWidgets),
            ),
            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("포토스팟 위치", style: Theme.of(context).textTheme.titleMedium),
            ),
            (widget.post.location == null)
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
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
              ),
            ),

            const SizedBox(height: 20),

            // (신규) 따라 찍기 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87, // 진한 회색/검정 배경
                    foregroundColor: Colors.yellowAccent, // 노란색 텍스트 (강조)
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
                        builder: (context) => CameraRecipeScreen(targetPost: widget.post),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 50), // 하단 여백
          ],
        ),
      ),
    );
  }
}