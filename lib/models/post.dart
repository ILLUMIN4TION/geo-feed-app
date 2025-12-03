import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String imageUrl;         // 원본 이미지
  final String? thumbnailUrl;    // 썸네일 이미지 (800x800)
  final String caption;
  final GeoPoint? location;
  final Timestamp timestamp;
  final List<String> likes;
  final List<String> tags;
  final Map<String, dynamic> exifData;

  Post({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.location,
    required this.timestamp,
    required this.exifData,
    required this.likes,
    required this.tags,
  });

  // 화면에 따라 적절한 이미지 URL 반환
  String getImageUrl({bool useThumbnail = true}) {
    if (useThumbnail && thumbnailUrl != null) {
      return thumbnailUrl!;
    }
    return imageUrl;
  }

  // EXIF 파싱 Getter들
  double? get shutterSpeedValue {
    final text = exifData['ShutterSpeed']?.toString();
    if (text == null || text == 'N/A') return null;
    try {
      String cleanText = text.replaceAll('s', '');
      if (cleanText.contains('/')) {
        final parts = cleanText.split('/');
        return double.parse(parts[0]) / double.parse(parts[1]);
      }
      return double.tryParse(cleanText);
    } catch (e) {
      return null;
    }
  }

  String get formattedShutterSpeed {
    final val = shutterSpeedValue;
    if (val == null) return 'N/A';

    if (val < 1.0) {
      final denominator = (1 / val).round();
      return '1/${denominator}s';
    } else {
      return '${val.toStringAsFixed(1)}s';
    }
  }

  double? get apertureValue {
    final text = exifData['Aperture']?.toString();
    if (text == null || text == 'N/A') return null;
    try {
      return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return null;
    }
  }

  int? get isoValue {
    final val = exifData['ISO'];
    if (val is int) return val;
    if (val is String) return int.tryParse(val);
    return null;
  }

  double? get focalLengthValue {
    final text = exifData['FocalLength']?.toString();
    if (text == null || text == 'N/A') return null;
    try {
      return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return null;
    }
  }

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],  // 새로 추가
      caption: data['caption'] ?? '',
      location: data['location'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      exifData: Map<String, dynamic>.from(data['exifData'] ?? {}),
      likes: List<String>.from(data['likes'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Post copyWith({
    String? id,
    String? userId,
    String? imageUrl,
    String? thumbnailUrl,
    String? caption,
    GeoPoint? location,
    Timestamp? timestamp,
    List<String>? likes,
    List<String>? tags,
    Map<String, dynamic>? exifData,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      exifData: exifData ?? this.exifData,
      likes: likes ?? this.likes,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'location': location,
      'timestamp': timestamp,
      'exifData': exifData,
      'likes': likes,
      'tags': tags,
    };
  }
}