import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/models/asset_model.dart';

class AssetCacheDatabase {
  static Database? _database;
  static const String _databaseName = 'asset_cache.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _assetsTable = 'cached_assets';
  static const String _hashesTable = 'asset_hashes';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  static Future<void> _createDatabase(Database db, int version) async {
    // Table for asset metadata and file info
    await db.execute('''
      CREATE TABLE $_assetsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        directory_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        last_modified INTEGER NOT NULL,
        asset_type TEXT NOT NULL,
        asset_format TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Table for pre-computed image hashes
    await db.execute('''
      CREATE TABLE $_hashesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        red_histogram TEXT NOT NULL,
        green_histogram TEXT NOT NULL,
        blue_histogram TEXT NOT NULL,
        grayscale_histogram TEXT NOT NULL,
        color_moments TEXT NOT NULL,
        similarity_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (asset_id) REFERENCES $_assetsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_assets_directory ON $_assetsTable (directory_path)');
    await db.execute('CREATE INDEX idx_assets_path ON $_assetsTable (file_path)');
    await db.execute('CREATE INDEX idx_assets_modified ON $_assetsTable (last_modified)');
    await db.execute('CREATE INDEX idx_hashes_asset ON $_hashesTable (asset_id)');
  }

  static Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle future database migrations here
  }

  // Cache a processed asset
  static Future<int> cacheAsset({
    required String filePath,
    required String directoryPath,
    required String fileName,
    required int fileSize,
    required int lastModified,
    required AssetType assetType,
    required AssetFormat assetFormat,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.insert(
      _assetsTable,
      {
        'file_path': filePath,
        'directory_path': directoryPath,
        'file_name': fileName,
        'file_size': fileSize,
        'last_modified': lastModified,
        'asset_type': assetType.name,
        'asset_format': assetFormat.name,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Cache image hashes
  static Future<void> cacheAssetHashes({
    required int assetId,
    required List<int> redHistogram,
    required List<int> greenHistogram,
    required List<int> blueHistogram,
    required List<int> grayscaleHistogram,
    required Map<String, double> colorMoments,
    required String similarityHash,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      _hashesTable,
      {
        'asset_id': assetId,
        'red_histogram': redHistogram.join(','),
        'green_histogram': greenHistogram.join(','),
        'blue_histogram': blueHistogram.join(','),
        'grayscale_histogram': grayscaleHistogram.join(','),
        'color_moments': colorMoments.entries.map((e) => '${e.key}:${e.value}').join(','),
        'similarity_hash': similarityHash,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all cached assets for a directory
  static Future<List<CachedAsset>> getCachedAssetsForDirectory(String directoryPath) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      _assetsTable,
      where: 'directory_path = ?',
      whereArgs: [directoryPath],
      orderBy: 'file_name ASC',
    );

    return maps.map((map) => CachedAsset.fromMap(map)).toList();
  }

  // Get assets that need processing (new or modified)
  static Future<List<String>> getUnprocessedAssets(
    String directoryPath,
    Map<String, FileSystemEntity> currentFiles,
  ) async {
    final db = await database;
    final unprocessed = <String>[];

    for (final entry in currentFiles.entries) {
      final filePath = entry.key;
      final file = entry.value;

      if (file is! File) continue;

      final stat = await file.stat();
      final lastModified = stat.modified.millisecondsSinceEpoch;

      // Check if file exists in cache and is up to date
      final List<Map<String, dynamic>> existing = await db.query(
        _assetsTable,
        where: 'file_path = ? AND last_modified = ?',
        whereArgs: [filePath, lastModified],
        limit: 1,
      );

      if (existing.isEmpty) {
        unprocessed.add(filePath);
      }
    }

    return unprocessed;
  }

  // Find similar assets by comparing hashes
  static Future<List<SimilarAssetResult>> findSimilarAssets({
    required List<int> targetRedHistogram,
    required List<int> targetGreenHistogram,
    required List<int> targetBlueHistogram,
    required List<int> targetGrayscaleHistogram,
    required Map<String, double> targetColorMoments,
    required String directoryPath,
    double minSimilarity = 0.90,
  }) async {
    final db = await database;

    // Get all cached hashes for the directory
    final List<Map<String, dynamic>> allHashes = await db.rawQuery('''
      SELECT h.*, a.file_path, a.file_name, a.asset_type, a.asset_format, a.file_size, a.last_modified
      FROM $_hashesTable h
      JOIN $_assetsTable a ON h.asset_id = a.id
      WHERE a.directory_path = ?
    ''', [directoryPath]);

    final results = <SimilarAssetResult>[];

    for (final hashData in allHashes) {
      try {
        // Parse stored histograms
        final redHist = hashData['red_histogram'].toString().split(',').map(int.parse).toList();
        final greenHist = hashData['green_histogram'].toString().split(',').map(int.parse).toList();
        final blueHist = hashData['blue_histogram'].toString().split(',').map(int.parse).toList();
        final grayscaleHist = hashData['grayscale_histogram'].toString().split(',').map(int.parse).toList();

        // Parse color moments
        final colorMomentsStr = hashData['color_moments'].toString();
        final colorMoments = <String, double>{};
        for (final pair in colorMomentsStr.split(',')) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            colorMoments[parts[0]] = double.parse(parts[1]);
          }
        }

        // Calculate similarity
        final similarity = _calculateHistogramSimilarity(
          targetRedHistogram, targetGreenHistogram, targetBlueHistogram,
          targetGrayscaleHistogram, targetColorMoments,
          redHist, greenHist, blueHist, grayscaleHist, colorMoments,
        );

        if (similarity >= minSimilarity) {
          results.add(SimilarAssetResult(
            filePath: hashData['file_path'].toString(),
            fileName: hashData['file_name'].toString(),
            assetType: AssetType.values.byName(hashData['asset_type'].toString()),
            assetFormat: AssetFormat.values.byName(hashData['asset_format'].toString()),
            fileSize: hashData['file_size'] as int,
            lastModified: DateTime.fromMillisecondsSinceEpoch(hashData['last_modified'] as int),
            similarity: similarity,
          ));
        }
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }

    // Sort by similarity (highest first)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results;
  }

  // Clear cache for a directory (when directory changes)
  static Future<void> clearDirectoryCache(String directoryPath) async {
    final db = await database;

    // Get asset IDs for the directory
    final List<Map<String, dynamic>> assetIds = await db.query(
      _assetsTable,
      columns: ['id'],
      where: 'directory_path = ?',
      whereArgs: [directoryPath],
    );

    // Delete hashes first (due to foreign key constraint)
    for (final assetId in assetIds) {
      await db.delete(
        _hashesTable,
        where: 'asset_id = ?',
        whereArgs: [assetId['id']],
      );
    }

    // Delete assets
    await db.delete(
      _assetsTable,
      where: 'directory_path = ?',
      whereArgs: [directoryPath],
    );
  }

  // Remove deleted files from cache
  static Future<void> cleanupDeletedFiles(String directoryPath, Set<String> existingFiles) async {
    final db = await database;

    final List<Map<String, dynamic>> cachedAssets = await db.query(
      _assetsTable,
      where: 'directory_path = ?',
      whereArgs: [directoryPath],
    );

    for (final asset in cachedAssets) {
      final filePath = asset['file_path'].toString();
      if (!existingFiles.contains(filePath)) {
        // File was deleted, remove from cache
        await db.delete(
          _assetsTable,
          where: 'file_path = ?',
          whereArgs: [filePath],
        );
      }
    }
  }

  static double _calculateHistogramSimilarity(
    List<int> r1, List<int> g1, List<int> b1, List<int> gray1, Map<String, double> moments1,
    List<int> r2, List<int> g2, List<int> b2, List<int> gray2, Map<String, double> moments2,
  ) {
    // Same logic as the original similarity calculator but optimized for cached data
    final redSim = _histogramIntersection(r1, r2);
    final greenSim = _histogramIntersection(g1, g2);
    final blueSim = _histogramIntersection(b1, b2);
    final graySim = _histogramIntersection(gray1, gray2);

    // Check color similarity requirement
    final minColorSim = [redSim, greenSim, blueSim].reduce((a, b) => a < b ? a : b);
    if (minColorSim < 0.7) {
      return minColorSim * 0.5;
    }

    // Color moments similarity
    final momentsSim = _colorMomentsSimilarity(moments1, moments2);

    return (redSim * 0.25) + (greenSim * 0.25) + (blueSim * 0.25) + (graySim * 0.15) + (momentsSim * 0.10);
  }

  static double _histogramIntersection(List<int> hist1, List<int> hist2) {
    if (hist1.length != hist2.length) return 0.0;

    int intersection = 0;
    int total1 = 0;
    int total2 = 0;

    for (int i = 0; i < hist1.length; i++) {
      intersection += (hist1[i] < hist2[i] ? hist1[i] : hist2[i]);
      total1 += hist1[i];
      total2 += hist2[i];
    }

    if (total1 == 0 || total2 == 0) return 0.0;
    final minTotal = total1 < total2 ? total1 : total2;
    return intersection / minTotal;
  }

  static double _colorMomentsSimilarity(Map<String, double> moments1, Map<String, double> moments2) {
    if (moments1.isEmpty || moments2.isEmpty) return 0.0;

    double totalDiff = 0;
    int count = 0;

    for (final key in moments1.keys) {
      if (moments2.containsKey(key)) {
        totalDiff += (moments1[key]! - moments2[key]!).abs();
        count++;
      }
    }

    if (count == 0) return 0.0;
    final avgDiff = totalDiff / count;
    return (1.0 - (avgDiff / 255.0)).clamp(0.0, 1.0);
  }
}

// Data classes
class CachedAsset {
  final int id;
  final String filePath;
  final String directoryPath;
  final String fileName;
  final int fileSize;
  final DateTime lastModified;
  final AssetType assetType;
  final AssetFormat assetFormat;

  CachedAsset({
    required this.id,
    required this.filePath,
    required this.directoryPath,
    required this.fileName,
    required this.fileSize,
    required this.lastModified,
    required this.assetType,
    required this.assetFormat,
  });

  factory CachedAsset.fromMap(Map<String, dynamic> map) {
    return CachedAsset(
      id: map['id'] as int,
      filePath: map['file_path'] as String,
      directoryPath: map['directory_path'] as String,
      fileName: map['file_name'] as String,
      fileSize: map['file_size'] as int,
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['last_modified'] as int),
      assetType: AssetType.values.byName(map['asset_type'] as String),
      assetFormat: AssetFormat.values.byName(map['asset_format'] as String),
    );
  }
}

class SimilarAssetResult {
  final String filePath;
  final String fileName;
  final AssetType assetType;
  final AssetFormat assetFormat;
  final int fileSize;
  final DateTime lastModified;
  final double similarity;

  SimilarAssetResult({
    required this.filePath,
    required this.fileName,
    required this.assetType,
    required this.assetFormat,
    required this.fileSize,
    required this.lastModified,
    required this.similarity,
  });

  AssetModel toAssetModel() {
    return AssetModel(
      path: filePath,
      name: fileName,
      type: assetType,
      format: assetFormat,
      size: fileSize,
      lastModified: lastModified,
    );
  }
}