import 'package:flutter/material.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/post_card.dart';
import 'package:provider/provider.dart';

class MainFeedScreen extends StatefulWidget {
  const MainFeedScreen({super.key});

  @override
  State<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends State<MainFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().fetchPosts(refresh: true);
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels > position.maxScrollExtent - 300) {
      context.read<PostProvider>().fetchMorePosts();
    }
  }

  Future<void> _refresh() async {
    await context.read<PostProvider>().fetchPosts(refresh: true);
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();

    if (provider.state == ViewState.Loading && provider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: provider.posts.length + 1,
        itemBuilder: (context, index) {
          if (index == provider.posts.length) {
            return provider.isFetchingMore
                ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
                : const SizedBox.shrink();
          }

          final post = provider.posts[index];

          return PostCard(
            key: ValueKey(post.id),
            post: post,
          );
        },
      ),
    );
  }
}
