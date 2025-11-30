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

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 12,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clusterManager == null) {
      _initClusterManager();
    }
  }

  void _initClusterManager() {
    final posts = context.read<PostProvider>().posts;

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
  }

  void _updateMarkers(Set<Marker> markers) {
    setState(() => _markers = markers);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _clusterManager?.setMapId(controller.mapId);
    _clusterManager?.updateMap();
  }

  Future<Marker> _markerBuilder(Cluster<PostClusterItem> cluster) async {
    if (cluster.isMultiple) {
      return Marker(
        markerId: MarkerId("cluster_${cluster.getId()}"),
        position: cluster.location,
        icon: await _getClusterBitmap(125, text: cluster.count.toString()),
        onTap: () async {
          // --- 1: 군집 클릭 -> 갤러리 시트 호출 (반환: 선택된 Post)
          final selectedPost = await showModalBottomSheet<Post?>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MapClusterGallerySheet(items: cluster.items.toList()),
          );

          if (!context.mounted) return;

          // --- 2: 갤러리에서 선택된 포스트가 있으면 -> 프리뷰 시트 호출 (반환: previewResult)
          if (selectedPost != null) {
            final previewResult = await showModalBottomSheet<Post?>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => MapPostPreview(post: selectedPost),
            );

            if (!context.mounted) return;

            // --- 3: 프리뷰에서 post 반환되면 상세 페이지로 이동
            if (previewResult != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(post: previewResult),
                ),
              );
            }
          }
        },
      );
    }

    // single item
    final post = cluster.items.first.post;

    return Marker(
      markerId: MarkerId(post.id),
      position: cluster.location,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onTap: () async {
        final selectedPost = await showModalBottomSheet<Post?>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => MapPostPreview(post: post),
        );

        if (!context.mounted) return;

        if (selectedPost != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: selectedPost),
            ),
          );
        }
      },
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

  @override
  Widget build(BuildContext context) {
    final postProvider = context.watch<PostProvider>();

    if (postProvider.state == ViewState.Loading &&
        postProvider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clusterManager != null) {
      final items = postProvider.posts
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
