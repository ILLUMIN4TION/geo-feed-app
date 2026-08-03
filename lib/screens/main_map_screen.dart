// lib/screens/main_map_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geofeed/utils/theme.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/models/post_cluster_item.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/widgets/map_post_preview.dart';
import 'package:geofeed/widgets/map_cluster_gallerysheet.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:provider/provider.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  ClusterManager<PostClusterItem>? _clusterManager;

  Set<Marker> _markers = {};
  
  // 데이터 변경 감지용 캐시 변수
  List<Post>? _cachedPosts;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 12,
  );

  @override
  bool get wantKeepAlive => true;


  // 클러스터 매니저 초기화 및 데이터 주입
  void _initClusterManager(List<Post> posts) {
    final items = posts
        .where((e) => e.location != null)
        .map((p) => PostClusterItem(p))
        .toList();

    _clusterManager = ClusterManager<PostClusterItem>(
      items,
      _updateMarkers,
      markerBuilder: _markerBuilder,
      stopClusteringZoom: 17,
      levels: const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
    );

    if (_mapController != null) {
      _clusterManager?.setMapId(_mapController!.mapId);
    }
  }

  // Provider 데이터가 변경되었을 때 호출됨
  void _updateClusterItems(List<Post> posts) {
    if (_clusterManager == null) {
      _initClusterManager(posts);
      return;
    }

    final items = posts
        .where((e) => e.location != null)
        .map((p) => PostClusterItem(p))
        .toList();
    
    _clusterManager?.setItems(items);
  }

  void _updateMarkers(Set<Marker> markers) {
    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // 맵이 생성되었을 때 현재 데이터로 초기화
    if (_cachedPosts != null) {
        if (_clusterManager == null) {
            _initClusterManager(_cachedPosts!);
        }
        _clusterManager?.setMapId(controller.mapId);
        _clusterManager?.updateMap();
    }
  }

  Future<Marker> _markerBuilder(Cluster<PostClusterItem> cluster) async {
    if (cluster.isMultiple) {
      return Marker(
        markerId: MarkerId("cluster_${cluster.getId()}"),
        position: cluster.location,
        icon: await _getClusterBitmap(125, text: cluster.count.toString()),
        onTap: () => _handleClusterFlow(cluster.items.toList()),
      );
    }

    final post = cluster.items.first.post;

    return Marker(
      markerId: MarkerId(post.id),
      position: cluster.location,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onTap: () => _handleSinglePostFlow(post),
    );
  }

  // ... (Bitmap 및 Flow 관련 코드는 기존과 동일, 생략 없이 아래 포함) ...

  Future<BitmapDescriptor> _getClusterBitmap(int size, {String? text}) async {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = Colors.red;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint);

    if (text != null) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size / 3,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      )..layout();

      textPainter.paint(
        canvas,
        Offset(size / 2 - textPainter.width / 2,
            size / 2 - textPainter.height / 2),
      );
    }

    final img = await recorder.endRecording().toImage(size, size);
    final byteData = await img.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  /// 클러스터 탭 시 게시글 갤러리 → 미리보기 → 상세 화면 흐름 처리
  /// 재귀 호출 대신 단일 async 메서드 체인으로 변경하여 무한 루프 방지
  Future<void> _handleClusterFlow(List<PostClusterItem> clusterItems) async {
    if (!mounted || clusterItems.isEmpty) return;

    // 1단계: 클러스터 갤러리에서 게시글 선택
    final selectedPost = await showModalBottomSheet<Post?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapClusterGallerySheet(items: clusterItems),
    );

    if (!mounted || selectedPost == null) return;

    // 2단계: 선택된 게시글의 미리보기 → 상세 화면 흐름 처리
    await _handlePreviewFlow(selectedPost, clusterItems);
  }

  /// 게시글 미리보기 → 상세 화면 흐름 처리
  /// 최대 1회만 실행되며, 재귀 호출을 제거하여 무한 루프 방지
  /// 반환값: true = 갤러리로 돌아가야 함, false = 흐름 종료
  Future<bool> _handlePreviewFlow(Post post, [List<PostClusterItem>? clusterItems]) async {
    if (!mounted) return false;

    // 미리보기 화면 표시
    final previewResult = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapPostPreview(post: post),
    );

    if (!mounted) return false;

    // 사용자가 미리보기에서 닫기 또는 다른 게시글 선택
    if (previewResult == null) {
      // 갤러리에서 돌아갈 경우 (clusterItems가 있는 경우만)
      return clusterItems != null;
    }

    if (previewResult is String && previewResult == "backToGallery") {
      return clusterItems != null;
    }

    // Post가 아닌 경우 흐름 종료
    if (previewResult is! Post) return false;

    // 상세 화면으로 이동
    final detailResult = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: previewResult),
      ),
    );

    if (!mounted) return false;

    // 상세 화면에서 돌아온 결과 처리
    if (detailResult != null && detailResult is Map) {
      if (detailResult['reopenPreview'] == true) {
        // 미리보기를 다시 표시하려면 현재 post로 preview만 재표시 (재귀 호출 X)
        await _showPreviewOnly(previewResult);
        return clusterItems != null;
      } else if (detailResult['reopenGallery'] == true) {
        // 갤러리로 돌아가기
        return clusterItems != null;
      }
    } else if (detailResult != null && detailResult is Post) {
      // 다른 게시글로 이동한 경우 해당 게시글의 미리보기만 표시 (재귀 호출 X)
      await _showPreviewOnly(detailResult);
      return false;
    }

    return false;
  }

  /// 미리보기 화면만 단발성으로 표시 (재귀 호출 방지용 헬퍼)
  Future<void> _showPreviewOnly(Post post) async {
    if (!mounted) return;
    await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapPostPreview(post: post),
    ).then((_) {
      if (mounted) {
        // 바텀 시트가 닫힌 후 네비게이션 스택 상태 유지
      }
    });
  }

  /// 단일 마커 탭 시 게시글 미리보기 → 상세 화면 흐름 처리
  /// while 루프를 제거하여 무한 루프 방지
  Future<void> _handleSinglePostFlow(Post post) async {
    if (!mounted) return;

    // 1단계: 게시글 미리보기 표시
    final previewResult = await showModalBottomSheet<Post?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapPostPreview(post: post),
    );

    if (!mounted || previewResult == null) return;

    // 2단계: 상세 화면으로 이동
    final detailResult = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: previewResult),
      ),
    );

    if (!mounted) return;

    // 3단계: 상세 화면에서 돌아온 결과 처리
    // 재귀 호출 없이 단발성 실행 (다시 열지 않음)
    if (detailResult != null && detailResult is Map) {
      if (detailResult['reopenPreview'] == true) {
        // 미리보기를 다시 표시해야 하는 경우 단발성으로 표시
        await _showPreviewOnly(previewResult);
      }
      // reopenGallery는 단일 마커 흐름에서는 의미 없음 (무시)
    } else if (detailResult != null && detailResult is Post) {
      // 다른 게시글 상세 화면에서 온 경우 해당 게시글의 미리보기만 표시
      await _showPreviewOnly(detailResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ★ [핵심] Build 시점에 데이터 변경을 감지하여 매니저 업데이트
    final currentPosts = context.watch<PostProvider>().mapPosts;
    
    // 리스트의 참조값이 바뀌었거나, 길이가 다르면 업데이트 실행
    // (Provider가 notifyListeners를 호출하면 리스트 객체가 교체되므로 보통 참조값 비교로 충분)
    if (_cachedPosts != currentPosts) {
      _cachedPosts = currentPosts;
      // 빌드 중에 setState나 setItems를 직접 호출하면 에러가 날 수 있으므로 PostFrameCallback 사용
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateClusterItems(currentPosts);
      });
    }

    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: _onMapCreated,
        markers: _markers, // ClusterManager에 의해 업데이트된 마커 사용
        onCameraMove: (position) {
          _clusterManager?.onCameraMove(position);
        },
        onCameraIdle: () {
          _clusterManager?.updateMap();
        },
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}