abstract class FileManagerContract {
  Future<String?> selectDirectory({String? initialDirectory});
  Future<String?> selectFile({List<String>? allowedExtensions, String? initialDirectory});
  Future<bool> hasDirectoryAccess(String directoryPath);
  Future<List<String>> getFilesInDirectory(
    String directoryPath, {
    bool recursive = true,
    List<String>? extensions,
  });
}