import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({super.key, required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.outline,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.outline,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class PostCardShimmer extends StatelessWidget {
  const PostCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 72, height: 72, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: double.infinity, height: 12),
                const SizedBox(height: 6),
                const ShimmerBox(width: 160, height: 11),
                const SizedBox(height: 8),
                Row(children: const [ShimmerBox(width: 55, height: 18, radius: 20), SizedBox(width: 8), ShimmerBox(width: 70, height: 18, radius: 20)]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardStatShimmer extends StatelessWidget {
  const DashboardStatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 28, height: 28, radius: 8),
          SizedBox(height: 8),
          ShimmerBox(width: 50, height: 22),
          SizedBox(height: 4),
          ShimmerBox(width: 70, height: 10),
        ],
      ),
    );
  }
}
