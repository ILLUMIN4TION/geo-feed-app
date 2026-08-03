import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:io'; 
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geofeed/screens/camera_recipe_screen.dart';
import 'package:geofeed/utils/theme.dart';
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
          title: Text("포스트 상세 정보", style: TextStyle(color: AppTheme.textPrimary)),
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
                    SnackBar(content: Text("수정 완료!"), backgroundColor: AppTheme.successColor),
                  );
                }
              },
              child: Text(
                "완료",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
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
                  tag: imageUrl,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      memCacheWidth: 1080,
                      placeholder: (c, _) => Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor))),
                      errorWidget: (c, _, __) => Icon(Icons.error_outline, size: 48, color: AppTheme.textHint),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isEditing
                    ? TextField(
                  controller: _captionController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: "내용을 입력하세요",
                    filled: true,
                    fillColor: AppTheme.bgSurface.withOpacity(0.5),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: null,
                  autofocus: true,
                )
                    : Text(
                  widget.post.caption.isEmpty
                      ? "(캡션 없음)"
                      : widget.post.caption,
                  style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
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
                      child: const Text("취소", style: TextStyle(color: AppTheme.textHint)),
                    ),
                  ),
                ),

              const Divider(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("촬영 정보 (EXIF)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: exifWidgets.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "이 사진에는 촬영 정보가 없습니다.",
                    style: TextStyle(color: AppTheme.textHint),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("포토스팟 위치", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),

              widget.post.location == null
                  ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("이 사진에는 위치 정보가 없습니다.", style: TextStyle(color: AppTheme.textHint)),
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
                  gestureRecognizers: {}, 
                  liteModeEnabled: Platform.isAndroid,
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: AppTheme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.camera_enhance),
                    label: Text(
                      "이 설정값으로 촬영하기 (Beta)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CameraRecipeScreen(targetPost: widget.post)),
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

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        child: Container(
          width: screenSize.width,
          height: screenSize.height,
          alignment: Alignment.center,
          child: Hero(
            tag: imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
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