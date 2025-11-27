import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/widgets/expandable_caption.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:provider/provider.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    // Post 모델의 likes 리스트를 확인하여 좋아요 상태 결정
    final bool isLiked = post.likes.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      elevation: 1.0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용자 정보 헤더
          UserInfoHeader(post: post),

          // 이미지 + EXIF
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
              );
            },
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  width: double.infinity,
                  height: 350,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(width: double.infinity, height: 350, color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 350,
                    color: Colors.grey[200],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        SizedBox(height: 8),
                        Text("이미지를 불러올 수 없습니다.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                _buildExifOverlay(context, post), // post 객체 전체 전달
              ],
            ),
          ),

          // 좋아요 + 북마크
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: () {
                  // Provider의 toggleLike 호출 (낙관적 업데이트 적용됨)
                  context.read<PostProvider>().toggleLike(post.id, post.likes);
                },
              ),
              // 좋아요 수 표시 (즉시 반영됨)
              Text("${post.likes.length}명", style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {}),
            ],
          ),

          // 캡션
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: post.caption.isEmpty
                ? const SizedBox.shrink()
                : ExpandableCaption(text: post.caption),
          ),
        ],
      ),
    );
  }

  Widget _buildExifOverlay(BuildContext context, Post post) {
    final exifData = post.exifData;
    final apertureText = exifData['Aperture']?.toString() ?? 'N/A';

    // formattedShutterSpeed Getter 사용
    final shutterText = post.formattedShutterSpeed;

    final isoRaw = exifData['ISO'];
    final isoText = (isoRaw == null) ? 'N/A' : 'ISO ${isoRaw.toString()}';
    final focalLengthText = exifData['FocalLength']?.toString() ?? 'N/A';
    final modelText = exifData['Model']?.toString() ?? '';

    final bool noExifData = apertureText == 'N/A' &&
        shutterText == 'N/A' &&
        isoText == 'N/A' &&
        focalLengthText == 'N/A' &&
        modelText.isEmpty;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (noExifData)
              const Text(
                "촬영 정보 없음",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                ),
              )
            else ...[
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _exifIconText(Icons.camera_alt_outlined, apertureText),
                  _exifIconText(Icons.shutter_speed_outlined, shutterText),
                  _exifIconText(Icons.iso_outlined, isoText),
                  _exifIconText(Icons.center_focus_weak_outlined, focalLengthText),
                ],
              ),
              if (modelText.isNotEmpty && modelText != 'N/A')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    modelText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _exifIconText(IconData icon, String text) {
    if (text == 'N/A' || text.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18, shadows: const [
          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
        ]),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
          ),
        ),
      ],
    );
  }
}