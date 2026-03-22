import 'dart:io';

import 'package:args/command_runner.dart';

import '../lib/commands/setup_command.dart';
import '../lib/commands/config_command.dart';
import '../lib/commands/sync_command.dart';
import '../lib/commands/deploy_webhook_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner<void>(
    'ghost_maintainer',
    'AI-powered maintenance partner for open-source projects.',
  )
    ..addCommand(SetupCommand())
    ..addCommand(ConfigCommand())
    ..addCommand(SyncCommand())
    ..addCommand(DeployWebhookCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    print(e);
    exit(1);
  }
}
