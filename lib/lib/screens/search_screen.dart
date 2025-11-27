// lib/screens/search_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/screens/post_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  /// (추가) 초기 검색어를 받을 수 있도록 확장
  final String? initialSearchTerm;

  const SearchScreen({super.key, this.initialSearchTerm});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

  @override
  void initState() {
    super.initState();

    // 초기 검색어가 전달되었으면 TextField와 검색어 상태에 반영
    if (widget.initialSearchTerm != null && widget.initialSearchTerm!.isNotEmpty) {
      _searchController.text = widget.initialSearchTerm!;
      _searchTerm = widget.initialSearchTerm!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 검색 입력 필드
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: "태그 검색 (예: #야경)",
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
          // 엔터를 누르면 검색
          onSubmitted: (value) {
            setState(() {
              _searchTerm = value.trim();
            });
          },
        ),
      ),

      body: _searchTerm.isEmpty
          ? const Center(child: Text("검색어를 입력하세요."))
          : StreamBuilder<QuerySnapshot>(
        // Firestore에서 'tags' 배열에 검색어 포함된 문서 가져오기
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('tags', arrayContains: _searchTerm)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text("'$_searchTerm' 검색 결과가 없습니다."));
          }

          final posts = snapshot.data!.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();

          // 검색 결과 GridView
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(
                        post: posts[index],
                      ),
                    ),
                  );
                },
                child: Image.network(
                  posts[index].imageUrl,
                  fit: BoxFit.cover,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
