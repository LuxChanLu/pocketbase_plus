# AGENTS.md - Coding Guidelines for pocketbase_plus

This document provides essential information for agentic coding agents working in this Dart package repository.

## Project Overview

Pocketbase Plus is a Dart package that automates model generation for PocketBase projects. It fetches collection schemas from PocketBase and generates type-safe Dart model classes.

**PocketBase SDK Version:** Requires PocketBase Dart SDK >=0.23.0 (compatible with PocketBase v0.23.0+)

**Breaking Changes from 0.18.x:**
- `SchemaField` is now `CollectionField`
- `CollectionModel.schema` is now `CollectionModel.fields`
- `RecordModel.created/updated` properties are deprecated; use `r.get<String>('created')` instead
- `pb.admins` is deprecated; use `pb.collection('_superusers')` for admin authentication

## Build/Lint/Test Commands

### Running the Generator
```bash
# Run with default config (./pocketbase.yaml)
dart run pocketbase_plus:main

# Run with custom config file
dart run pocketbase_plus:main --config pubspec.yaml
dart run pocketbase_plus:main -c path/to/config.yaml

# Show help
dart run pocketbase_plus:main --help
```

### Testing
```bash
# Run all tests
dart test

# Run a specific test file
dart test test/pocketbase_plus_test.dart

# Run tests with verbose output
dart test --reporter=expanded

# Run tests with coverage
dart test --coverage=coverage
```

### Linting & Analysis
```bash
# Run static analysis
dart analyze

# Check for issues without fixing
dart analyze --fatal-infos

# Format code (check without modifying)
dart format --output=none --set-exit-if-changed .
```

### Formatting
```bash
# Format all Dart files
dart format .

# Format specific directory
dart format lib/
dart format bin/

# Format specific file
dart format lib/src/models.dart
```

### Package Management
```bash
# Get dependencies
dart pub get

# Upgrade dependencies
dart pub upgrade

# Check for outdated dependencies
dart pub outdated
```

## Code Style Guidelines

### Naming Conventions

**Files & Directories:**
- Snake_case for file names: `models.dart`, `main.dart`
- Directory names should be snake_case: `lib/src/`

**Variables & Parameters:**
- camelCase for variables and parameters: `collection`, `outputDirectory`
- Use descriptive names: `configPath` not `path`

**Classes & Types:**
- PascalCase for class names: `CollectionModel`, `UsersModel`
- Enums use PascalCase with `Enum` suffix: `GenderEnum`, `OverallStateEnum`
- Model classes end with `Model` suffix: `UsersModel`, `MatchesModel`

**Constants:**
- UPPER_CASE for static const String fields: `static const String Id = 'id';`
- Use `// ignore_for_file: constant_identifier_names` for generated code

**Functions:**
- camelCase for function names: `capName()`, `removeSnake()`
- Private functions prefix with underscore: `_privateFunction()`

### Imports

```dart
// Dart SDK imports first
import 'dart:io';
import 'dart:convert';

// Package imports second (alphabetically)
import 'package:args/args.dart';
import 'package:path/path.dart' as pp;
import 'package:pocketbase/pocketbase.dart';
import 'package:yaml/yaml.dart';

// Relative imports last
import 'src/models.dart';
```

**Import Aliases:**
- Use when needed to avoid conflicts: `import 'package:path/path.dart' as pp;`

### Types & Null Safety

**Explicit Typing:**
```dart
// Always specify types explicitly
final String domain;
final List<CollectionField> fields;
final Map<String, dynamic> data;

// Avoid var when type isn't obvious
String collectionName = 'users';  // Good
var collectionName = 'users';      // Avoid
```

**Nullable Types:**
```dart
// Use ? for optional/nullable fields
final String? name;
final DateTime? deletedAt;
final List<String>? mimeTypes;

// Non-nullable for required fields
final String phoneNumber;
final DateTime createdAt;
```

**Factory Constructors:**
```dart
factory UsersModel.fromModel(RecordModel r) {
  return UsersModel(
    id: r.id,
    created: DateTime.parse(r.get<String>('created')),
    name: r.data['name'],
  );
}
```

### Error Handling

**Throw Exceptions:**
```dart
// Throw descriptive exceptions
if (pbConfig == null) {
  throw Exception('Missing "pocketbase" section in configuration.');
}

// Use ArgumentError for invalid arguments
throw ArgumentError("Invalid value: $value");
```

**Try-Catch:**
```dart
try {
  config = loadConfiguration(configPath);
} catch (e) {
  print('Error loading configuration: $e');
  printHelp(parser);
  exit(1);
}
```

### Code Organization

**File Headers (for generated code):**
```dart
// This file is auto-generated. Do not modify manually.
// Model for collection users
// ignore_for_file: constant_identifier_names
```

**Class Structure:**
```dart
class ExampleModel {
  // 1. Static constants
  static const String Id = 'id';
  
  // 2. Instance fields
  final String? id;
  final String name;
  
  // 3. Constructor
  const ExampleModel({
    this.id,
    required this.name,
  });
  
  // 4. Factory constructor
  factory ExampleModel.fromModel(RecordModel r) { ... }
  
  // 5. Instance methods
  Map<String, dynamic> toMap() { ... }
  
  // 6. copyWith method
  ExampleModel copyWith({ ... }) { ... }
}
```

### Documentation

**Library-Level Documentation:**
```dart
/// Support for doing something awesome.
///
/// More dartdocs go here.
library;
```

**Function Documentation:**
```dart
/// Authenticates an admin user with PocketBase.
/// Note: pb.admins is deprecated; prefer pb.collection('_superusers')
Future<void> authenticate(PocketBase pb, String email, String password) async {
  // ignore: deprecated_member_use
  await pb.admins.authWithPassword(email, password);
}

/// Capitalizes the first letter of a string.
String capName(String str) {
  if (str == 'date_time' || str == 'datetime' || str == 'dateTime') {
    return 'DateTimez';
  }
  return str[0].toUpperCase() + str.substring(1);
}
```

### Special Patterns

**Enum with Value:**
```dart
enum GenderEnum {
  male("male"),
  female("female"),
  ;

  final String value;
  const GenderEnum(this.value);

  static GenderEnum fromValue(String value) {
    return GenderEnum.values.firstWhere(
      (enumValue) => enumValue.value == value,
      orElse: () => throw ArgumentError("Invalid value: $value"),
    );
  }
}
```

**DateTime Handling:**
```dart
// Parsing from JSON
DateTime.parse(r.data['date_field'])

// Serializing to JSON
dateTime?.toIso8601String()

// Null-safe handling
r.data['deleted_at'] != null ? DateTime.parse(r.data['deleted_at']) : null
```

**String Buffer for Code Generation:**
```dart
final buffer = StringBuffer();
buffer.writeln('// Comment');
buffer.writeln('class Example {');
buffer.writeln('  final String name;');
buffer.writeln('}');
return buffer.toString();
```

## Project Structure

```
pocketbase_plus/
├── bin/
│   └── main.dart           # CLI entry point
├── lib/
│   ├── pocketbase_plus.dart # Library exports
│   └── src/
│       └── models.dart      # Internal implementation
├── test/
│   └── pocketbase_plus_test.dart
├── example/
│   └── lib/
│       └── models/          # Generated model examples
├── dart-sdk/                # SDK documentation
├── analysis_options.yaml    # Linter configuration
├── pubspec.yaml            # Package configuration
└── README.md
```

## Linting Rules

This project uses `package:lints/recommended.yaml` which includes:

- `avoid_dynamic_calls` - Avoid dynamic method calls
- `avoid_returning_null_for_void` - Don't return null for void
- `avoid_type_to_string` - Avoid .toString() on types
- `camel_case_types` - Use camelCase for types
- `constant_identifier_names` - Use UPPER_CASE for constants
- `curly_braces` - Always use curly braces
- `empty_catches` - Don't use empty catch blocks
- `file_names` - Use snake_case for file names
- `no_duplicate_case_values` - No duplicate case values
- `non_constant_identifier_names` - Use camelCase for identifiers
- `prefer_const_constructors` - Use const constructors
- `prefer_final_fields` - Make fields final
- `prefer_single_quotes` - Use single quotes for strings
- `sort_child_properties_last` - Sort child properties last
- `unnecessary_null_comparison` - Avoid unnecessary null checks
- `use_key_in_widget_constructors` - Use key in widget constructors

## Before Committing

1. Run `dart analyze` and ensure no errors
2. Run `dart format .` to format code
3. Run `dart test` to ensure all tests pass
4. Check for any new dependencies with `dart pub outdated`
5. Ensure generated code in `example/lib/models/` is up to date