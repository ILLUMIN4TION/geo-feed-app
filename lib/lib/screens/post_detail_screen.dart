// lib/screens/post_detail_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context, {"reopenSheet": true});
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
                  Navigator.pop(context, updatedPost); //  반드시 유지
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
      
              CachedNetworkImage(
                imageUrl: widget.post.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (c, _) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (c, _, __) => const Icon(Icons.error),
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
