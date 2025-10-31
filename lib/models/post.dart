// lib/models/post.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;          // 문서 ID
  final String userId;      // 작성자 UID
  final String imageUrl;    // 스토리지에 저장된 이미지 URL
  final String caption;     // 캡션(내용)
  final GeoPoint location;    // 위치 (Firestore 지리좌표)
  final Timestamp timestamp; // 작성 시간

  // 교수님 피드백 반영 (핵심): EXIF 데이터를 Map으로 저장
  final Map<String, dynamic> exifData; 
  // 예: { "aperture": "f/2.8", "iso": 400, "shutterSpeed": "1/125" }

  Post({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.caption,
    required this.location,
    required this.timestamp,
    required this.exifData,
  });

  // Firestore에서 데이터를 읽을 때 사용할 팩토리 생성자
  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      exifData: Map<String, dynamic>.from(data['exifData'] ?? {}),
    );
  }

  // Firestore에 데이터를 쓸 때 사용할 메서드
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'caption': caption,
      'location': location,
      'timestamp': timestamp,
      'exifData': exifData,
    };
  }
}