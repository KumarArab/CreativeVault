import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../../core/models/asset_model.dart';

class VectorSimilarityDetector {
  Future<List<SimilarityResult>> findSimilarVectors(String targetVectorPath, List<AssetModel> vectorAssets) async {
    final results = <SimilarityResult>[];
    final targetType = await _determineVectorType(targetVectorPath);

    if (targetType == VectorType.unknown) return results;

    for (final asset in vectorAssets) {
      if (!_isVectorAsset(asset)) continue;

      try {
        final similarity = await _calculateVectorSimilarity(targetVectorPath, asset.path, targetType);

        if (similarity > 0.3) {
          results.add(
            SimilarityResult(asset: asset, similarity: similarity, matchType: _determineMatchType(similarity)),
          );
        }
      } catch (e) {
        continue;
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results;
  }

  Future<bool> areVectorsIdentical(String vectorPath1, String vectorPath2) async {
    try {
      print('Comparing vectors: $vectorPath1 vs $vectorPath2');
      final hash1 = await _generateVectorHash(vectorPath1);
      final hash2 = await _generateVectorHash(vectorPath2);
      print('Vector hashes: $hash1 vs $hash2');
      final areIdentical = hash1 == hash2;
      print('Vectors identical: $areIdentical');
      return areIdentical;
    } catch (e) {
      print('Error comparing vectors: $e');
      return false;
    }
  }

  Future<double> calculateVectorSimilarity(String vectorPath1, String vectorPath2) async {
    try {
      final type1 = await _determineVectorType(vectorPath1);
      final type2 = await _determineVectorType(vectorPath2);

      if (type1 != type2) return 0.0;

      return await _calculateVectorSimilarity(vectorPath1, vectorPath2, type1);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateVectorSimilarity(String path1, String path2, VectorType vectorType) async {
    switch (vectorType) {
      case VectorType.svg:
        return await _calculateSVGSimilarity(path1, path2);
      case VectorType.lottie:
        return await _calculateLottieSimilarity(path1, path2);
      case VectorType.rive:
        return await _calculateRiveSimilarity(path1, path2);
      case VectorType.unknown:
        return 0.0;
    }
  }

  Future<double> _calculateSVGSimilarity(String svgPath1, String svgPath2) async {
    try {
      final content1 = await File(svgPath1).readAsString();
      final content2 = await File(svgPath2).readAsString();

      final features1 = _extractSVGFeatures(content1);
      final features2 = _extractSVGFeatures(content2);

      return _compareSVGFeatures(features1, features2);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateLottieSimilarity(String lottiePath1, String lottiePath2) async {
    try {
      final content1 = await File(lottiePath1).readAsString();
      final content2 = await File(lottiePath2).readAsString();

      final json1 = jsonDecode(content1) as Map<String, dynamic>;
      final json2 = jsonDecode(content2) as Map<String, dynamic>;

      final features1 = _extractLottieFeatures(json1);
      final features2 = _extractLottieFeatures(json2);

      return _compareLottieFeatures(features1, features2);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateRiveSimilarity(String rivePath1, String rivePath2) async {
    try {
      final file1 = File(rivePath1);
      final file2 = File(rivePath2);

      final stat1 = await file1.stat();
      final stat2 = await file2.stat();

      final sizeSimilarity = 1.0 - ((stat1.size - stat2.size).abs() / (stat1.size + stat2.size));

      final bytes1 = await file1.readAsBytes();
      final bytes2 = await file2.readAsBytes();

      final hash1 = sha256.convert(bytes1).toString();
      final hash2 = sha256.convert(bytes2).toString();

      final contentSimilarity = hash1 == hash2 ? 1.0 : 0.0;

      return (sizeSimilarity * 0.3) + (contentSimilarity * 0.7);
    } catch (e) {
      return 0.0;
    }
  }

  SVGFeatures _extractSVGFeatures(String svgContent) {
    final pathCount = RegExp(r'<path').allMatches(svgContent).length;
    final circleCount = RegExp(r'<circle').allMatches(svgContent).length;
    final rectCount = RegExp(r'<rect').allMatches(svgContent).length;
    final groupCount = RegExp(r'<g').allMatches(svgContent).length;

    final colors = _extractColorsFromSVG(svgContent);
    final viewBox = _extractViewBox(svgContent);

    return SVGFeatures(
      pathCount: pathCount,
      circleCount: circleCount,
      rectCount: rectCount,
      groupCount: groupCount,
      colors: colors,
      viewBox: viewBox,
      contentLength: svgContent.length,
    );
  }

  LottieFeatures _extractLottieFeatures(Map<String, dynamic> lottieJson) {
    final frameRate = (lottieJson['fr'] as num?)?.toDouble() ?? 0.0;
    final inPoint = (lottieJson['ip'] as num?)?.toDouble() ?? 0.0;
    final outPoint = (lottieJson['op'] as num?)?.toDouble() ?? 0.0;
    final version = lottieJson['v'] as String? ?? '';

    final layers = lottieJson['layers'] as List<dynamic>? ?? [];
    final assets = lottieJson['assets'] as List<dynamic>? ?? [];

    return LottieFeatures(
      frameRate: frameRate,
      inPoint: inPoint,
      outPoint: outPoint,
      duration: outPoint - inPoint,
      version: version,
      layerCount: layers.length,
      assetCount: assets.length,
    );
  }

  double _compareSVGFeatures(SVGFeatures features1, SVGFeatures features2) {
    double similarity = 0.0;

    // Structural similarity (40% weight)
    final pathSimilarity = _normalizedSimilarity(features1.pathCount, features2.pathCount, 100);
    final circleSimilarity = _normalizedSimilarity(features1.circleCount, features2.circleCount, 50);
    final rectSimilarity = _normalizedSimilarity(features1.rectCount, features2.rectCount, 50);
    final groupSimilarity = _normalizedSimilarity(features1.groupCount, features2.groupCount, 50);

    final structuralSimilarity =
        (pathSimilarity * 0.4 + circleSimilarity * 0.2 + rectSimilarity * 0.2 + groupSimilarity * 0.2);
    similarity += structuralSimilarity * 0.4;

    // Color similarity (35% weight)
    final colorSimilarity = _calculateColorSetSimilarity(features1.colors, features2.colors);
    similarity += colorSimilarity * 0.35;

    // Size/complexity similarity (25% weight)
    final sizeSimilarity = _normalizedSimilarity(features1.contentLength, features2.contentLength, 10000);
    similarity += sizeSimilarity * 0.25;

    return similarity.clamp(0.0, 1.0);
  }

  double _compareLottieFeatures(LottieFeatures features1, LottieFeatures features2) {
    double similarity = 0.0;

    similarity += _normalizedSimilarity(features1.frameRate, features2.frameRate, 60) * 0.2;
    similarity += _normalizedSimilarity(features1.duration, features2.duration, 300) * 0.25;
    similarity += _normalizedSimilarity(features1.layerCount, features2.layerCount, 100) * 0.25;
    similarity += _normalizedSimilarity(features1.assetCount, features2.assetCount, 50) * 0.2;

    final versionSimilarity = features1.version == features2.version ? 1.0 : 0.8;
    similarity += versionSimilarity * 0.1;

    return similarity.clamp(0.0, 1.0);
  }

  double _normalizedSimilarity(num value1, num value2, num maxExpected) {
    final diff = (value1 - value2).abs();
    final maxDiff = maxExpected;
    return (maxDiff - diff) / maxDiff;
  }

  double _calculateColorSetSimilarity(Set<String> colors1, Set<String> colors2) {
    if (colors1.isEmpty && colors2.isEmpty) return 1.0;
    if (colors1.isEmpty || colors2.isEmpty) return 0.0;

    final intersection = colors1.intersection(colors2);
    final union = colors1.union(colors2);

    return intersection.length / union.length;
  }

  Set<String> _extractColorsFromSVG(String svgContent) {
    final colors = <String>{};
    final colorRegex = RegExp(r'(?:fill|stroke)="([^"]*)"', caseSensitive: false);

    for (final match in colorRegex.allMatches(svgContent)) {
      final color = match.group(1);
      if (color != null && color != 'none' && color.isNotEmpty) {
        colors.add(color.toLowerCase());
      }
    }

    return colors;
  }

  String? _extractViewBox(String svgContent) {
    final viewBoxRegex = RegExp(r'viewBox="([^"]*)"', caseSensitive: false);
    final match = viewBoxRegex.firstMatch(svgContent);
    return match?.group(1);
  }

  Future<VectorType> _determineVectorType(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'svg':
        return VectorType.svg;
      case 'json':
        return await _isLottieFile(filePath) ? VectorType.lottie : VectorType.unknown;
      case 'riv':
        return VectorType.rive;
      default:
        return VectorType.unknown;
    }
  }

  Future<bool> _isLottieFile(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      return content.contains('"v":') || content.contains('"version":') || content.contains('bodymovin');
    } catch (e) {
      return false;
    }
  }

  bool _isVectorAsset(AssetModel asset) {
    return asset.type == AssetType.svg || asset.type == AssetType.lottie || asset.type == AssetType.rive;
  }

  Future<String> _generateVectorHash(String vectorPath) async {
    final file = File(vectorPath);
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  SimilarityMatchType _determineMatchType(double similarity) {
    if (similarity >= 0.95) return SimilarityMatchType.exact;
    if (similarity >= 0.80) return SimilarityMatchType.nearDuplicate;
    if (similarity >= 0.60) return SimilarityMatchType.visuallySimilar;
    if (similarity >= 0.40) return SimilarityMatchType.structurallySimilar;
    return SimilarityMatchType.conceptuallySimilar;
  }
}

enum VectorType { svg, lottie, rive, unknown }

class SVGFeatures {
  const SVGFeatures({
    required this.pathCount,
    required this.circleCount,
    required this.rectCount,
    required this.groupCount,
    required this.colors,
    required this.viewBox,
    required this.contentLength,
  });

  final int pathCount;
  final int circleCount;
  final int rectCount;
  final int groupCount;
  final Set<String> colors;
  final String? viewBox;
  final int contentLength;
}

class LottieFeatures {
  const LottieFeatures({
    required this.frameRate,
    required this.inPoint,
    required this.outPoint,
    required this.duration,
    required this.version,
    required this.layerCount,
    required this.assetCount,
  });

  final double frameRate;
  final double inPoint;
  final double outPoint;
  final double duration;
  final String version;
  final int layerCount;
  final int assetCount;
}
