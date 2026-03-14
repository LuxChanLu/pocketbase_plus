import 'package:yaml/yaml.dart';

/// Configuration for PocketBase connection and model generation.
class Config {
  final String domain;
  final String email;
  final String password;
  final String outputDirectory;

  Config({
    required this.domain,
    required this.email,
    required this.password,
    required this.outputDirectory,
  });

  Config copyWith({
    String? domain,
    String? email,
    String? password,
    String? outputDirectory,
  }) {
    return Config(
      domain: domain ?? this.domain,
      email: email ?? this.email,
      password: password ?? this.password,
      outputDirectory: outputDirectory ?? this.outputDirectory,
    );
  }

  factory Config.fromYaml(YamlMap yaml) {
    final pbConfig = yaml['pocketbase'];
    if (pbConfig == null) {
      throw Exception('Missing "pocketbase" section in configuration.');
    }

    final hostingConfig = pbConfig['hosting'];
    if (hostingConfig == null) {
      throw Exception(
          'Missing "hosting" section under "pocketbase" in configuration.');
    }

    final domain = hostingConfig['domain'];
    final email = hostingConfig['email'];
    final password = hostingConfig['password'];

    if (domain == null || email == null || password == null) {
      throw Exception(
          'Missing "domain", "email", or "password" in hosting configuration.');
    }

    final outputDirectory = pbConfig['output_directory'] ?? './lib/models';

    return Config(
      domain: domain,
      email: email,
      password: password,
      outputDirectory: outputDirectory,
    );
  }
}
