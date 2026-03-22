import 'dart:convert';
import 'dart:io';

/// Ghost Maintainer configuration, stored as .ghost_maintainer.json in the repo.
class GhostConfig {
  static const fileName = '.ghost_maintainer.json';

  /// Automatically investigate bugs and create PRs.
  bool autoFixBugs;

  GhostConfig({
    this.autoFixBugs = true,
  });

  factory GhostConfig.fromJson(Map<String, dynamic> json) {
    return GhostConfig(
      autoFixBugs: json['auto_fix_bugs'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'auto_fix_bugs': autoFixBugs,
      };

  /// Load config from the current directory or return defaults.
  static GhostConfig load([String? path]) {
    final file = File(path ?? fileName);
    if (file.existsSync()) {
      try {
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        return GhostConfig.fromJson(json);
      } catch (_) {
        return GhostConfig();
      }
    }
    return GhostConfig();
  }

  /// Save config to file.
  void save([String? path]) {
    final encoder = JsonEncoder.withIndent('  ');
    File(path ?? fileName).writeAsStringSync('${encoder.convert(toJson())}\n');
  }

  @override
  String toString() {
    return 'auto_fix_bugs: $autoFixBugs';
  }
}
