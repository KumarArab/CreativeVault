import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoadingWidget extends StatelessWidget {
  const ShimmerLoadingWidget({super.key, this.width = 250, this.height = 300, this.borderRadius = 12});

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(borderRadius)),
      ),
    );
  }
}

class ExactMatchesShimmerWidget extends StatelessWidget {
  const ExactMatchesShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4, // Show 4 shimmer placeholders
        itemBuilder: (context, index) {
          return Container(width: 250, margin: const EdgeInsets.only(right: 12), child: const ShimmerLoadingWidget());
        },
      ),
    );
  }
}

class SearchResultsShimmerSection extends StatelessWidget {
  const SearchResultsShimmerSection({super.key, required this.uploadedAsset, this.onClearTap});

  final String uploadedAsset;
  final VoidCallback? onClearTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Clear button
          Row(
            children: [
              const Text(
                'Search Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
              ),
              const Spacer(),
              if (onClearTap != null)
                TextButton(
                  onPressed: onClearTap,
                  child: const Text('Clear', style: TextStyle(color: Color(0xFF007AFF), fontSize: 16)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Row with uploaded asset and shimmer loading exact matches
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Uploaded Asset (Left side)
              Container(
                width: 280,
                height: 365,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3), width: 2),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Uploaded Asset',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: uploadedAsset.isNotEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(image: FileImage(File(uploadedAsset)), fit: BoxFit.cover),
                                ),
                              )
                            : const ShimmerLoadingWidget(),
                      ),
                    ),
                  ],
                ),
              ),

              // Exact Matches Loading (Right side - Shimmer)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.3), width: 1),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    childrenPadding: const EdgeInsets.all(8),
                    backgroundColor: Colors.white,
                    collapsedBackgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                    leading: const Icon(Icons.search, size: 18, color: Color(0xFF34C759)),
                    title: const Text(
                      'Finding Exact Matches...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
                    ),
                    trailing: Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                    children: const [ExactMatchesShimmerWidget()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
