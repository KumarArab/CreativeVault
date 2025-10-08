import '../../core/models/asset_model.dart';
import '../database/asset_cache_database.dart';
import 'image_similarity_detector.dart';

class CachedSimilarityDetector {
  final ImageSimilarityDetector _imageSimilarityDetector = ImageSimilarityDetector();

  // Pre-process all assets in a directory (run once when directory is selected)
  Future<void> preprocessAssetsInDirectory(String directoryPath, List<AssetModel> assets) async {
    print('Pre-processing ${assets.length} assets for similarity caching...');

    int processed = 0;

    for (final asset in assets) {
      try {
        // Skip if not an image
        if (asset.type != AssetType.image) continue;

        // Check if already cached and up-to-date
        final cachedAssets = await AssetCacheDatabase.getCachedAssetsForDirectory(directoryPath);
        final isAlreadyCached = cachedAssets.any(
          (cached) =>
              cached.filePath == asset.path &&
              cached.lastModified.millisecondsSinceEpoch == asset.lastModified.millisecondsSinceEpoch,
        );

        if (isAlreadyCached) continue;

        // Process the asset
        await _processAndCacheAsset(asset, directoryPath);
        processed++;

        if (processed % 10 == 0) {
          print('Processed $processed/${assets.length} assets...');
        }
      } catch (e) {
        print('Error processing asset ${asset.path}: $e');
        continue;
      }
    }

    print('Asset pre-processing complete! Processed $processed new/updated assets.');
  }

  // Process a single asset and cache its hashes
  Future<void> _processAndCacheAsset(AssetModel asset, String directoryPath) async {
    try {
      // Generate image hashes using existing detector
      final hashes = await _imageSimilarityDetector.generateImageHashes(asset.path);
      if (hashes == null) return;

      // Cache asset metadata
      final assetId = await AssetCacheDatabase.cacheAsset(
        filePath: asset.path,
        directoryPath: directoryPath,
        fileName: asset.name,
        fileSize: asset.size,
        lastModified: asset.lastModified.millisecondsSinceEpoch,
        assetType: asset.type,
        assetFormat: asset.format,
      );

      // Cache image hashes
      await AssetCacheDatabase.cacheAssetHashes(
        assetId: assetId,
        redHistogram: hashes.redHistogram,
        greenHistogram: hashes.greenHistogram,
        blueHistogram: hashes.blueHistogram,
        grayscaleHistogram: hashes.grayscaleHistogram,
        colorMoments: hashes.colorMoments,
        similarityHash: _generateSimpleHash(hashes),
      );
    } catch (e) {
      print('Error caching asset ${asset.path}: $e');
    }
  }

  // Fast similarity search using cached data
  Future<List<SimilarityResult>> findSimilarAssetsFast(String uploadedAssetPath, String directoryPath) async {
    try {
      print('Finding similar assets using cached data...');

      // Generate hashes for uploaded asset
      final uploadedHashes = await _imageSimilarityDetector.generateImageHashes(uploadedAssetPath);
      if (uploadedHashes == null) {
        print('Could not process uploaded asset');
        return [];
      }

      // Query database for similar assets
      final similarAssets = await AssetCacheDatabase.findSimilarAssets(
        targetRedHistogram: uploadedHashes.redHistogram,
        targetGreenHistogram: uploadedHashes.greenHistogram,
        targetBlueHistogram: uploadedHashes.blueHistogram,
        targetGrayscaleHistogram: uploadedHashes.grayscaleHistogram,
        targetColorMoments: uploadedHashes.colorMoments,
        directoryPath: directoryPath,
        minSimilarity: 0.70, // More flexible matching
      );

      print('Found ${similarAssets.length} similar assets from cache');

      // Convert to SimilarityResult format
      return similarAssets
          .map(
            (result) => SimilarityResult(
              asset: result.toAssetModel(),
              similarity: result.similarity,
              matchType: _determineMatchType(result.similarity),
            ),
          )
          .toList();
    } catch (e) {
      print('Error in fast similarity search: $e');
      return [];
    }
  }

  // Update cache when new files are added
  Future<void> updateCacheForNewFiles(String directoryPath, List<AssetModel> newAssets) async {
    if (newAssets.isEmpty) return;

    print('Updating cache for ${newAssets.length} new assets...');

    for (final asset in newAssets) {
      if (asset.type == AssetType.image) {
        await _processAndCacheAsset(asset, directoryPath);
      }
    }

    print('Cache update complete!');
  }

  // Clean up cache when directory changes
  Future<void> clearCacheForDirectory(String directoryPath) async {
    await AssetCacheDatabase.clearDirectoryCache(directoryPath);
    print('Cache cleared for directory: $directoryPath');
  }

  // Remove deleted files from cache
  Future<void> cleanupDeletedFiles(String directoryPath, List<AssetModel> currentAssets) async {
    final existingFiles = currentAssets.map((asset) => asset.path).toSet();
    await AssetCacheDatabase.cleanupDeletedFiles(directoryPath, existingFiles);
  }

  // Check if directory cache needs updating
  Future<bool> needsCacheUpdate(String directoryPath, List<AssetModel> currentAssets) async {
    try {
      final cachedAssets = await AssetCacheDatabase.getCachedAssetsForDirectory(directoryPath);

      // If no cached assets, needs full processing
      if (cachedAssets.isEmpty && currentAssets.isNotEmpty) {
        return true;
      }

      // Check for new or modified files
      for (final asset in currentAssets) {
        if (asset.type != AssetType.image) continue;

        final cached = cachedAssets.where((c) => c.filePath == asset.path).isEmpty
            ? null
            : cachedAssets.where((c) => c.filePath == asset.path).first;
        if (cached == null || cached.lastModified.millisecondsSinceEpoch != asset.lastModified.millisecondsSinceEpoch) {
          return true;
        }
      }

      // Check for deleted files
      for (final cached in cachedAssets) {
        if (!currentAssets.any((asset) => asset.path == cached.filePath)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking cache status: $e');
      return true; // Assume needs update on error
    }
  }

  String _generateSimpleHash(ImageHashes hashes) {
    // Create a simple combined hash for quick lookup
    final combined = StringBuffer();

    // Sample a few key histogram values
    for (int i = 0; i < hashes.redHistogram.length; i += 32) {
      combined.write(hashes.redHistogram[i].toString());
    }

    return combined.toString();
  }

  SimilarityMatchType _determineMatchType(double similarity) {
    if (similarity >= 0.95) return SimilarityMatchType.exact;
    if (similarity >= 0.85) return SimilarityMatchType.nearDuplicate;
    if (similarity >= 0.70) return SimilarityMatchType.visuallySimilar;
    return SimilarityMatchType.structurallySimilar;
  }
}
