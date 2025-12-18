import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader elegante para carrosséis e listas
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor = const Color(0xFF2A2A2A),
    this.highlightColor = const Color(0xFF3A3A3A),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Skeleton para carousel items
class CarouselSkeletonLoader extends StatelessWidget {
  final double width;
  final double height;

  const CarouselSkeletonLoader({
    super.key,
    this.width = 280,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: width, height: height),
          const SizedBox(height: 8),
          SkeletonLoader(width: width * 0.7, height: 16),
          const SizedBox(height: 4),
          SkeletonLoader(width: width * 0.5, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton para grid cards
class GridCardSkeletonLoader extends StatelessWidget {
  final double width;
  final double imageHeight;

  const GridCardSkeletonLoader({
    super.key,
    this.width = 120,
    this.imageHeight = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLoader(width: width, height: imageHeight),
        const SizedBox(height: 6),
        SkeletonLoader(width: width * 0.9, height: 10),
        const SizedBox(height: 3),
        SkeletonLoader(width: width * 0.7, height: 8),
      ],
    );
  }
}
