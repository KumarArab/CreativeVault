import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../../core/contracts/asset_scanner_contract.dart';
import '../../core/contracts/file_manager_contract.dart';
import '../../core/models/asset_model.dart';

class AssetScannerImpl implements AssetScannerContract {
  AssetScannerImpl({required this.fileManager});

  final FileManagerContract fileManager;

  static const Map<String, AssetFormat> _extensionToFormat = {
    'png': AssetFormat.png,
    'jpg': AssetFormat.jpg,
    'jpeg': AssetFormat.jpeg,
    'webp': AssetFormat.webp,
    'svg': AssetFormat.svg,
    'json': AssetFormat.json,
    'riv': AssetFormat.riv,
    'mp4': AssetFormat.mp4,
    'mov': AssetFormat.mov,
    'avi': AssetFormat.avi,
    'mkv': AssetFormat.mkv,
    'webm': AssetFormat.webm,
  };

  @override
  Future<List<AssetModel>> scanDirectory(String directoryPath) async {
    final assets = <AssetModel>[];

    await for (final asset in scanDirectoryStream(directoryPath)) {
      assets.add(asset);
    }

    return assets;
  }

  @override
  Stream<AssetModel> scanDirectoryStream(String directoryPath) async* {
    try {
      final filePaths = await fileManager.getFilesInDirectory(directoryPath);

      for (final filePath in filePaths) {
        if (await isAssetSupported(filePath)) {
          final asset = await _createAssetModel(filePath);
          if (asset != null) {
            yield asset;
          }
        }
      }
    } catch (e) {
      throw AssetScannerException('Failed to scan directory: $e');
    }
  }

  @override
  Future<bool> isAssetSupported(String filePath) async {
    try {
      final extension = _getFileExtension(filePath);
      return _extensionToFormat.containsKey(extension);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AssetType> determineAssetType(String filePath) async {
    final extension = _getFileExtension(filePath);
    final mimeType = lookupMimeType(filePath);

    switch (extension) {
      case 'svg':
        return AssetType.svg;
      case 'json':
        return await _isLottieFile(filePath) ? AssetType.lottie : AssetType.unknown;
      case 'riv':
        return AssetType.rive;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return AssetType.video;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return AssetType.image;
      default:
        if (mimeType?.startsWith('video/') == true) {
          return AssetType.video;
        } else if (mimeType?.startsWith('image/') == true) {
          return AssetType.image;
        }
        return AssetType.unknown;
    }
  }

  Future<AssetModel?> _createAssetModel(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final extension = _getFileExtension(filePath);
      final format = _extensionToFormat[extension] ?? AssetFormat.unknown;
      final type = await determineAssetType(filePath);

      return AssetModel(
        path: filePath,
        name: path.basenameWithoutExtension(filePath),
        type: type,
        format: format,
        size: stat.size,
        lastModified: stat.modified,
        metadata: await _extractMetadata(filePath, type),
      );
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _extractMetadata(String filePath, AssetType type) async {
    try {
      switch (type) {
        case AssetType.image:
        case AssetType.svg:
          return await _extractImageMetadata(filePath);
        case AssetType.lottie:
          return await _extractLottieMetadata(filePath);
        case AssetType.rive:
          return await _extractRiveMetadata(filePath);
        case AssetType.video:
          return await _extractVideoMetadata(filePath);
        case AssetType.unknown:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _extractImageMetadata(String filePath) async {
    return <String, dynamic>{
      'fileExtension': _getFileExtension(filePath),
      'extractedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>?> _extractLottieMetadata(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      return <String, dynamic>{
        'fileType': 'lottie',
        'contentLength': content.length,
        'extractedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _extractRiveMetadata(String filePath) async {
    return <String, dynamic>{'fileType': 'rive', 'extractedAt': DateTime.now().toIso8601String()};
  }

  Future<Map<String, dynamic>?> _extractVideoMetadata(String filePath) async {
    return <String, dynamic>{'fileType': 'video', 'extractedAt': DateTime.now().toIso8601String()};
  }

  Future<bool> _isLottieFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      return content.contains('"v":') || content.contains('"version":') || content.contains('bodymovin');
    } catch (e) {
      return false;
    }
  }

  String _getFileExtension(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return extension.startsWith('.') ? extension.substring(1) : extension;
  }
}

class AssetScannerException implements Exception {
  const AssetScannerException(this.message);

  final String message;

  @override
  String toString() => 'AssetScannerException: $message';
}
