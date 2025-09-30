import 'package:equatable/equatable.dart';

enum AssetType {
  image,
  svg,
  lottie,
  rive,
  video,
  unknown,
}

enum AssetFormat {
  png,
  jpg,
  jpeg,
  webp,
  svg,
  json,
  riv,
  mp4,
  mov,
  avi,
  mkv,
  webm,
  unknown,
}

class AssetModel extends Equatable {
  const AssetModel({
    required this.path,
    required this.name,
    required this.type,
    required this.format,
    required this.size,
    required this.lastModified,
    this.thumbnailPath,
    this.metadata,
  });

  final String path;
  final String name;
  final AssetType type;
  final AssetFormat format;
  final int size;
  final DateTime lastModified;
  final String? thumbnailPath;
  final Map<String, dynamic>? metadata;

  AssetModel copyWith({
    String? path,
    String? name,
    AssetType? type,
    AssetFormat? format,
    int? size,
    DateTime? lastModified,
    String? thumbnailPath,
    Map<String, dynamic>? metadata,
  }) {
    return AssetModel(
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      format: format ?? this.format,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        path,
        name,
        type,
        format,
        size,
        lastModified,
        thumbnailPath,
        metadata,
      ];
}

class SimilarityResult extends Equatable {
  const SimilarityResult({
    required this.asset,
    required this.similarity,
    required this.matchType,
  });

  final AssetModel asset;
  final double similarity;
  final SimilarityMatchType matchType;

  @override
  List<Object?> get props => [asset, similarity, matchType];
}

enum SimilarityMatchType {
  exact,
  nearDuplicate,
  visuallySimilar,
  structurallySimilar,
  conceptuallySimilar,
}