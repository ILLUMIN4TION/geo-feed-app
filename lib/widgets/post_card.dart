import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp 타입 처리를 위해 필요할 수 있음
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

  // ★ 날짜 포맷팅 헬퍼 함수
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      // 7일 이상 지난 게시물은 날짜로 표시 (YYYY.MM.DD)
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
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

          // 이미지 + EXIF (썸네일 사용)
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
                  // ★ [수정] 썸네일 대신 원본 이미지를 사용 (useThumbnail: false)
                  // 메인 피드는 크게 보여줘야 하므로 고화질 원본이 필요함
                  imageUrl: post.getImageUrl(useThumbnail: false), 
                  
                  width: double.infinity,
                  height: 350,
                  fit: BoxFit.cover,

                  // ★ [메모리 최적화] 원본을 불러오더라도, 화면에 표시할 때는 
                  // 1080px(FHD 너비) 정도만 메모리에 올리면 충분함.
                  // S24 원본(4000px 이상)을 그대로 메모리에 올리는 것을 방지.
                  memCacheWidth: 1080,
                  
                  // 디스크 캐시도 1080 정도면 확대해서 봐도 충분히 선명함
                  maxWidthDiskCache: 1080,

                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: double.infinity,
                      height: 350,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 350,
                    color: Colors.grey[200],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        SizedBox(height: 8),
                        Text(
                          "이미지를 불러올 수 없습니다.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildExifOverlay(context, post),
              ],
            ),
          ),

          // 하단 정보 (좋아요 + 타임스탬프)
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: () {
                  context.read<PostProvider>().toggleLike(post.id, post.likes);
                },
              ),
              Text(
                "${post.likes.length}명",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              
              const Spacer(), // 남은 공간을 차지하여 타임스탬프를 오른쪽으로 밈

              // ★ 타임스탬프 추가 부분
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  _formatTimestamp(post.timestamp),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // 캡션
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0), // 하단 패딩 살짝 조정
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
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    )
                  ],
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
                  _exifIconText(
                      Icons.center_focus_weak_outlined, focalLengthText),
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
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        )
                      ],
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
            shadows: [
              Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)
            ],
          ),
        ),
      ],
    );
  }
}