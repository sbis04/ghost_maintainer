import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubService {
  final String token;
  final _client = http.Client();
  static const _baseUrl = 'https://api.github.com';

  GitHubService({required this.token});

  Map<String, String> get _headers => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> getIssue(
    String owner,
    String repo,
    int issueNumber,
  ) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/issues/$issueNumber'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<String> getDefaultBranchSha(String owner, String repo) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo'),
      headers: _headers,
    );
    final repoData = _handleResponse(response);
    final defaultBranch = repoData['default_branch'] as String;

    final refResponse = await _client.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/git/ref/heads/$defaultBranch'),
      headers: _headers,
    );
    final refData = _handleResponse(refResponse);
    return refData['object']['sha'] as String;
  }

  Future<String> getDefaultBranch(String owner, String repo) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo'),
      headers: _headers,
    );
    final repoData = _handleResponse(response);
    return repoData['default_branch'] as String;
  }

  Future<void> createBranch(
    String owner,
    String repo,
    String branchName,
    String fromSha,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/repos/$owner/$repo/git/refs'),
      headers: _headers,
      body: jsonEncode({
        'ref': 'refs/heads/$branchName',
        'sha': fromSha,
      }),
    );
    _handleResponse(response);
  }

  Future<void> createOrUpdateFile(
    String owner,
    String repo,
    String path,
    String content,
    String message,
    String branch,
  ) async {
    // Check if file exists to get its sha
    String? existingSha;
    try {
      final existing = await _client.get(
        Uri.parse(
            '$_baseUrl/repos/$owner/$repo/contents/$path?ref=$branch'),
        headers: _headers,
      );
      if (existing.statusCode == 200) {
        final data = jsonDecode(existing.body) as Map<String, dynamic>;
        existingSha = data['sha'] as String?;
      }
    } catch (_) {
      // File doesn't exist, that's fine
    }

    final body = <String, dynamic>{
      'message': message,
      'content': base64Encode(utf8.encode(content)),
      'branch': branch,
    };
    if (existingSha != null) {
      body['sha'] = existingSha;
    }

    final response = await _client.put(
      Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _handleResponse(response);
  }

  Future<Map<String, dynamic>> createPullRequest(
    String owner,
    String repo, {
    required String title,
    required String body,
    required String head,
    required String base,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/repos/$owner/$repo/pulls'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'body': body,
        'head': head,
        'base': base,
      }),
    );
    return _handleResponse(response);
  }

  Future<List<Map<String, dynamic>>> getRepoTree(
    String owner,
    String repo, {
    String? branch,
  }) async {
    final ref = branch ?? 'HEAD';
    final response = await _client.get(
      Uri.parse(
          '$_baseUrl/repos/$owner/$repo/git/trees/$ref?recursive=1'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return (data['tree'] as List).cast<Map<String, dynamic>>();
  }

  Future<String> getFileContent(
    String owner,
    String repo,
    String path, {
    String? branch,
  }) async {
    final queryParams = branch != null ? '?ref=$branch' : '';
    final response = await _client.get(
      Uri.parse(
          '$_baseUrl/repos/$owner/$repo/contents/$path$queryParams'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    final encoded = data['content'] as String;
    return utf8.decode(base64Decode(encoded.replaceAll('\n', '')));
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw GitHubApiException(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  void dispose() => _client.close();
}

class GitHubApiException implements Exception {
  final int statusCode;
  final String body;

  GitHubApiException({required this.statusCode, required this.body});

  @override
  String toString() => 'GitHubApiException($statusCode): $body';
}
