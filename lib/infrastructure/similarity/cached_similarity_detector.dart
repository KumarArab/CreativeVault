import 'dart:io';
import '../../core/models/asset_model.dart';
import '../database/asset_cache_database.dart';
import 'coreml_similarity_detector.dart';

/// Cached similarity detector using Core ML with database caching
class CachedSimilarityDetector {
  final CoreMLSimilarityDetector _coreMLDetector = CoreMLSimilarityDetector();
  bool _isInitialized = false;

  /// Initialize the cached detector
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing cached similarity detector...');
    _isInitialized = await _coreMLDetector.initialize();

    if (_isInitialized) {
      print('✅ Cached similarity detector initialized');
    } else {
      print('⚠️ Cached similarity detector initialization failed');
    }
  }

  /// Pre-process all assets in a directory (run once when directory is selected)
  Future<void> preprocessAssetsInDirectory(String directoryPath, List<AssetModel> assets) async {
    print('🔄 Pre-processing ${assets.length} assets for similarity caching...');

    if (!_isInitialized) {
      await initialize();
    }

    int processed = 0;
    int skipped = 0;

    for (final asset in assets) {
      try {
        // Skip if not an image
        if (asset.type != AssetType.image) {
          skipped++;
          continue;
        }

        // Check if already cached and up-to-date
        final cachedAssets = await AssetCacheDatabase.getCachedAssetsForDirectory(directoryPath);
        CachedAsset? existingCachedAsset;
        try {
          existingCachedAsset = cachedAssets.firstWhere((cached) => cached.filePath == asset.path);
        } catch (e) {
          existingCachedAsset = null;
        }

        if (existingCachedAsset != null) {
          // Check if file modification time matches
          final file = File(asset.path);
          final stat = await file.stat();
          if (existingCachedAsset.lastModified.millisecondsSinceEpoch == stat.modified.millisecondsSinceEpoch) {
            print('   ⏭️ Skipping ${asset.name} (already cached and up-to-date)');
            skipped++;
            continue;
          }
        }

        print('   🔍 Processing ${asset.name}...');

        // Extract Core ML feature vector
        final featureVector = await _coreMLDetector.extractFeatureVector(asset.path);

        if (featureVector != null) {
          // Store in cache database
          await AssetCacheDatabase.cacheAsset(
            filePath: asset.path,
            directoryPath: directoryPath,
            fileName: asset.name,
            fileSize: asset.size,
            lastModified: asset.lastModified.millisecondsSinceEpoch,
            assetType: asset.type,
            assetFormat: asset.format,
          );

          print('   ✅ Cached ${asset.name} (${featureVector.length} dimensions)');
          processed++;
        } else {
          print('   ❌ Failed to extract features from ${asset.name}');
        }
      } catch (e) {
        print('   ❌ Error processing ${asset.name}: $e');
      }
    }

    print('📊 Pre-processing completed: $processed processed, $skipped skipped');
  }

  /// Find similar assets using cached data with Core ML fallback
  Future<List<SimilarityResult>> findSimilarAssets(String targetImagePath, List<AssetModel> assetsToCompare) async {
    print('🔍 Finding similar assets using cached data...');
    print('   Target: ${targetImagePath.split('/').last}');
    print('   Assets to compare: ${assetsToCompare.length}');

    if (!_isInitialized) {
      await initialize();
    }

    final results = <SimilarityResult>[];
    final stopwatch = Stopwatch()..start();

    try {
      // Extract target feature vector using Core ML
      print('🧠 Extracting target feature vector...');
      final targetVector = await _coreMLDetector.extractFeatureVector(targetImagePath);

      if (targetVector == null) {
        print('❌ Could not extract target feature vector');
        return results;
      }

      print('✅ Target feature vector extracted: ${targetVector.length} dimensions');

      // Get cached assets for comparison
      final directoryPath = targetImagePath.split('/').sublist(0, targetImagePath.split('/').length - 1).join('/');
      final cachedAssets = await AssetCacheDatabase.getCachedAssetsForDirectory(directoryPath);

      print('📚 Found ${cachedAssets.length} cached assets');

      int processedCount = 0;
      int matchCount = 0;

      for (final asset in assetsToCompare) {
        try {
          if (asset.type != AssetType.image) continue;

          // Find cached data for this asset
          CachedAsset? cachedAsset;
          try {
            cachedAsset = cachedAssets.firstWhere((cached) => cached.filePath == asset.path);
          } catch (e) {
            cachedAsset = null;
          }

          List<double>? assetVector;

          if (cachedAsset != null) {
            // Use cached data to verify file hasn't changed
            final file = File(asset.path);
            final stat = await file.stat();

            if (cachedAsset.lastModified.millisecondsSinceEpoch == stat.modified.millisecondsSinceEpoch) {
              // File hasn't changed, but we still need to extract features on-demand
              // since the database doesn't store feature vectors
              print('   📚 Using cached metadata for ${asset.name}');
            }
          }

          // Extract feature vector on-demand (database doesn't store feature vectors)
          print('   🔍 Extracting features for ${asset.name}...');
          assetVector = await _coreMLDetector.extractFeatureVector(asset.path);

          if (assetVector != null) {
            // Update cache with current metadata
            await AssetCacheDatabase.cacheAsset(
              filePath: asset.path,
              directoryPath: directoryPath,
              fileName: asset.name,
              fileSize: asset.size,
              lastModified: asset.lastModified.millisecondsSinceEpoch,
              assetType: asset.type,
              assetFormat: asset.format,
            );
            print('   💾 Updated cache for ${asset.name}');
          }

          if (assetVector == null) {
            print('   ❌ Could not get features for ${asset.name}');
            continue;
          }

          // Calculate similarity
          final similarity = _coreMLDetector.calculateCosineSimilarity(targetVector, assetVector);
          processedCount++;

          if (similarity > 0.70) {
            // Lower threshold for cached search
            final matchType = _determineMatchType(similarity);
            final similarityPercent = (similarity * 100).toStringAsFixed(1);

            print('   ✅ MATCH FOUND: ${asset.name} - $similarityPercent% ($matchType)');

            results.add(SimilarityResult(asset: asset, similarity: similarity, matchType: matchType));
            matchCount++;
          } else {
            final similarityPercent = (similarity * 100).toStringAsFixed(1);
            print('   ⏭️ Below threshold: ${asset.name} - $similarityPercent%');
          }
        } catch (e) {
          print('   ❌ Error comparing with ${asset.name}: $e');
          continue;
        }
      }

      stopwatch.stop();

      // Sort by similarity (highest first)
      results.sort((a, b) => b.similarity.compareTo(a.similarity));

      print('📊 Cached similarity search completed:');
      print('   ⏱️ Total time: ${stopwatch.elapsedMilliseconds}ms');
      print('   🔍 Assets processed: $processedCount');
      print('   ✅ Matches found: $matchCount');
      print(
        '   📈 Average time per comparison: ${processedCount > 0 ? (stopwatch.elapsedMilliseconds / processedCount).toStringAsFixed(1) : 0}ms',
      );

      return results;
    } catch (e) {
      print('❌ Error in cached similarity search: $e');
      return results;
    }
  }

  /// Check if two assets are identical using cached data
  Future<bool> areAssetsIdentical(String assetPath1, String assetPath2) async {
    print('🔍 Checking if assets are identical using cached data...');
    print('   Asset 1: ${assetPath1.split('/').last}');
    print('   Asset 2: ${assetPath2.split('/').last}');

    if (!_isInitialized) {
      await initialize();
    }

    try {
      final file1 = File(assetPath1);
      final file2 = File(assetPath2);

      if (!await file1.exists() || !await file2.exists()) {
        print('❌ One or both files do not exist');
        return false;
      }

      final stat1 = await file1.stat();
      final stat2 = await file2.stat();

      // Quick size check
      if (stat1.size != stat2.size) {
        print('📏 Files have different sizes, not identical');
        return false;
      }

      // Calculate similarity using Core ML
      final similarity = await _coreMLDetector.calculateCoreMLSimilarity(assetPath1, assetPath2);

      // Consider identical if >95% similar
      final isIdentical = similarity >= 0.95;
      print(
        '🔍 Identity check result: ${isIdentical ? "IDENTICAL" : "DIFFERENT"} (${(similarity * 100).toStringAsFixed(1)}%)',
      );

      return isIdentical;
    } catch (e) {
      print('❌ Error in identity check: $e');
      return false;
    }
  }

  /// Calculate similarity between two assets using cached data
  Future<double> calculateSimilarity(String assetPath1, String assetPath2) async {
    print('🔍 Calculating similarity using cached data...');
    print('   Asset 1: ${assetPath1.split('/').last}');
    print('   Asset 2: ${assetPath2.split('/').last}');

    if (!_isInitialized) {
      await initialize();
    }

    return await _coreMLDetector.calculateCoreMLSimilarity(assetPath1, assetPath2);
  }

  /// Generate asset hash using cached data
  Future<String?> generateAssetHash(String assetPath) async {
    print('🔑 Generating hash using cached data: ${assetPath.split('/').last}');

    if (!_isInitialized) {
      await initialize();
    }

    return await _coreMLDetector.extractFeatureVector(assetPath).then((vector) {
      if (vector != null) {
        return vector.map((v) => v.toStringAsFixed(3)).join(',');
      }
      return null;
    });
  }

  /// Clear cache for directory
  Future<void> clearCacheForDirectory(String directoryPath) async {
    print('🗑️ Clearing cache for directory: ${directoryPath.split('/').last}');
    await AssetCacheDatabase.clearDirectoryCache(directoryPath);
    print('✅ Cache cleared');
  }

  /// Check if cache needs update
  Future<bool> needsCacheUpdate(String directoryPath, List<AssetModel> currentAssets) async {
    print('🔍 Checking if cache needs update for: ${directoryPath.split('/').last}');

    final cachedAssets = await AssetCacheDatabase.getCachedAssetsForDirectory(directoryPath);

    if (cachedAssets.length != currentAssets.length) {
      print('📊 Asset count changed: ${cachedAssets.length} cached vs ${currentAssets.length} current');
      return true;
    }

    // Check if any files have been modified
    for (final asset in currentAssets) {
      if (asset.type != AssetType.image) continue;

      CachedAsset? cachedAsset;
      try {
        cachedAsset = cachedAssets.firstWhere((cached) => cached.filePath == asset.path);
      } catch (e) {
        cachedAsset = null;
      }

      if (cachedAsset == null) {
        print('📝 New asset found: ${asset.name}');
        return true;
      }

      if (cachedAsset.lastModified.millisecondsSinceEpoch != asset.lastModified.millisecondsSinceEpoch) {
        print('📝 Asset modified: ${asset.name}');
        return true;
      }
    }

    print('✅ Cache is up to date');
    return false;
  }

  /// Cleanup deleted files from cache
  Future<void> cleanupDeletedFiles(String directoryPath, List<AssetModel> currentAssets) async {
    print('🧹 Cleaning up deleted files from cache...');

    final currentPaths = currentAssets.map((asset) => asset.path).toSet();
    await AssetCacheDatabase.cleanupDeletedFiles(directoryPath, currentPaths);

    print('✅ Cleanup completed');
  }

  /// Determine match type based on similarity score
  SimilarityMatchType _determineMatchType(double similarity) {
    if (similarity >= 0.95) return SimilarityMatchType.exact;
    if (similarity >= 0.85) return SimilarityMatchType.nearDuplicate;
    if (similarity >= 0.70) return SimilarityMatchType.visuallySimilar;
    return SimilarityMatchType.structurallySimilar;
  }

  /// Dispose of resources
  void dispose() {
    print('🔄 Disposing cached similarity detector...');
    _coreMLDetector.dispose();
    print('✅ Cached similarity detector disposed');
  }
}
