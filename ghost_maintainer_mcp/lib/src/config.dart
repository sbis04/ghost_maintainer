import 'dart:io';

class Config {
  final String notionToken;
  final String notionDatabaseId;
  final String notionVisionPageId;
  final String githubToken;
  final String targetRepo;
  final String geminiApiKey;

  Config({
    required this.notionToken,
    required this.notionDatabaseId,
    required this.notionVisionPageId,
    required this.githubToken,
    required this.targetRepo,
    required this.geminiApiKey,
  });

  factory Config.fromEnv() {
    String require(String key) {
      final value = Platform.environment[key];
      if (value == null || value.isEmpty) {
        throw StateError('Missing required environment variable: $key');
      }
      return value;
    }

    return Config(
      notionToken: require('NOTION_TOKEN'),
      notionDatabaseId: require('NOTION_DATABASE_ID'),
      notionVisionPageId: require('NOTION_VISION_PAGE_ID'),
      githubToken: require('GITHUB_TOKEN'),
      targetRepo: require('TARGET_REPO'),
      geminiApiKey: require('GEMINI_API_KEY'),
    );
  }

  String get repoOwner => targetRepo.split('/')[0];
  String get repoName => targetRepo.split('/')[1];
}
