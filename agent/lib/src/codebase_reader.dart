import 'dart:io';

/// Reads local codebase files for investigation.
/// Used when the agent runs locally alongside the repository.
class CodebaseReader {
  final String repoPath;

  CodebaseReader({required this.repoPath});

  /// Lists all source files in the repository.
  List<String> listSourceFiles() {
    final dir = Directory(repoPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => _isSourceFile(f.path))
        .where((f) => !_isIgnored(f.path))
        .map((f) => f.path.substring(repoPath.length + 1))
        .toList();
  }

  /// Reads a file's content.
  String? readFile(String relativePath) {
    final file = File('$repoPath/$relativePath');
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  /// Reads multiple files.
  Map<String, String> readFiles(List<String> paths) {
    final result = <String, String>{};
    for (final path in paths) {
      final content = readFile(path);
      if (content != null) result[path] = content;
    }
    return result;
  }

  bool _isSourceFile(String path) {
    const extensions = [
      '.dart', '.py', '.js', '.ts', '.java', '.kt', '.go',
      '.rs', '.rb', '.swift', '.c', '.cpp', '.h',
      '.yaml', '.yml', '.json', '.toml',
    ];
    return extensions.any(path.endsWith);
  }

  bool _isIgnored(String path) {
    const ignored = [
      '.dart_tool',
      '.git',
      'build',
      'node_modules',
      '.pub-cache',
    ];
    return ignored.any((d) => path.contains('/$d/') || path.contains('/$d'));
  }
}
