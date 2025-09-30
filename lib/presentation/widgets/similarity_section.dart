import 'package:flutter/material.dart';

import '../../core/models/asset_model.dart';
import 'asset_grid_item.dart';

class SimilaritySection extends StatelessWidget {
  const SimilaritySection({
    super.key,
    required this.title,
    required this.results,
    this.icon,
    this.color,
    this.showSimilarityScore = false,
    this.onAssetTap,
  });

  final String title;
  final List<dynamic> results;
  final IconData? icon;
  final Color? color;
  final bool showSimilarityScore;
  final Function(AssetModel)? onAssetTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color?.withValues(alpha: 0.3) ?? const Color(0xFFE5E5EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color ?? const Color(0xFF6E6E73)),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color ?? const Color(0xFF1D1D1F)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (color ?? const Color(0xFF6E6E73)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${results.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? const Color(0xFF6E6E73)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                final asset = result is SimilarityResult ? result.asset : result as AssetModel;

                return Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: AssetGridItem(asset: asset, onTap: onAssetTap != null ? () => onAssetTap!(asset) : null),
                      ),
                      if (showSimilarityScore && result is SimilarityResult) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSimilarityColor(result.similarity),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(result.similarity * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getSimilarityColor(double similarity) {
    if (similarity >= 0.9) return const Color(0xFF34C759);
    if (similarity >= 0.7) return const Color(0xFFFF9500);
    if (similarity >= 0.5) return const Color(0xFFFF3B30);
    return const Color(0xFF8E8E93);
  }
}
