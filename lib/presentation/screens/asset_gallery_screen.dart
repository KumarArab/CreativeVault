import 'package:creativevault/core/models/asset_model.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../controllers/app_controller.dart';
import '../models/app_state.dart';
import '../widgets/asset_grid_item.dart';
import '../widgets/similarity_section.dart';

class AssetGalleryScreen extends ConsumerStatefulWidget {
  const AssetGalleryScreen({super.key});

  @override
  ConsumerState<AssetGalleryScreen> createState() => _AssetGalleryScreenState();
}

class _AssetGalleryScreenState extends ConsumerState<AssetGalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final appController = ref.read(appControllerProvider.notifier);

    final filteredAssets = appState.assets
        .where((asset) => asset.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .where((asset) => _matchesFilter(asset, appState.selectedFilter))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Column(
        children: [
          _buildHeader(appState, appController),
          _buildFilterChips(appState, appController),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (appState.uploadedAsset != null) ...[_buildSimilarityResults(appState, appController)],
                Expanded(child: _buildAssetGrid(filteredAssets)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppState appState, AppController appController) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => appController.selectPath(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.back, color: Color(0xFF007AFF)),
                    SizedBox(width: 4),
                    Text('Change Path', style: TextStyle(color: Color(0xFF007AFF), fontSize: 16)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${appState.assets.length} Assets',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
              ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF007AFF),
                onPressed:
                    appState.status == AppStatus.uploadingAsset || appState.status == AppStatus.findingSimilarAssets
                    ? null
                    : () => appController.uploadAssetAndFindSimilar(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appState.status == AppStatus.uploadingAsset ||
                        appState.status == AppStatus.findingSimilarAssets) ...[
                      const CupertinoActivityIndicator(color: Colors.white),
                      const SizedBox(width: 8),
                    ] else ...[
                      const Icon(CupertinoIcons.plus, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      appState.status == AppStatus.uploadingAsset
                          ? 'Uploading...'
                          : appState.status == AppStatus.findingSimilarAssets
                          ? 'Finding Similar...'
                          : 'Upload Asset',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoSearchTextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            placeholder: 'Search assets...',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarityResults(AppState appState, AppController appController) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Similarity Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => appController.clearUploadedAsset(),
                child: const Text('Clear', style: TextStyle(color: Color(0xFF007AFF), fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SimilaritySection(
            title: 'Exact Matches',
            results: appState.exactMatches,
            icon: CupertinoIcons.checkmark_circle_fill,
            color: const Color(0xFF34C759),
            onAssetTap: (asset) => _showAssetDetails(context, asset),
          ),
          SimilaritySection(
            title: 'Similar Assets',
            results: appState.similarAssets,
            icon: CupertinoIcons.search,
            color: const Color(0xFF007AFF),
            showSimilarityScore: true,
            onAssetTap: (asset) => _showAssetDetails(context, asset),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetGrid(List assets) {
    if (assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? CupertinoIcons.search : CupertinoIcons.photo_on_rectangle,
              size: 64,
              color: const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No assets found for "$_searchQuery"' : 'No assets found in selected directory',
              style: const TextStyle(fontSize: 18, color: Color(0xFF6E6E73)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MasonryGridView.count(
        controller: _scrollController,
        crossAxisCount: _calculateCrossAxisCount(context),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemCount: assets.length,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final asset = assets[index];
          return AssetGridItem(asset: asset, onTap: () => _showAssetDetails(context, asset));
        },
      ),
    );
  }

  int _calculateCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    if (width > 400) return 3;
    return 2;
  }

  void _showAssetDetails(BuildContext context, AssetModel asset) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(asset.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Path: ${asset.path}'),
            const SizedBox(height: 8),
            Text('Type: ${_getAssetTypeName(asset.type)}'),
            const SizedBox(height: 8),
            Text('Size: ${_formatFileSize(asset.size)}'),
            const SizedBox(height: 8),
            Text('Modified: ${_formatDate(asset.lastModified)}'),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _openFileLocation(asset.path);
            },
            child: const Text('Show in Finder'),
          ),
        ],
      ),
    );
  }

  void _openFileLocation(String assetPath) async {
    try {
      if (Platform.isMacOS) {
        // Use the 'open' command with -R flag to reveal in Finder
        final result = await Process.run('open', ['-R', assetPath]);
        if (result.exitCode != 0) {
          print('Failed to open in Finder: ${result.stderr}');
          _showErrorSnackBar('Failed to open file location');
        }
      } else {
        print('Show in Finder is only supported on macOS');
        _showErrorSnackBar('Show in Finder is only supported on macOS');
      }
    } catch (e) {
      print('Error opening file location: $e');
      _showErrorSnackBar('Error opening file location');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF3B30), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getAssetTypeName(AssetType type) {
    switch (type) {
      case AssetType.image:
        return 'Image';
      case AssetType.svg:
        return 'SVG';
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

  Widget _buildFilterChips(AppState appState, AppController appController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        // color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AssetTypeFilter.values.map((filter) {
            final isSelected = appState.selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minSize: 0,
                onPressed: () => appController.setFilter(filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA), width: 1),
                  ),
                  child: Text(
                    _getFilterDisplayName(filter),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF1D1D1F),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getFilterDisplayName(AssetTypeFilter filter) {
    switch (filter) {
      case AssetTypeFilter.all:
        return 'All';
      case AssetTypeFilter.images:
        return 'Images';
      case AssetTypeFilter.vectors:
        return 'Vectors';
      case AssetTypeFilter.lotties:
        return 'Lotties';
      case AssetTypeFilter.rives:
        return 'Rives';
      case AssetTypeFilter.videos:
        return 'Videos';
    }
  }

  bool _matchesFilter(AssetModel asset, AssetTypeFilter filter) {
    switch (filter) {
      case AssetTypeFilter.all:
        return true;
      case AssetTypeFilter.images:
        return asset.type == AssetType.image;
      case AssetTypeFilter.vectors:
        return asset.type == AssetType.svg;
      case AssetTypeFilter.lotties:
        return asset.type == AssetType.lottie;
      case AssetTypeFilter.rives:
        return asset.type == AssetType.rive;
      case AssetTypeFilter.videos:
        return asset.type == AssetType.video;
    }
  }
}
