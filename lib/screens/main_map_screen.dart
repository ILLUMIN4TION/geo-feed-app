// lib/screens/main_map_screen.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/models/post_cluster_item.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/utils/view_state.dart';
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

class _MainMapScreenState extends State<MainMapScreen> {
  GoogleMapController? _mapController;
  ClusterManager<PostClusterItem>? _clusterManager;

  Set<Marker> _markers = {};
  bool _isMapReady = false;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    // initState에서는 context를 사용할 수 없으므로 여기서는 초기화하지 않음
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ClusterManager를 매번 초기화하지 않고, 데이터가 있을 때만 초기화
    if (_clusterManager == null) {
      final posts = context.read<PostProvider>().mapPosts;
      if (posts.isNotEmpty) {
        _initClusterManager();
      }
    }
  }

  void _initClusterManager() {
    final posts = context.read<PostProvider>().mapPosts;

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

    // 지도가 이미 준비됐다면 바로 업데이트
    if (_isMapReady && _mapController != null) {
      _clusterManager?.setMapId(_mapController!.mapId);
      _clusterManager?.updateMap();
    }
  }

  void _updateMarkers(Set<Marker> markers) {
    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;

    if (_clusterManager != null) {
      _clusterManager?.setMapId(controller.mapId);
      _clusterManager?.updateMap();
    } else {
      // ClusterManager가 아직 없으면 지금 초기화
      _initClusterManager();
      _clusterManager?.setMapId(controller.mapId);
      _clusterManager?.updateMap();
    }
  }

  // 클러스터 플로우를 처리하는 별도 함수
  Future<void> _handleClusterFlow(List<PostClusterItem> clusterItems) async {
    bool shouldReopenGallery = true;

    while (shouldReopenGallery && mounted) {
      shouldReopenGallery = false;

      // 1단계: 갤러리 시트 표시
      final selectedPost = await showModalBottomSheet<Post?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MapClusterGallerySheet(items: clusterItems),
      );

      if (!mounted || selectedPost == null) break;

      // 2단계: 프리뷰 시트 표시 및 상세 화면 플로우
      final shouldReopen = await _handlePreviewFlow(selectedPost, clusterItems);

      // 프리뷰에서 갤러리로 돌아가라는 신호를 받으면 갤러리 다시 열기
      if (shouldReopen) {
        shouldReopenGallery = true;
      }
    }
  }

  // 단일 포스트 또는 프리뷰 플로우를 처리하는 함수
  // 반환값: true면 갤러리로 돌아가야 함
  Future<bool> _handlePreviewFlow(Post post, [List<PostClusterItem>? clusterItems]) async {
    final previewResult = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapPostPreview(post: post),
    );

    if (!mounted) return false;

    // 프리뷰에서 닫기 버튼이나 외부 탭으로 닫은 경우
    if (previewResult == null) {
      // 클러스터에서 온 경우 갤러리로 돌아가기
      return clusterItems != null;
    }

    // "backToGallery" 신호를 받은 경우
    if (previewResult is String && previewResult == "backToGallery") {
      return clusterItems != null;
    }

    // Post를 반환받은 경우 (상세 보기 버튼 클릭)
    if (previewResult is! Post) return false;

    // 3단계: 상세 페이지로 이동
    final detailResult = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: previewResult),
      ),
    );

    if (!mounted) return false;

    // 상세 페이지에서 돌아올 때 처리
    if (detailResult != null && detailResult is Map) {
      if (detailResult['reopenPreview'] == true) {
        // 프리뷰 시트 다시 열기 (재귀 호출)
        return await _handlePreviewFlow(previewResult, clusterItems);
      } else if (detailResult['reopenGallery'] == true) {
        // 갤러리로 돌아가기
        return true;
      }
    } else if (detailResult != null && detailResult is Post) {
      // 업데이트된 포스트로 프리뷰 다시 열기
      return await _handlePreviewFlow(detailResult, clusterItems);
    }

    return false;
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

    // single item
    final post = cluster.items.first.post;

    return Marker(
      markerId: MarkerId(post.id),
      position: cluster.location,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onTap: () => _handleSinglePostFlow(post),
    );
  }

  // 단일 포스트 플로우 처리 (프리뷰 시트가 재귀적으로 열리도록)
  Future<void> _handleSinglePostFlow(Post post) async {
    bool shouldReopenPreview = true;
    Post currentPost = post;

    while (shouldReopenPreview && mounted) {
      shouldReopenPreview = false;

      final previewResult = await showModalBottomSheet<Post?>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => MapPostPreview(post: currentPost),
      );

      if (!mounted || previewResult == null) break;

      // 상세 페이지로 이동
      final detailResult = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(post: previewResult),
        ),
      );

      if (!mounted) break;

      // 상세 페이지에서 돌아올 때 처리
      if (detailResult != null && detailResult is Map) {
        if (detailResult['reopenPreview'] == true) {
          // 프리뷰 시트 다시 열기
          shouldReopenPreview = true;
          currentPost = previewResult;
        }
      } else if (detailResult != null && detailResult is Post) {
        // 업데이트된 포스트로 프리뷰 다시 열기
        shouldReopenPreview = true;
        currentPost = detailResult;
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final postProvider = context.watch<PostProvider>();

    // ClusterManager가 없고 데이터가 있으면 초기화
    if (_clusterManager == null && postProvider.mapPosts.isNotEmpty) {
      _initClusterManager();
    }

    // 데이터가 업데이트되면 ClusterManager에 반영
    if (_clusterManager != null && postProvider.mapPosts.isNotEmpty) {
      final items = postProvider.mapPosts
          .where((e) => e.location != null)
          .map((p) => PostClusterItem(p))
          .toList();

      _clusterManager!.setItems(items);
    }

    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: _onMapCreated,
        markers: _markers,
        onCameraMove: _clusterManager?.onCameraMove,
        onCameraIdle: _clusterManager?.updateMap,
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
      ),
    );
  }
}