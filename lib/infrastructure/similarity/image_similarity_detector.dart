import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

import '../../core/models/asset_model.dart';

class ImageSimilarityDetector {
  static const int _imageSize = 64; // Resize to 64x64 for better histogram accuracy
  static const int _histogramBins = 256; // Full 256 bins for each color channel
  static const double _exactMatchThreshold = 0.95;
  static const double _nearDuplicateThreshold = 0.85;
  static const double _visuallySimilarThreshold = 0.70;
  static const double _minSimilarityThreshold = 0.3; // Lower threshold for initial filtering

  Future<List<SimilarityResult>> findSimilarImages(String targetImagePath, List<AssetModel> imageAssets) async {
    final results = <SimilarityResult>[];
    final targetHashes = await _generateImageHashes(targetImagePath);

    if (targetHashes == null) return results;

    for (final asset in imageAssets) {
      if (asset.type != AssetType.image) continue;

      try {
        final similarity = await _calculateImageSimilarity(targetHashes, asset.path);

        if (similarity > _minSimilarityThreshold) {
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

  // Find similar assets visually (works with images AND vectors)
  Future<List<SimilarityResult>> findSimilarAssetsVisually(String targetImagePath, List<AssetModel> allAssets) async {
    final results = <SimilarityResult>[];
    final targetHashes = await _generateImageHashes(targetImagePath);

    if (targetHashes == null) {
      return results;
    }

    for (final asset in allAssets) {
      try {
        double similarity = 0.0;

        if (asset.type == AssetType.image) {
          similarity = await _calculateImageSimilarity(targetHashes, asset.path);
        } else if (asset.type == AssetType.svg) {
          // Convert SVG to image for visual comparison
          similarity = await _calculateSvgToImageSimilarity(targetHashes, asset.path);
        } else {
          // Skip other types (lottie, rive, etc.)
          continue;
        }

        if (similarity > _minSimilarityThreshold) {
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

  // Calculate visual similarity between any two assets
  Future<double> calculateVisualSimilarity(String assetPath1, String assetPath2) async {
    try {
      final hashes1 = await _generateImageHashes(assetPath1);
      if (hashes1 == null) {
        return 0.0;
      }

      // Determine what type the second asset is
      final extension2 = assetPath2.split('.').last.toLowerCase();
      if (extension2 == 'svg') {
        return await _calculateSvgToImageSimilarity(hashes1, assetPath2);
      } else {
        // Treat as regular image
        final hashes2 = await _generateImageHashes(assetPath2);
        if (hashes2 == null) return 0.0;
        return _calculateHashSimilarity(hashes1, hashes2);
      }
    } catch (e) {
      return 0.0;
    }
  }

  Future<bool> areImagesIdentical(String imagePath1, String imagePath2) async {
    try {
      final similarity = await calculateImageSimilarity(imagePath1, imagePath2);
      final isIdentical = similarity >= _exactMatchThreshold;
      return isIdentical;
    } catch (e) {
      return false;
    }
  }

  Future<double> calculateImageSimilarity(String imagePath1, String imagePath2) async {
    try {
      final hashes1 = await _generateImageHashes(imagePath1);
      final hashes2 = await _generateImageHashes(imagePath2);

      if (hashes1 == null || hashes2 == null) return 0.0;

      return _calculateHashSimilarity(hashes1, hashes2);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateImageSimilarity(ImageHashes targetHashes, String assetPath) async {
    final assetHashes = await _generateImageHashes(assetPath);
    if (assetHashes == null) return 0.0;

    return _calculateHashSimilarity(targetHashes, assetHashes);
  }

  double _calculateHashSimilarity(ImageHashes hashes1, ImageHashes hashes2) {
    // Calculate histogram similarities for each color channel
    final redSimilarity = _calculateHistogramSimilarity(hashes1.redHistogram, hashes2.redHistogram);
    final greenSimilarity = _calculateHistogramSimilarity(hashes1.greenHistogram, hashes2.greenHistogram);
    final blueSimilarity = _calculateHistogramSimilarity(hashes1.blueHistogram, hashes2.blueHistogram);
    final grayscaleSimilarity = _calculateHistogramSimilarity(hashes1.grayscaleHistogram, hashes2.grayscaleHistogram);

    // Calculate color moments similarity
    final colorMomentsSimilarity = _calculateColorMomentsSimilarity(hashes1.colorMoments, hashes2.colorMoments);

    // Weighted combination of all similarity measures
    final compositeSimilarity =
        (redSimilarity * 0.2) +
        (greenSimilarity * 0.2) +
        (blueSimilarity * 0.2) +
        (grayscaleSimilarity * 0.2) +
        (colorMomentsSimilarity * 0.2);

    return compositeSimilarity.clamp(0.0, 1.0);
  }

  Future<ImageHashes?> _generateImageHashes(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to standard size for consistent processing
      final resized = img.copyResize(image, width: _imageSize, height: _imageSize);

      return ImageHashes(
        redHistogram: _generateColorHistogram(resized, 'red'),
        greenHistogram: _generateColorHistogram(resized, 'green'),
        blueHistogram: _generateColorHistogram(resized, 'blue'),
        grayscaleHistogram: _generateGrayscaleHistogram(resized),
        colorMoments: _calculateColorMoments(resized),
      );
    } catch (e) {
      return null;
    }
  }

  List<int> _generateColorHistogram(img.Image image, String channel) {
    final histogram = List.filled(_histogramBins, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        int value;

        switch (channel) {
          case 'red':
            value = pixel.r.toInt();
            break;
          case 'green':
            value = pixel.g.toInt();
            break;
          case 'blue':
            value = pixel.b.toInt();
            break;
          default:
            value = 0;
        }

        if (value >= 0 && value < _histogramBins) {
          histogram[value]++;
        }
      }
    }

    return histogram;
  }

  List<int> _generateGrayscaleHistogram(img.Image image) {
    final histogram = List.filled(_histogramBins, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = img.getLuminanceRgb(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()).toInt();

        if (gray >= 0 && gray < _histogramBins) {
          histogram[gray]++;
        }
      }
    }

    return histogram;
  }

  Map<String, double> _calculateColorMoments(img.Image image) {
    double rSum = 0, gSum = 0, bSum = 0;
    double rSumSq = 0, gSumSq = 0, bSumSq = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        rSum += r;
        gSum += g;
        bSum += b;

        rSumSq += r * r;
        gSumSq += g * g;
        bSumSq += b * b;

        pixelCount++;
      }
    }

    if (pixelCount == 0) {
      return {'rMean': 0.0, 'gMean': 0.0, 'bMean': 0.0, 'rStd': 0.0, 'gStd': 0.0, 'bStd': 0.0};
    }

    final rMean = rSum / pixelCount;
    final gMean = gSum / pixelCount;
    final bMean = bSum / pixelCount;

    final rStd = sqrt((rSumSq / pixelCount) - (rMean * rMean));
    final gStd = sqrt((gSumSq / pixelCount) - (gMean * gMean));
    final bStd = sqrt((bSumSq / pixelCount) - (bMean * bMean));

    return {'rMean': rMean, 'gMean': gMean, 'bMean': bMean, 'rStd': rStd, 'gStd': gStd, 'bStd': bStd};
  }

  double _calculateHistogramSimilarity(List<int> hist1, List<int> hist2) {
    if (hist1.length != hist2.length) return 0.0;

    // Calculate histogram intersection
    int intersection = 0;
    int total1 = 0;
    int total2 = 0;

    for (int i = 0; i < hist1.length; i++) {
      intersection += min(hist1[i], hist2[i]);
      total1 += hist1[i];
      total2 += hist2[i];
    }

    if (total1 == 0 && total2 == 0) return 1.0;
    if (total1 == 0 || total2 == 0) return 0.0;

    // Normalize by the smaller total
    final minTotal = min(total1, total2);
    return intersection / minTotal;
  }

  double _calculateColorMomentsSimilarity(Map<String, double> moments1, Map<String, double> moments2) {
    // Calculate similarity based on color moments
    final rMeanDiff = (moments1['rMean']! - moments2['rMean']!).abs();
    final gMeanDiff = (moments1['gMean']! - moments2['gMean']!).abs();
    final bMeanDiff = (moments1['bMean']! - moments2['bMean']!).abs();

    final rStdDiff = (moments1['rStd']! - moments2['rStd']!).abs();
    final gStdDiff = (moments1['gStd']! - moments2['gStd']!).abs();
    final bStdDiff = (moments1['bStd']! - moments2['bStd']!).abs();

    // Normalize differences (assuming max values around 255)
    final meanSimilarity = 1.0 - ((rMeanDiff + gMeanDiff + bMeanDiff) / (3.0 * 255.0));
    final stdSimilarity = 1.0 - ((rStdDiff + gStdDiff + bStdDiff) / (3.0 * 128.0));

    return (meanSimilarity + stdSimilarity) / 2.0;
  }

  Future<double> _calculateSvgToImageSimilarity(ImageHashes targetImageHashes, String svgPath) async {
    try {
      // For SVGs, we'll use a more sophisticated approach
      final svgFile = File(svgPath);
      if (!await svgFile.exists()) return 0.0;

      final svgContent = await svgFile.readAsString();

      // Extract SVG characteristics
      final svgMetrics = _extractSvgMetrics(svgContent);
      final imageMetrics = _extractImageMetrics(targetImageHashes);

      // Calculate similarity based on multiple factors
      double similarity = 0.0;

      // 1. Color similarity (40% weight)
      final colorSimilarity = _calculateSvgColorSimilarity(svgContent, targetImageHashes);
      similarity += colorSimilarity * 0.4;

      // 2. Complexity similarity (30% weight)
      final complexityDiff = (svgMetrics['complexity']! - imageMetrics['complexity']!).abs();
      final complexitySimilarity = (1.0 - (complexityDiff / 10.0).clamp(0.0, 1.0));
      similarity += complexitySimilarity * 0.3;

      // 3. Aspect ratio similarity (30% weight)
      final aspectDiff = (svgMetrics['aspectRatio']! - imageMetrics['aspectRatio']!).abs();
      final aspectSimilarity = (1.0 - aspectDiff.clamp(0.0, 1.0));
      similarity += aspectSimilarity * 0.3;

      return similarity.clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  Map<String, double> _extractSvgMetrics(String svgContent) {
    // Basic SVG analysis
    final hasColor = svgContent.contains('fill=') && !svgContent.contains('fill="none"');
    final elementCount = '<'.allMatches(svgContent).length;
    final complexity = (elementCount / 50.0).clamp(0.0, 10.0);

    // Try to extract viewBox for aspect ratio
    double aspectRatio = 1.0;
    final viewBoxMatch = RegExp(r'viewBox="([^"]*)"').firstMatch(svgContent);
    if (viewBoxMatch != null) {
      final viewBox = viewBoxMatch.group(1)?.split(' ');
      if (viewBox != null && viewBox.length >= 4) {
        final width = double.tryParse(viewBox[2]) ?? 1.0;
        final height = double.tryParse(viewBox[3]) ?? 1.0;
        aspectRatio = width / height;
      }
    }

    return {'hasColor': hasColor ? 1.0 : 0.0, 'complexity': complexity, 'aspectRatio': aspectRatio};
  }

  Map<String, double> _extractImageMetrics(ImageHashes hashes) {
    // Extract basic metrics from image hashes
    final colorVariation = hashes.redHistogram.where((count) => count > 0).length / _histogramBins;
    final hasColor = colorVariation > 0.1 ? 1.0 : 0.0;

    // Complexity based on histogram variation
    final totalPixels = hashes.redHistogram.reduce((a, b) => a + b);
    if (totalPixels == 0) {
      return {'hasColor': 0.0, 'complexity': 0.0, 'aspectRatio': 1.0};
    }

    // Calculate entropy as complexity measure
    double entropy = 0.0;
    for (int i = 0; i < hashes.redHistogram.length; i++) {
      if (hashes.redHistogram[i] > 0) {
        final p = hashes.redHistogram[i] / totalPixels;
        entropy -= p * log(p);
      }
    }
    final complexity = (entropy / log(_histogramBins)).clamp(0.0, 10.0);

    return {
      'hasColor': hasColor,
      'complexity': complexity,
      'aspectRatio': 1.0, // Default, would need actual image dimensions
    };
  }

  double _calculateSvgColorSimilarity(String svgContent, ImageHashes imageHashes) {
    // Extract colors from SVG
    final svgColors = _extractColorsFromSvg(svgContent);

    // Convert image color histogram to a set of dominant colors
    final imageColors = _extractDominantColorsFromHistogram(
      imageHashes.redHistogram,
      imageHashes.greenHistogram,
      imageHashes.blueHistogram,
    );

    if (svgColors.isEmpty && imageColors.isEmpty) return 1.0;
    if (svgColors.isEmpty || imageColors.isEmpty) return 0.0;

    // Calculate color set similarity
    final intersection = svgColors.intersection(imageColors);
    final union = svgColors.union(imageColors);

    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  Set<String> _extractColorsFromSvg(String svgContent) {
    final colors = <String>{};
    final colorRegex = RegExp(r'(?:fill|stroke)="([^"]*)"', caseSensitive: false);

    for (final match in colorRegex.allMatches(svgContent)) {
      final color = match.group(1);
      if (color != null && color != 'none' && color.isNotEmpty) {
        // Normalize color to basic categories
        final normalizedColor = _normalizeColor(color);
        if (normalizedColor.isNotEmpty) {
          colors.add(normalizedColor);
        }
      }
    }

    return colors;
  }

  String _normalizeColor(String color) {
    // Convert common color names and hex values to basic categories
    final lowerColor = color.toLowerCase();

    if (lowerColor.contains('red') || lowerColor.contains('#ff') || lowerColor.contains('#f00')) {
      return 'red';
    } else if (lowerColor.contains('blue') || lowerColor.contains('#00f') || lowerColor.contains('#0000ff')) {
      return 'blue';
    } else if (lowerColor.contains('green') || lowerColor.contains('#0f0') || lowerColor.contains('#00ff00')) {
      return 'green';
    } else if (lowerColor.contains('black') || lowerColor.contains('#000') || lowerColor.contains('#000000')) {
      return 'black';
    } else if (lowerColor.contains('white') || lowerColor.contains('#fff') || lowerColor.contains('#ffffff')) {
      return 'white';
    } else if (lowerColor.contains('gray') || lowerColor.contains('grey')) {
      return 'gray';
    }

    return ''; // Unknown color
  }

  Set<String> _extractDominantColorsFromHistogram(List<int> redHist, List<int> greenHist, List<int> blueHist) {
    final colors = <String>{};

    // Find dominant color bins
    final redTotal = redHist.reduce((a, b) => a + b);
    final greenTotal = greenHist.reduce((a, b) => a + b);
    final blueTotal = blueHist.reduce((a, b) => a + b);

    if (redTotal == 0 && greenTotal == 0 && blueTotal == 0) return colors;

    // Find dominant colors based on histogram peaks
    final redPeak = _findHistogramPeak(redHist);
    final greenPeak = _findHistogramPeak(greenHist);
    final bluePeak = _findHistogramPeak(blueHist);

    // Convert peaks to color categories
    if (redPeak > greenPeak && redPeak > bluePeak) {
      colors.add('red');
    } else if (greenPeak > redPeak && greenPeak > bluePeak) {
      colors.add('green');
    } else if (bluePeak > redPeak && bluePeak > greenPeak) {
      colors.add('blue');
    } else if (redPeak < 50 && greenPeak < 50 && bluePeak < 50) {
      colors.add('black');
    } else if (redPeak > 200 && greenPeak > 200 && bluePeak > 200) {
      colors.add('white');
    } else {
      colors.add('gray');
    }

    return colors;
  }

  int _findHistogramPeak(List<int> histogram) {
    int maxCount = 0;
    int peakIndex = 0;

    for (int i = 0; i < histogram.length; i++) {
      if (histogram[i] > maxCount) {
        maxCount = histogram[i];
        peakIndex = i;
      }
    }

    return peakIndex;
  }

  SimilarityMatchType _determineMatchType(double similarity) {
    if (similarity >= _exactMatchThreshold) return SimilarityMatchType.exact;
    if (similarity >= _nearDuplicateThreshold) return SimilarityMatchType.nearDuplicate;
    if (similarity >= _visuallySimilarThreshold) return SimilarityMatchType.visuallySimilar;
    return SimilarityMatchType.structurallySimilar;
  }
}

class ImageHashes {
  const ImageHashes({
    required this.redHistogram,
    required this.greenHistogram,
    required this.blueHistogram,
    required this.grayscaleHistogram,
    required this.colorMoments,
  });

  final List<int> redHistogram;
  final List<int> greenHistogram;
  final List<int> blueHistogram;
  final List<int> grayscaleHistogram;
  final Map<String, double> colorMoments;
}
