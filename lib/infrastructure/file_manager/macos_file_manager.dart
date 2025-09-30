import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../core/contracts/file_manager_contract.dart';

class MacOSFileManager implements FileManagerContract {
  static const List<String> _supportedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'svg',
    'json',
    'riv',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  @override
  Future<String?> selectDirectory({String? initialDirectory}) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Asset Directory',
        lockParentWindow: true,
        initialDirectory: initialDirectory,
      );
      return result;
    } catch (e) {
      throw FileManagerException('Failed to select directory: $e');
    }
  }

  @override
  Future<String?> selectFile({
    List<String>? allowedExtensions,
    String? initialDirectory,
  }) async {
    try {
      final extensions = allowedExtensions ?? _supportedExtensions;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
        dialogTitle: 'Select Asset File',
        lockParentWindow: true,
        initialDirectory: initialDirectory,
      );

      return result?.files.single.path;
    } catch (e) {
      throw FileManagerException('Failed to select file: $e');
    }
  }

  @override
  Future<bool> hasDirectoryAccess(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return false;

      final testFile = File(path.join(directoryPath, '.access_test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getFilesInDirectory(
    String directoryPath, {
    bool recursive = true,
    List<String>? extensions,
  }) async {
    try {
      if (!await hasDirectoryAccess(directoryPath)) {
        throw FileManagerException('No access to directory: $directoryPath');
      }

      final directory = Directory(directoryPath);
      final targetExtensions = extensions ?? _supportedExtensions;
      final files = <String>[];

      await for (final entity in directory.list(
        recursive: recursive,
        followLinks: false,
      )) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          final extensionWithoutDot = extension.startsWith('.')
              ? extension.substring(1)
              : extension;

          if (targetExtensions.contains(extensionWithoutDot)) {
            files.add(entity.path);
          }
        }
      }

      files.sort((a, b) => path.basename(a).compareTo(path.basename(b)));
      return files;
    } catch (e) {
      throw FileManagerException('Failed to scan directory: $e');
    }
  }
}

class FileManagerException implements Exception {
  const FileManagerException(this.message);

  final String message;

  @override
  String toString() => 'FileManagerException: $message';
}