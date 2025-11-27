// // lib/widgets/cluster_preview_sheet.dart
//
// import 'package:flutter/material.dart';
// import 'package:geofeed/models/post.dart';
// import 'package:geofeed/screens/post_detail_screen.dart';
//
// class ClusterPreviewSheet extends StatelessWidget {
//   final List<Post> posts;
//
//   const ClusterPreviewSheet({super.key, required this.posts});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 400,
//       padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 1. 헤더 (타이틀 및 닫기 버튼)
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 "이 지역의 포스트 (${posts.length}개)",
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.close),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ],
//           ),
//           const Divider(),
//
//           // 2. 앨범 그리드 뷰
//           Expanded(
//             child: GridView.builder(
//               padding: const EdgeInsets.only(bottom: 20),
//               itemCount: posts.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 3, // 한 줄에 3개
//                 crossAxisSpacing: 4,
//                 mainAxisSpacing: 4,
//               ),
//               itemBuilder: (context, index) {
//                 final post = posts[index];
//                 return GestureDetector(
//                   onTap: () {
//                     // 사진 클릭 시 상세 페이지로 이동
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => PostDetailScreen(post: post),
//                       ),
//                     );
//                   },
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(4),
//                     child: Image.network(
//                       post.imageUrl,
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Container(color: Colors.grey[300]);
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }