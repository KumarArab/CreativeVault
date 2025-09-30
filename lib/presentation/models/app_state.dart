import 'package:equatable/equatable.dart';

import '../../core/models/asset_model.dart';

enum AppStatus {
  initial,
  pathSelected,
  scanning,
  assetsLoaded,
  uploadingAsset,
  findingSimilarAssets,
  error,
}

enum AssetTypeFilter {
  all,
  images,
  vectors,
  lotties,
  rives,
  videos,
}

class AppState extends Equatable {
  const AppState({
    this.status = AppStatus.initial,
    this.selectedPath,
    this.assets = const [],
    this.uploadedAsset,
    this.similarAssets = const [],
    this.exactMatches = const [],
    this.errorMessage,
    this.scanProgress = 0.0,
    this.selectedFilter = AssetTypeFilter.all,
  });

  final AppStatus status;
  final String? selectedPath;
  final List<AssetModel> assets;
  final AssetModel? uploadedAsset;
  final List<SimilarityResult> similarAssets;
  final List<AssetModel> exactMatches;
  final String? errorMessage;
  final double scanProgress;
  final AssetTypeFilter selectedFilter;

  AppState copyWith({
    AppStatus? status,
    String? selectedPath,
    List<AssetModel>? assets,
    AssetModel? uploadedAsset,
    List<SimilarityResult>? similarAssets,
    List<AssetModel>? exactMatches,
    String? errorMessage,
    double? scanProgress,
    AssetTypeFilter? selectedFilter,
  }) {
    return AppState(
      status: status ?? this.status,
      selectedPath: selectedPath ?? this.selectedPath,
      assets: assets ?? this.assets,
      uploadedAsset: uploadedAsset ?? this.uploadedAsset,
      similarAssets: similarAssets ?? this.similarAssets,
      exactMatches: exactMatches ?? this.exactMatches,
      errorMessage: errorMessage ?? this.errorMessage,
      scanProgress: scanProgress ?? this.scanProgress,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedPath,
        assets,
        uploadedAsset,
        similarAssets,
        exactMatches,
        errorMessage,
        scanProgress,
        selectedFilter,
      ];
}