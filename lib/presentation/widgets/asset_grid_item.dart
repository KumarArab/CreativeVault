import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:rive/rive.dart' hide Image;

import 'video_preview_widget.dart';

import '../../core/models/asset_model.dart';

class AssetGridItem extends StatelessWidget {
  const AssetGridItem({super.key, required this.asset, this.onTap, this.isSelected = false});

  final AssetModel asset;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300, minHeight: 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildAssetPreview()),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        asset.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1D1D1F)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildAssetTypeIcon(),
                          const SizedBox(width: 4),
                          Text(
                            _getAssetTypeName(asset.type),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6E6E73), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF6E6E73))),
                          const SizedBox(width: 4),
                          Text(
                            _formatFileSize(asset.size),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6E6E73)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetPreview() {
    switch (asset.type) {
      case AssetType.image:
        return _buildImagePreview();
      case AssetType.svg:
        return _buildSVGPreview();
      case AssetType.lottie:
        return _buildLottiePreview();
      case AssetType.rive:
        return _buildRivePreview();
      case AssetType.video:
        return _buildVideoPreview();
      case AssetType.unknown:
        return _buildUnknownPreview();
    }
  }

  Widget _buildImagePreview() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          _buildContrastBackground(),
          Align(
            alignment: Alignment.center,
            child: Image.file(
              File(asset.path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildErrorPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSVGPreview() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          _buildContrastBackground(),
          Align(
            alignment: Alignment.center,
            child: SvgPicture.file(
              File(asset.path),
              fit: BoxFit.contain,
              height: 100,
              placeholderBuilder: (context) => const CupertinoActivityIndicator(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottiePreview() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          _buildContrastBackground(),
          Align(
            alignment: Alignment.center,
            child: Lottie.file(
              File(asset.path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildLottieIcon(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRivePreview() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          _buildContrastBackground(),
          Align(
            alignment: Alignment.center,
            child: RiveAnimation.file(asset.path, fit: BoxFit.contain, onInit: (artboard) {}),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return VideoPreviewWidget(
      videoPath: asset.path,
      uniqueKey: '${asset.path}_${asset.lastModified.millisecondsSinceEpoch}',
    );
  }

  Widget _buildUnknownPreview() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
      child: const Icon(CupertinoIcons.question, size: 32, color: Color(0xFF6E6E73)),
    );
  }

  Widget _buildErrorPreview() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
      child: const Icon(CupertinoIcons.exclamationmark_triangle, size: 32, color: Color(0xFFFF3B30)),
    );
  }

  Widget _buildLottieIcon() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
      child: const Icon(CupertinoIcons.play_circle, size: 32, color: Color(0xFF007AFF)),
    );
  }

  Widget _buildAssetTypeIcon() {
    IconData icon;
    Color color;

    switch (asset.type) {
      case AssetType.image:
        icon = CupertinoIcons.photo;
        color = const Color(0xFF34C759);
        break;
      case AssetType.svg:
        icon = CupertinoIcons.triangle;
        color = const Color(0xFF007AFF);
        break;
      case AssetType.lottie:
        icon = CupertinoIcons.play_circle;
        color = const Color(0xFFFF9500);
        break;
      case AssetType.rive:
        icon = CupertinoIcons.play_rectangle;
        color = const Color(0xFF5856D6);
        break;
      case AssetType.video:
        icon = CupertinoIcons.videocam_fill;
        color = const Color(0xFFFF2D92);
        break;
      case AssetType.unknown:
        icon = CupertinoIcons.question;
        color = const Color(0xFF8E8E93);
        break;
    }

    return Icon(icon, size: 12, color: color);
  }

  Widget _buildContrastBackground() {
    // Smart background selection for better visibility
    final fileName = asset.name.toLowerCase();

    // Check for common patterns that indicate light/white content
    final lightPatterns = ['white', 'light', 'bright', 'logo_light', 'icon_light', 'outline', 'stroke'];

    final darkPatterns = ['dark', 'black', 'shadow', 'filled', 'solid'];

    Color backgroundColor;

    // Check filename for hints about content
    bool isLightContent = false;
    bool isDarkContent = false;

    for (final pattern in lightPatterns) {
      if (fileName.contains(pattern)) {
        isLightContent = true;
        break;
      }
    }

    if (!isLightContent) {
      for (final pattern in darkPatterns) {
        if (fileName.contains(pattern)) {
          isDarkContent = true;
          break;
        }
      }
    }

    if (isLightContent) {
      backgroundColor = const Color(0xFF2C2C2E); // Dark background for light content
    } else if (isDarkContent) {
      backgroundColor = const Color(0xFFF8F9FA); // Light background for dark content
    } else {
      // Default: Use a subtle checkerboard pattern for unknown content
      return _buildCheckerboardBackground();
    }

    return Container(
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildCheckerboardBackground() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: CustomPaint(painter: CheckerboardPainter(), child: Container()),
    );
  }

  String _getAssetTypeName(AssetType type) {
    switch (type) {
      case AssetType.image:
        return 'Image';
      case AssetType.svg:
        return 'Vector';
      case AssetType.lottie:
        return 'Lottie';
      case AssetType.rive:
        return 'Rive';
      case AssetType.video:
        return 'Video';
      case AssetType.unknown:
        return 'Unknown';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class CheckerboardPainter extends CustomPainter {
  static const double _squareSize = 8.0;
  static const Color _lightColor = Color(0xFFF5F5F7);
  static const Color _darkColor = Color(0xFFEBEBED);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (double x = 0; x < size.width; x += _squareSize) {
      for (double y = 0; y < size.height; y += _squareSize) {
        final isEven = ((x / _squareSize).floor() + (y / _squareSize).floor()) % 2 == 0;
        paint.color = isEven ? _lightColor : _darkColor;

        canvas.drawRect(Rect.fromLTWH(x, y, _squareSize, _squareSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
