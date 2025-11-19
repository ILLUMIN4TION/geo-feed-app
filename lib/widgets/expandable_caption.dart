// lib/widgets/expandable_caption.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ExpandableCaption extends StatefulWidget {
  final String text;
  const ExpandableCaption({super.key, required this.text});

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _isExpanded = false;
  static const int _maxLines = 3; // 최대 표시 줄 수 (인스타 스타일)

  @override
  Widget build(BuildContext context) {
    // 1. 해시태그 분리 로직 (기존 동일)
    final String originalText = widget.text;
    final RegExp hashtagRegExp = RegExp(r"\#\S+");

    final List<String> tags = hashtagRegExp
        .allMatches(originalText)
        .map((m) => m.group(0)!)
        .toList();

    String cleanText = originalText.replaceAll(hashtagRegExp, '').trim();
    cleanText = cleanText.replaceAll(RegExp(r'\n+'), '\n').trim();

    // 본문이 비었으면 태그만 표시
    if (cleanText.isEmpty && tags.isNotEmpty) {
      return _buildTags(tags);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2. 본문 (LayoutBuilder로 너비 계산)
        if (cleanText.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              // 텍스트 스타일 정의
              const TextStyle style = TextStyle(fontSize: 15, color: Colors.black);
              final TextSpan span = TextSpan(text: cleanText, style: style);

              // 텍스트 페인터로 미리 그려보기 (너비 계산용)
              final TextPainter tp = TextPainter(
                text: span,
                maxLines: _maxLines,
                textDirection: TextDirection.ltr,
              );
              tp.layout(maxWidth: constraints.maxWidth);

              // 3줄을 넘지 않으면 그냥 표시
              if (!tp.didExceedMaxLines) {
                return Text(cleanText, style: style);
              }

              // 펼쳐진 상태면 전체 표시 + 접기 버튼
              if (_isExpanded) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cleanText, style: style),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = false),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text("접기", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    ),
                  ],
                );
              }

              // 3. (수정) 접힌 상태: "... 더보기"를 인라인으로 삽입

              // "... 더보기"가 차지할 공간 계산
              const TextSpan moreSpan = TextSpan(
                text: "... 더보기",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              );
              final TextPainter moreTp = TextPainter(
                text: moreSpan,
                textDirection: TextDirection.ltr,
              );
              moreTp.layout();

              // (수정 핵심) 3번째 줄의 끝부분 위치 찾기
              // 기존: constraints.maxWidth - moreTp.width
              // 수정: constraints.maxWidth - moreTp.width - 10 (10픽셀 여유 공간 확보)
              final pos = tp.getPositionForOffset(Offset(
                constraints.maxWidth - moreTp.width - 10,
                tp.height,
              ));

              // 잘라낼 위치 (인덱스)
              int endIndex = pos.offset;

              // (추가) 안전장치: 텍스트가 잘리는 위치가 단어 중간일 수 있으므로
              // 글자수보다 넘치지 않게 조정
              if (endIndex > cleanText.length) {
                endIndex = cleanText.length;
              }

              return RichText(
                text: TextSpan(
                  style: style,
                  children: [
                    TextSpan(text: cleanText.substring(0, endIndex)),
                    TextSpan(
                      text: "... 더보기",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                    ),
                  ],
                ),
              );
            },
          ),

        // 4. 하단 해시태그
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTags(tags),
          ),
      ],
    );
  }

  Widget _buildTags(List<String> tags) {
    return Wrap(
      spacing: 4.0,
      children: tags.map((tag) {
        return Text(
          "$tag ",
          style: const TextStyle(color: Colors.blue, fontSize: 15),
        );
      }).toList(),
    );
  }
}