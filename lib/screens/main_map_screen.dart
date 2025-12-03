// lib/screens/main_map_screen.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
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
  bool _isMapReady = false;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 12,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  // ★ [핵심 수정] Provider의 데이터 변경을 감지하여 클러스터 매니저 업데이트
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // context.watch를 사용하여 PostProvider의 mapPosts가 변경될 때마다 이 메서드가 호출됨
    final posts = context.watch<PostProvider>().mapPosts;

    if (_clusterManager != null) {
      // 이미 매니저가 있다면 아이템만 업데이트
      _updateClusterItems(posts);
    } else {
      // 매니저가 아직 없다면 초기화 시도 (단, 맵 컨트롤러가 필요할 수 있음)
      // 여기서는 데이터를 준비해두고 _onMapCreated에서 연결
      _initClusterManager(posts);
    }
  }

  // 클러스터 아이템 업데이트 (새로고침)
  void _updateClusterItems(List<Post> posts) {
    final items = posts
        .where((e) => e.location != null)
        .map((p) => PostClusterItem(p))
        .toList();
    
    _clusterManager?.setItems(items);
  }

  // 클러스터 매니저 초기화
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

    // 맵 생성 시점에 현재 데이터로 클러스터 매니저 연결
    // read를 써도 되는 이유는 didChangeDependencies에서 이미 최신 데이터를 watch하고 있기 때문
    final posts = context.read<PostProvider>().mapPosts;
    
    if (_clusterManager == null) {
      _initClusterManager(posts);
    }
    
    _clusterManager?.setMapId(controller.mapId);
    _clusterManager?.updateMap();
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

  Future<void> _handleClusterFlow(List<PostClusterItem> clusterItems) async {
    bool shouldReopenGallery = true;

    while (shouldReopenGallery && mounted) {
      shouldReopenGallery = false;

      final selectedPost = await showModalBottomSheet<Post?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MapClusterGallerySheet(items: clusterItems),
      );

      if (!mounted || selectedPost == null) break;

      final shouldReopen = await _handlePreviewFlow(selectedPost, clusterItems);

      if (shouldReopen) {
        shouldReopenGallery = true;
      }
    }
  }

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

    if (previewResult == null) {
      return clusterItems != null;
    }

    if (previewResult is String && previewResult == "backToGallery") {
      return clusterItems != null;
    }

    if (previewResult is! Post) return false;

    final detailResult = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: previewResult),
      ),
    );

    if (!mounted) return false;

    if (detailResult != null && detailResult is Map) {
      if (detailResult['reopenPreview'] == true) {
        return await _handlePreviewFlow(previewResult, clusterItems);
      } else if (detailResult['reopenGallery'] == true) {
        return true;
      }
    } else if (detailResult != null && detailResult is Post) {
      return await _handlePreviewFlow(detailResult, clusterItems);
    }

    return false;
  }

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

      final detailResult = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(post: previewResult),
        ),
      );

      if (!mounted) break;

      if (detailResult != null && detailResult is Map) {
        if (detailResult['reopenPreview'] == true) {
          shouldReopenPreview = true;
          currentPost = previewResult;
        }
      } else if (detailResult != null && detailResult is Post) {
        shouldReopenPreview = true;
        currentPost = detailResult;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: _onMapCreated,
        markers: _markers,
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