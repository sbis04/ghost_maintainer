import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';

import 'package:ghost_maintainer_mcp/src/config.dart';
import 'package:ghost_maintainer_mcp/src/server.dart';

void main() {
  final config = Config.fromEnv();
  final channel = stdioChannel(input: io.stdin, output: io.stdout);
  GhostMaintainerServer(channel, config: config);
}
