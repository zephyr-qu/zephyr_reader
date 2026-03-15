import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 书籍封面组件
class BookCover extends StatelessWidget {
  final String? coverUrl;
  final double width;
  final double height;
  final String? title;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const BookCover({
    super.key,
    this.coverUrl,
    this.width = 80,
    this.height = 120,
    this.title,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBorderRadius = borderRadius ?? BorderRadius.circular(8);

    Widget child;

    if (coverUrl != null && coverUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: coverUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    } else {
      child = _buildPlaceholder();
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: defaultBorderRadius,
        child: child,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.book_outlined,
          size: width * 0.4,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}