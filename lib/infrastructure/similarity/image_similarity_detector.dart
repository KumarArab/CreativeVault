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
  static const double _minSimilarityThreshold = 0.75; // Higher threshold with proper structural analysis

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
      print('Could not generate hashes for target image: $targetImagePath');
      return results;
    }

    print('Comparing uploaded asset against ${allAssets.length} assets...');

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
          print('Found match: ${asset.name} with similarity ${(similarity * 100).toStringAsFixed(1)}%');
          results.add(
            SimilarityResult(asset: asset, similarity: similarity, matchType: _determineMatchType(similarity)),
          );
        } else if (similarity > 0.3) {
          print(
            'Near match: ${asset.name} with similarity ${(similarity * 100).toStringAsFixed(1)}% (below threshold)',
          );
        }
      } catch (e) {
        print('Error comparing with ${asset.name}: $e');
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

    // Calculate structural similarity (shape, composition, complexity)
    final structuralSimilarity = _calculateStructuralSimilarity(hashes1, hashes2);

    // Calculate color similarity
    final avgColorSimilarity = (redSimilarity + greenSimilarity + blueSimilarity) / 3.0;

    // CRITICAL: Both structural AND color similarity must be reasonable for a match
    // If either is very poor, the overall similarity should be low
    if (structuralSimilarity < 0.4 || avgColorSimilarity < 0.3) {
      // Heavily penalize poor structural or color matches
      return (structuralSimilarity * avgColorSimilarity * 0.5).clamp(0.0, 1.0);
    }

    // Weighted combination emphasizing structural similarity
    final compositeSimilarity =
        (structuralSimilarity * 0.50) + // 50% weight on structure/shape
        (avgColorSimilarity * 0.25) + // 25% weight on color
        (grayscaleSimilarity * 0.15) + // 15% weight on grayscale
        (colorMomentsSimilarity * 0.10); // 10% weight on color moments

    return compositeSimilarity.clamp(0.0, 1.0);
  }

  // Public method for cache access
  Future<ImageHashes?> generateImageHashes(String imagePath) async {
    return await _generateImageHashes(imagePath);
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

    if (total1 == 0 && total2 == 0) return 0.0; // Both empty = no similarity
    if (total1 == 0 || total2 == 0) return 0.0; // One empty = no similarity

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

  double _calculateStructuralSimilarity(ImageHashes hashes1, ImageHashes hashes2) {
    // Analyze structural properties: complexity, distribution, shape characteristics

    // 1. Complexity similarity (entropy-based)
    final complexity1 = _calculateComplexity(hashes1);
    final complexity2 = _calculateComplexity(hashes2);
    final complexitySimilarity = 1.0 - ((complexity1 - complexity2).abs() / max(complexity1, complexity2));

    // 2. Distribution similarity (how pixels are distributed)
    final distribution1 = _calculateDistribution(hashes1);
    final distribution2 = _calculateDistribution(hashes2);
    final distributionSimilarity = 1.0 - ((distribution1 - distribution2).abs() / max(distribution1, distribution2));

    // 3. Shape characteristics (based on grayscale patterns)
    final shapeSimilarity = _calculateShapeSimilarity(hashes1, hashes2);

    // 4. Color dominance patterns (which colors dominate)
    final dominanceSimilarity = _calculateDominanceSimilarity(hashes1, hashes2);

    // Weighted combination of structural factors
    final structuralSimilarity =
        (complexitySimilarity * 0.30) +
        (distributionSimilarity * 0.25) +
        (shapeSimilarity * 0.30) +
        (dominanceSimilarity * 0.15);

    return structuralSimilarity.clamp(0.0, 1.0);
  }

  double _calculateComplexity(ImageHashes hashes) {
    // Calculate entropy as a measure of complexity
    final totalPixels = hashes.grayscaleHistogram.reduce((a, b) => a + b);
    if (totalPixels == 0) return 0.0;

    double entropy = 0.0;
    for (int i = 0; i < hashes.grayscaleHistogram.length; i++) {
      if (hashes.grayscaleHistogram[i] > 0) {
        final p = hashes.grayscaleHistogram[i] / totalPixels;
        entropy -= p * log(p);
      }
    }

    return entropy / log(256.0); // Normalize to 0-1
  }

  double _calculateDistribution(ImageHashes hashes) {
    // Calculate how evenly distributed the pixels are
    final totalPixels = hashes.grayscaleHistogram.reduce((a, b) => a + b);
    if (totalPixels == 0) return 0.0;

    // Calculate variance in histogram
    final mean = totalPixels / hashes.grayscaleHistogram.length;
    double variance = 0.0;
    for (int count in hashes.grayscaleHistogram) {
      variance += pow(count - mean, 2);
    }
    variance /= hashes.grayscaleHistogram.length;

    return sqrt(variance) / mean; // Coefficient of variation
  }

  double _calculateShapeSimilarity(ImageHashes hashes1, ImageHashes hashes2) {
    // Compare grayscale patterns that indicate shape
    final pattern1 = _extractShapePattern(hashes1);
    final pattern2 = _extractShapePattern(hashes2);

    // Calculate correlation between patterns
    return _calculatePatternCorrelation(pattern1, pattern2);
  }

  List<double> _extractShapePattern(ImageHashes hashes) {
    // Extract key characteristics of the shape pattern
    final pattern = <double>[];

    // 1. Peak locations (dominant grayscale values)
    final peaks = _findHistogramPeaks(hashes.grayscaleHistogram);
    pattern.addAll(peaks.map((p) => p / 255.0));

    // 2. Contrast (difference between light and dark areas)
    final contrast = _calculateContrast(hashes.grayscaleHistogram);
    pattern.add(contrast);

    // 3. Symmetry (how symmetric the distribution is)
    final symmetry = _calculateSymmetry(hashes.grayscaleHistogram);
    pattern.add(symmetry);

    return pattern;
  }

  List<int> _findHistogramPeaks(List<int> histogram) {
    final peaks = <int>[];
    for (int i = 1; i < histogram.length - 1; i++) {
      if (histogram[i] > histogram[i - 1] && histogram[i] > histogram[i + 1] && histogram[i] > 10) {
        peaks.add(i);
      }
    }
    return peaks.take(5).toList(); // Top 5 peaks
  }

  double _calculateContrast(List<int> histogram) {
    final total = histogram.reduce((a, b) => a + b);
    if (total == 0) return 0.0;

    // Calculate standard deviation as contrast measure
    final mean = total / histogram.length;
    double variance = 0.0;
    for (int count in histogram) {
      variance += pow(count - mean, 2);
    }
    return sqrt(variance / histogram.length) / mean;
  }

  double _calculateSymmetry(List<int> histogram) {
    // Calculate how symmetric the histogram is around its center
    final center = histogram.length ~/ 2;
    double symmetry = 0.0;
    int comparisons = 0;

    for (int i = 0; i < center; i++) {
      final left = histogram[i];
      final right = histogram[histogram.length - 1 - i];
      if (left > 0 || right > 0) {
        symmetry += min(left, right) / max(left, right);
        comparisons++;
      }
    }

    return comparisons > 0 ? symmetry / comparisons : 0.0;
  }

  double _calculatePatternCorrelation(List<double> pattern1, List<double> pattern2) {
    if (pattern1.isEmpty || pattern2.isEmpty) return 0.0;

    final minLength = min(pattern1.length, pattern2.length);
    double correlation = 0.0;

    for (int i = 0; i < minLength; i++) {
      final diff = (pattern1[i] - pattern2[i]).abs();
      correlation += 1.0 - diff; // Higher when values are closer
    }

    return correlation / minLength;
  }

  double _calculateDominanceSimilarity(ImageHashes hashes1, ImageHashes hashes2) {
    // Compare which color channels dominate
    final dominance1 = _calculateColorDominance(hashes1);
    final dominance2 = _calculateColorDominance(hashes2);

    // Calculate similarity of dominance patterns
    double similarity = 0.0;
    similarity += 1.0 - (dominance1['red']! - dominance2['red']!).abs();
    similarity += 1.0 - (dominance1['green']! - dominance2['green']!).abs();
    similarity += 1.0 - (dominance1['blue']! - dominance2['blue']!).abs();

    return (similarity / 3.0).clamp(0.0, 1.0);
  }

  Map<String, double> _calculateColorDominance(ImageHashes hashes) {
    final redTotal = hashes.redHistogram.reduce((a, b) => a + b);
    final greenTotal = hashes.greenHistogram.reduce((a, b) => a + b);
    final blueTotal = hashes.blueHistogram.reduce((a, b) => a + b);
    final total = redTotal + greenTotal + blueTotal;

    if (total == 0) return {'red': 0.0, 'green': 0.0, 'blue': 0.0};

    return {'red': redTotal / total, 'green': greenTotal / total, 'blue': blueTotal / total};
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
