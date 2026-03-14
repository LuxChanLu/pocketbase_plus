import 'dart:io';
import 'package:path/path.dart' as pp;
import 'package:pocketbase/pocketbase.dart';
import 'package:yaml/yaml.dart';
import 'package:args/args.dart';
import 'package:pocketbase_plus/pocketbase_plus.dart';

/// Entry point of the application
/// Authenticates with PocketBase and generates Dart models for collections.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      defaultsTo: './pocketbase.yaml',
      help: 'Configuration file path.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated models (overrides config file).',
    )
    ..addFlag(
      'extensions',
      abbr: 'e',
      defaultsTo: true,
      help: 'Generate extension files with CRUD methods.',
    )
    ..addFlag(
      'barrel',
      abbr: 'b',
      defaultsTo: true,
      help: 'Generate barrel file (models.dart) that exports all models.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help information.',
    );

  final argResults = parser.parse(arguments);

  if (argResults['help'] as bool) {
    printHelp(parser);
    exit(0);
  }

  final configPath = argResults['config'] as String;
  final outputOverride = argResults['output'] as String?;
  final generateExtensions = argResults['extensions'] as bool;
  final generateBarrel = argResults['barrel'] as bool;

  print('Loading configuration from $configPath');

  Config config;
  try {
    config = loadConfiguration(configPath);
  } catch (e) {
    print('Error loading configuration: $e');
    printHelp(parser);
    exit(1);
  }

  // Apply CLI overrides
  if (outputOverride != null) {
    config = config.copyWith(outputDirectory: outputOverride);
  }

  print('Authenticating with PocketBase');

  final pb = PocketBase(config.domain);

  try {
    await authenticate(
      pb,
      config.email,
      config.password,
    );
  } catch (e) {
    print('Authentication failed: $e');
    print('Please check your email and password in the configuration file.');
    exit(1);
  }

  print('Fetching collections from PocketBase');

  final collections = await pb.collections.getFullList();

  print('Creating models directory at ${config.outputDirectory}');

  createModelsDirectory(config.outputDirectory);

  print('Generating models');

  generateModels(collections, config.outputDirectory);

  if (generateExtensions) {
    print('Generating extensions');
    generateExtensionsForAll(collections, config.outputDirectory);
  }

  if (generateBarrel) {
    print('Generating barrel file');
    generateBarrelFile(collections, config.outputDirectory);
  }

  print('Formatting generated code');

  formatGeneratedModels(config.outputDirectory);

  print('Done');
}

/// Loads the PocketBase configuration from a YAML file.
Config loadConfiguration(String path) {
  final file = File(pp.normalize(path));
  if (!file.existsSync()) {
    throw Exception('Configuration file not found at $path');
  }
  final yamlString = file.readAsStringSync();
  final yaml = loadYaml(yamlString);
  return Config.fromYaml(yaml);
}

/// Prints help information.
void printHelp(ArgParser parser) {
  print('Pocketbase Plus Model Generator\n');
  print('Generates Dart models from your PocketBase collections.\n');
  print('Usage:');
  print('  dart run pocketbase_plus:main [options]\n');
  print('Options:');
  print(parser.usage);
  print('''
Configuration file (pocketbase.yaml or pubspec.yaml):

pocketbase:
  hosting:
    domain: 'https://your-pocketbase-domain.com'
    email: 'your-email@example.com'
    password: 'your-password'
  output_directory: './lib/models'  # Optional, default is './lib/models'

Features:
  - Generates typed model classes with fromModel/toMap/copyWith
  - Generates enums for select fields
  - Generates extension files with CRUD helper methods (--extensions)
  - Generates barrel file for easy imports (--barrel)
''');
}

/// Authenticates an admin user with PocketBase.
Future<void> authenticate(PocketBase pb, String email, String password) async {
  // ignore: deprecated_member_use
  await pb.admins.authWithPassword(email, password);
}

/// Ensures that the models directory exists; creates it if not.
void createModelsDirectory(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
}

/// Generates Dart models for all collections.
void generateModels(List<CollectionModel> collections, String outputDirectory) {
  final collectionRegistry = _buildCollectionRegistry(collections);
  for (var collection in collections) {
    final modelContent =
        generateModelForCollection(collection, collectionRegistry);
    final filePath = pp.join(outputDirectory, '${collection.name}.dart');
    File(filePath).writeAsStringSync(modelContent);
  }
}

/// Builds a registry mapping collection IDs to collection names.
Map<String, String> _buildCollectionRegistry(
    List<CollectionModel> collections) {
  final registry = <String, String>{};
  for (var collection in collections) {
    registry[collection.id] = collection.name;
  }
  return registry;
}

/// Formats the generated model files using Dart's formatter.
void formatGeneratedModels(String modelsPath) {
  Process.runSync('dart', ['format', modelsPath]);
}

/// Generates the Dart model code for a single collection.
String generateModelForCollection(
    CollectionModel collection, Map<String, String> collectionRegistry) {
  final buffer = StringBuffer();

  // Find relation fields and their target collections
  final relationImports = <String>{};
  final relationFields = <MapEntry<CollectionField, String>>[];
  for (var field in collection.fields) {
    if (field.type == 'relation') {
      final collectionId = field.get<String>('options.collectionId', '');
      final targetCollectionName = collectionRegistry[collectionId];
      if (targetCollectionName != null) {
        relationImports.add(targetCollectionName);
        relationFields.add(MapEntry(field, targetCollectionName));
      } else if (collectionId.isNotEmpty) {
        print(
            'Warning: Relation field "${field.name}" in collection "${collection.name}" '
            'references unknown collection ID "$collectionId". Expand field not generated.');
      }
    }
  }

  // Add file documentation and imports
  buffer.writeln('// This file is auto-generated. Do not modify manually.');
  buffer.writeln('// Model for collection ${collection.name}');
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln();
  buffer.writeln("import 'package:pocketbase/pocketbase.dart';");

  // Add imports for relation target collections
  for (var importedCollection in relationImports) {
    final importName = importedCollection == collection.name
        ? '' // Skip self-import
        : "import '$importedCollection.dart';";
    if (importName.isNotEmpty) {
      buffer.writeln(importName);
    }
  }
  buffer.writeln();

  // Add enums for 'select' fields
  for (var field in collection.fields) {
    if (field.type == 'select') {
      generateEnumForField(buffer, field);
    }
  }

  // Add class declaration
  buffer.writeln("class ${removeSnake(capName(collection.name))}Model {");
  generateClassFields(buffer, collection.fields, relationFields);
  generateConstructor(
      collection.name, buffer, collection.fields, relationFields);
  generateFactoryConstructor(buffer, collection, relationFields);
  generateToMapMethod(buffer, collection.fields);
  generateStaticMethods(buffer, collection);
  generateFilterMethod(buffer, collection);
  buffer.writeln("}"); // Close class

  generateFilterClass(buffer, collection);

  return buffer.toString();
}

/// Generates an enum for a 'select' field in the collection schema.
void generateEnumForField(StringBuffer buffer, CollectionField field) {
  // Start the enum definition with constructor
  buffer.writeln('enum ${capName(removeSnake(field.name))}Enum {');
  for (var option in field.get<List<dynamic>>('options.values', [])) {
    buffer.writeln('${removeSnake(option)}("$option"),');
  }
  buffer.writeln(';\n');

  // Add a final String field and the constructor
  buffer.writeln('final String value;\n');
  buffer
      .writeln('const ${capName(removeSnake(field.name))}Enum(this.value);\n');

  // Add fromValue static method
  buffer.writeln(
      'static ${capName(removeSnake(field.name))}Enum fromValue(String value) {');
  buffer.writeln(
      '  return ${capName(removeSnake(field.name))}Enum.values.firstWhere(');
  buffer.writeln('    (enumValue) => enumValue.value == value,');
  buffer.writeln(
      '    orElse: () => throw ArgumentError("Invalid value: \$value"),');
  buffer.writeln('  );');
  buffer.writeln('}\n');

  buffer.writeln('}');
  buffer.writeln();
}

/// Generates the fields and their corresponding constants for the class.
void generateClassFields(
  StringBuffer buffer,
  List<CollectionField> fields,
  List<MapEntry<CollectionField, String>> relationFields,
) {
  buffer.writeln('');
  buffer.writeln('  // Fields');
  buffer.writeln('  final String? id;');
  buffer.writeln("  static const String Id = 'id';");

  buffer.writeln('');
  buffer.writeln('  final DateTime? created;');
  buffer.writeln("  static const String Created = 'created';");

  buffer.writeln('');
  buffer.writeln('  final DateTime? updated;');
  buffer.writeln("  static const String Updated = 'updated';");

  for (var field in fields) {
    buffer.writeln('');
    buffer.writeln('  final ${getType(field)} ${removeSnake(field.name)};');
    buffer.writeln(
        "  static const String ${removeSnake(capName(field.name))} = '${field.name}';");
  }

  // Generate expand fields for relations
  for (var entry in relationFields) {
    final field = entry.key;
    final targetCollection = entry.value;
    final fieldName = removeSnake(field.name);
    final targetClassName = '${removeSnake(capName(targetCollection))}Model';
    final maxSelect = field.get<int>('options.maxSelect', 0);

    buffer.writeln('');
    if (maxSelect == 1) {
      buffer.writeln('  $targetClassName? ${fieldName}Expanded;');
    } else {
      buffer.writeln('  List<$targetClassName>? ${fieldName}Expanded;');
    }
  }
}

/// Generates the constructor for the class.
void generateConstructor(
  String colName,
  StringBuffer buffer,
  List<CollectionField> fields,
  List<MapEntry<CollectionField, String>> relationFields,
) {
  buffer.writeln('');
  buffer.writeln('  const ${removeSnake(capName(colName))}Model({');
  buffer.writeln('    this.id,');
  buffer.writeln('    this.created,');
  buffer.writeln('    this.updated,');

  for (var field in fields) {
    buffer.writeln(
        "    ${field.required ? 'required' : ''} this.${removeSnake(field.name)},");
  }

  // Add expand fields to constructor (always optional)
  for (var entry in relationFields) {
    buffer.writeln('    this.${removeSnake(entry.key.name)}Expanded,');
  }

  buffer.writeln('  });');

  buffer.writeln('');
  buffer.writeln('  ${removeSnake(capName(colName))}Model copyWith({');
  buffer.writeln('    String? id,');
  buffer.writeln('    DateTime? created,');
  buffer.writeln('    DateTime? updated,');

  for (var field in fields) {
    var type = getType(field);
    if (field.required && type != 'dynamic') {
      buffer.writeln('    ${getType(field)}? ${removeSnake(field.name)},');
    } else {
      buffer.writeln('    ${getType(field)} ${removeSnake(field.name)},');
    }
  }

  // Add expand fields to copyWith
  for (var entry in relationFields) {
    final field = entry.key;
    final targetCollection = entry.value;
    final targetClassName = '${removeSnake(capName(targetCollection))}Model';
    final maxSelect = field.get<int>('options.maxSelect', 0);
    final fieldName = removeSnake(field.name);
    final expandFieldName = '${fieldName}Expanded';

    if (maxSelect == 1) {
      buffer.writeln('    $targetClassName? $expandFieldName,');
    } else {
      buffer.writeln('    List<$targetClassName>? $expandFieldName,');
    }
  }

  buffer.writeln('  }) {');
  buffer.writeln('    return ${removeSnake(capName(colName))}Model(');
  buffer.writeln('      id: id ?? this.id,');
  buffer.writeln('      created: created ?? this.created,');
  buffer.writeln('      updated: updated ?? this.updated,');

  for (var field in fields) {
    buffer.writeln(
        "      ${removeSnake(field.name)}: ${removeSnake(field.name)} ?? this.${removeSnake(field.name)},");
  }

  // Add expand fields to copyWith return
  for (var entry in relationFields) {
    final fieldName = removeSnake(entry.key.name);
    final expandFieldName = '${fieldName}Expanded';
    buffer.writeln(
        "      $expandFieldName: $expandFieldName ?? this.$expandFieldName,");
  }

  buffer.writeln('    );');
  buffer.writeln('  }');
}

/// Generates the factory constructor for creating an instance from a PocketBase model.
void generateFactoryConstructor(
  StringBuffer buffer,
  CollectionModel collection,
  List<MapEntry<CollectionField, String>> relationFields,
) {
  buffer.writeln('');
  buffer.writeln(
      '  factory ${removeSnake(capName(collection.name))}Model.fromModel(RecordModel r) {');
  buffer.writeln('    return ${removeSnake(capName(collection.name))}Model(');
  buffer.writeln('      id: r.id,');
  buffer.writeln("      created: DateTime.parse(r.get<String>('created')),");
  buffer.writeln("      updated: DateTime.parse(r.get<String>('updated')),");

  for (var field in collection.fields) {
    final fieldName = removeSnake(field.name);
    if (field.type == 'select') {
      buffer.writeln(
          "      $fieldName: ${capName(fieldName)}Enum.fromValue(r.data['${field.name}']! as String),");
    } else if (field.type == 'date' || field.type == 'datetime') {
      if (field.required) {
        buffer.writeln(
            "      $fieldName: DateTime.parse(r.data['${field.name}']! as String),");
      } else {
        buffer.writeln(
            "      $fieldName: r.data['${field.name}'] != null && r.data['${field.name}'] != '' ? DateTime.parse(r.data['${field.name}']) : null,");
      }
    } else if (field.type == 'json') {
      if (field.required) {
        buffer.writeln(
            "      $fieldName: Map<String, dynamic>.from(r.data['${field.name}'] ?? {}),");
      } else {
        buffer.writeln(
            "      $fieldName: r.data['${field.name}'] != null ? Map<String, dynamic>.from(r.data['${field.name}']) : null,");
      }
    } else if (field.type == 'relation') {
      final maxSelect = field.get<int>('options.maxSelect', 0);
      if (maxSelect == 1) {
        buffer.writeln("      $fieldName: r.data['${field.name}'] as String?,");
      } else {
        buffer.writeln(
            "      $fieldName: (r.data['${field.name}'] as List<dynamic>?)?.cast<String>(),");
      }
    } else if (field.type == 'file') {
      final maxSelect = field.get<int>('options.maxSelect', 0);
      if (maxSelect == 1) {
        buffer.writeln("      $fieldName: r.data['${field.name}'] as String?,");
      } else {
        buffer.writeln(
            "      $fieldName: (r.data['${field.name}'] as List<dynamic>?)?.cast<String>(),");
      }
    } else {
      buffer.writeln("      $fieldName: r.data['${field.name}'],");
    }
  }

  // Generate expand field parsing for relations
  for (var entry in relationFields) {
    final field = entry.key;
    final targetCollection = entry.value;
    final targetClassName = '${removeSnake(capName(targetCollection))}Model';
    final fieldName = removeSnake(field.name);
    final expandFieldName = '${fieldName}Expanded';
    final maxSelect = field.get<int>('options.maxSelect', 0);

    buffer.writeln('');
    if (maxSelect == 1) {
      buffer.writeln('      $expandFieldName: () {');
      buffer.writeln('        final expanded = r.get<RecordModel?>('
          "'expand.${field.name}', null);");
      buffer.writeln('        return expanded != null');
      buffer.writeln('          ? $targetClassName.fromModel(expanded)');
      buffer.writeln('          : null;');
      buffer.writeln('      }(),');
    } else {
      buffer.writeln('      $expandFieldName: '
          "r.get<List<RecordModel>>('expand.${field.name}', [])");
      buffer.writeln('        .map((e) => $targetClassName.fromModel(e))');
      buffer.writeln('        .toList(),');
    }
  }

  buffer.writeln('    );');
  buffer.writeln('  }');
}

/// Generates the `toMap` method for the class, converting it to a Map.
void generateToMapMethod(StringBuffer buffer, List<CollectionField> fields) {
  buffer.writeln('');
  buffer.writeln('  Map<String, dynamic> toMap() {');
  buffer.writeln('    return {');

  for (var field in fields) {
    final fieldName = removeSnake(field.name);
    if (field.type == 'select') {
      buffer.writeln("      '${field.name}': $fieldName.value,");
    } else if (field.type == 'date' || field.type == 'datetime') {
      if (field.required) {
        buffer.writeln("      '${field.name}': $fieldName.toIso8601String(),");
      } else {
        buffer.writeln("      '${field.name}': $fieldName?.toIso8601String(),");
      }
    } else {
      buffer.writeln("      '${field.name}': $fieldName,");
    }
  }

  buffer.writeln('    };');
  buffer.writeln('  }');
}

/// Capitalizes the first letter of a string.
String capName(String str) {
  if (str == 'date_time' || str == 'datetime' || str == 'dateTime') {
    return 'DateTimez';
  }
  return str[0].toUpperCase() + str.substring(1);
}

/// Converts a snake_case string to camelCase.
String removeSnake(String str) {
  final parts = str.split('_');
  return parts.fold(
      '',
      (previous, element) =>
          previous.isEmpty ? element : previous + capName(element));
}

/// Maps the schema field type to a Dart type.
String getType(CollectionField field) {
  switch (field.type) {
    case 'text':
      return field.required ? 'String' : 'String?';
    case 'email':
      return field.required ? 'String' : 'String?';
    case 'url':
      return field.required ? 'String' : 'String?';
    case 'editor':
      return field.required ? 'String' : 'String?';
    case 'number':
      return field.required ? 'num' : 'num?';
    case 'bool':
      return field.required ? 'bool' : 'bool?';
    case 'date':
      return field.required ? 'DateTime' : 'DateTime?';
    case 'datetime':
      return field.required ? 'DateTime' : 'DateTime?';
    case 'select':
      return field.required
          ? '${capName(removeSnake(field.name))}Enum'
          : '${capName(removeSnake(field.name))}Enum?';
    case 'json':
      return field.required ? 'Map<String, dynamic>' : 'Map<String, dynamic>?';
    case 'file':
      final maxSelect = field.get<int>('options.maxSelect', 0);
      if (maxSelect == 1) {
        return field.required ? 'String' : 'String?';
      }
      return field.required ? 'List<String>' : 'List<String>?';
    case 'relation':
      final maxSelect = field.get<int>('options.maxSelect', 0);
      if (maxSelect == 1) {
        return field.required ? 'String' : 'String?';
      }
      return field.required ? 'List<String>' : 'List<String>?';
    default:
      return 'dynamic';
  }
}

/// Generates extension files with CRUD methods for all collections.
void generateExtensionsForAll(
    List<CollectionModel> collections, String outputDirectory) {
  for (var collection in collections) {
    final extensionContent = generateExtensionForCollection(collection);
    final filePath =
        pp.join(outputDirectory, '${collection.name}_extension.dart');
    File(filePath).writeAsStringSync(extensionContent);
  }
}

/// Generates the extension code for a single collection.
String generateExtensionForCollection(CollectionModel collection) {
  final buffer = StringBuffer();
  final className = '${removeSnake(capName(collection.name))}Model';
  final collectionName = collection.name;

  buffer.writeln('// This file is auto-generated. Do not modify manually.');
  buffer.writeln('// Extension for collection $collectionName');
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln();
  buffer.writeln("import 'package:pocketbase/pocketbase.dart';");
  buffer.writeln("import '$collectionName.dart';");
  buffer.writeln();

  // Extension for instance methods
  buffer.writeln('extension ${className}Extension on $className {');
  buffer.writeln('  /// Creates a new record or updates an existing one.');
  buffer.writeln(
      '  /// If [id] is null, creates a new record; otherwise updates.');
  buffer.writeln(
      '  Future<$className> save(PocketBase pb, {String? expand}) async {');
  buffer.writeln('    if (id == null) {');
  buffer.writeln(
      "      final record = await pb.collection('$collectionName').create(");
  buffer.writeln('        body: toMap(),');
  buffer.writeln('        expand: expand,');
  buffer.writeln('      );');
  buffer.writeln('      return $className.fromModel(record);');
  buffer.writeln('    }');
  buffer.writeln(
      "    final record = await pb.collection('$collectionName').update(");
  buffer.writeln('      id!,');
  buffer.writeln('      body: toMap(),');
  buffer.writeln('      expand: expand,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Deletes this record from the collection.');
  buffer.writeln('  /// Returns true if deletion was successful.');
  buffer.writeln('  Future<bool> delete(PocketBase pb) async {');
  buffer.writeln('    if (id == null) return false;');
  buffer.writeln("    await pb.collection('$collectionName').delete(id!);");
  buffer.writeln('    return true;');
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();

  // Extension for PocketBase static methods
  buffer.writeln('extension ${className}Service on PocketBase {');
  buffer.writeln('  /// Fetches a single $className by ID.');
  buffer.writeln(
      '  Future<$className> get${removeSnake(capName(collection.name))}(');
  buffer.writeln('    String id, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final record = await collection('$collectionName').getOne(");
  buffer.writeln('      id,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Fetches a paginated list of ${className}s.');
  buffer.writeln(
      '  Future<List<$className>> get${removeSnake(capName(collection.name))}List({');
  buffer.writeln('    int page = 1,');
  buffer.writeln('    int perPage = 30,');
  buffer.writeln('    String? filter,');
  buffer.writeln('    String? sort,');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final result = await collection('$collectionName').getList(");
  buffer.writeln('      page: page,');
  buffer.writeln('      perPage: perPage,');
  buffer.writeln('      filter: filter,');
  buffer.writeln('      sort: sort,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return result.items.map($className.fromModel).toList();');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Fetches all ${className}s with automatic pagination.');
  buffer.writeln(
      '  Future<List<$className>> get${removeSnake(capName(collection.name))}FullList({');
  buffer.writeln('    String? filter,');
  buffer.writeln('    String? sort,');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('    int batch = 1000,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final records = await collection('$collectionName').getFullList(");
  buffer.writeln('      batch: batch,');
  buffer.writeln('      filter: filter,');
  buffer.writeln('      sort: sort,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return records.map($className.fromModel).toList();');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Fetches the first $className matching the filter.');
  buffer.writeln(
      '  Future<$className> getFirst${removeSnake(capName(collection.name))}(');
  buffer.writeln('    String filter, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final record = await collection('$collectionName').getFirstListItem(");
  buffer.writeln('      filter,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Creates a new $className record.');
  buffer.writeln(
      '  Future<$className> create${removeSnake(capName(collection.name))}(');
  buffer.writeln('    Map<String, dynamic> data, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final record = await collection('$collectionName').create(");
  buffer.writeln('      body: data,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Updates an existing $className record.');
  buffer.writeln(
      '  Future<$className> update${removeSnake(capName(collection.name))}(');
  buffer.writeln('    String id,');
  buffer.writeln('    Map<String, dynamic> data, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final record = await collection('$collectionName').update(");
  buffer.writeln('      id,');
  buffer.writeln('      body: data,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Deletes a $className record by ID.');
  buffer.writeln(
      '  Future<void> delete${removeSnake(capName(collection.name))}(String id) async {');
  buffer.writeln("    await collection('$collectionName').delete(id);");
  buffer.writeln('  }');
  buffer.writeln('}');

  return buffer.toString();
}

/// Generates static CRUD methods for the model class.
void generateStaticMethods(StringBuffer buffer, CollectionModel collection) {
  final className = '${removeSnake(capName(collection.name))}Model';
  final collectionName = collection.name;

  buffer.writeln();
  buffer.writeln('  // Static CRUD methods');
  buffer.writeln();

  buffer.writeln('  /// Fetches a single $className by ID.');
  buffer.writeln('  /// Returns null if not found.');
  buffer.writeln(
      '  static Future<$className?> getOne(PocketBase pb, String id, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln('    try {');
  buffer.writeln(
      "      final record = await pb.collection('$collectionName').getOne(");
  buffer.writeln('        id,');
  buffer.writeln('        expand: expand,');
  buffer.writeln('        fields: fields,');
  buffer.writeln('      );');
  buffer.writeln('      return $className.fromModel(record);');
  buffer.writeln('    } catch (_) {');
  buffer.writeln('      return null;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln();

  buffer.writeln('  /// Fetches a paginated list of $className records.');
  buffer.writeln('  static Future<List<$className>> getList(PocketBase pb, {');
  buffer.writeln('    int page = 1,');
  buffer.writeln('    int perPage = 30,');
  buffer.writeln('    String? filter,');
  buffer.writeln('    String? sort,');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final result = await pb.collection('$collectionName').getList(");
  buffer.writeln('      page: page,');
  buffer.writeln('      perPage: perPage,');
  buffer.writeln('      filter: filter,');
  buffer.writeln('      sort: sort,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return result.items.map($className.fromModel).toList();');
  buffer.writeln('  }');
  buffer.writeln();

  buffer.writeln(
      '  /// Fetches all $className records with automatic pagination.');
  buffer.writeln(
      '  static Future<List<$className>> getFullList(PocketBase pb, {');
  buffer.writeln('    String? filter,');
  buffer.writeln('    String? sort,');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('    int batch = 1000,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final records = await pb.collection('$collectionName').getFullList(");
  buffer.writeln('      batch: batch,');
  buffer.writeln('      filter: filter,');
  buffer.writeln('      sort: sort,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return records.map($className.fromModel).toList();');
  buffer.writeln('  }');
  buffer.writeln();

  buffer.writeln('  /// Fetches the first $className matching the filter.');
  buffer.writeln('  /// Returns null if not found.');
  buffer.writeln(
      '  static Future<$className?> getFirst(PocketBase pb, String filter, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln('    try {');
  buffer.writeln(
      "      final record = await pb.collection('$collectionName').getFirstListItem(");
  buffer.writeln('        filter,');
  buffer.writeln('        expand: expand,');
  buffer.writeln('        fields: fields,');
  buffer.writeln('      );');
  buffer.writeln('      return $className.fromModel(record);');
  buffer.writeln('    } catch (_) {');
  buffer.writeln('      return null;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln();

  buffer.writeln('  /// Creates a new $className record.');
  buffer.writeln(
      '  static Future<$className> create(PocketBase pb, Map<String, dynamic> data, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final record = await pb.collection('$collectionName').create(");
  buffer.writeln('      body: data,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();

  buffer.writeln('  /// Updates an existing $className record.');
  buffer.writeln(
      '  static Future<$className> update(PocketBase pb, String id, Map<String, dynamic> data, {');
  buffer.writeln('    String? expand,');
  buffer.writeln('    String? fields,');
  buffer.writeln('  }) async {');
  buffer.writeln(
      "    final record = await pb.collection('$collectionName').update(");
  buffer.writeln('      id,');
  buffer.writeln('      body: data,');
  buffer.writeln('      expand: expand,');
  buffer.writeln('      fields: fields,');
  buffer.writeln('    );');
  buffer.writeln('    return $className.fromModel(record);');
  buffer.writeln('  }');
  buffer.writeln();

  buffer.writeln('  /// Deletes a $className record by ID.');
  buffer.writeln(
      '  static Future<void> delete(PocketBase pb, String id) async {');
  buffer.writeln("    await pb.collection('$collectionName').delete(id);");
  buffer.writeln('  }');
}

/// Generates the static filter getter for the model class.
void generateFilterMethod(StringBuffer buffer, CollectionModel collection) {
  final filterClassName = '${removeSnake(capName(collection.name))}Filter';

  buffer.writeln();
  buffer.writeln('  /// Returns a filter builder for this collection.');
  buffer.writeln('  static $filterClassName get f => $filterClassName();');
}

/// Generates a type-safe filter class for the collection.
void generateFilterClass(StringBuffer buffer, CollectionModel collection) {
  final className = '${removeSnake(capName(collection.name))}Model';
  final filterClassName = '${removeSnake(capName(collection.name))}Filter';

  buffer.writeln();
  buffer.writeln('/// Type-safe filter builder for $className.');
  buffer.writeln('class $filterClassName {');
  buffer.writeln('  final List<String> _conditions = [];');
  buffer.writeln('  bool _negateNext = false;');
  buffer.writeln();
  buffer.writeln('  $filterClassName();');
  buffer.writeln();
  buffer.writeln('  void _add(String condition) {');
  buffer.writeln('    if (_negateNext) {');
  buffer.writeln("      _conditions.add('!(' + condition + ')');");
  buffer.writeln('      _negateNext = false;');
  buffer.writeln('    } else {');
  buffer.writeln('      _conditions.add(condition);');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Negates the next condition.');
  buffer.writeln('  $filterClassName get not {');
  buffer.writeln('    _negateNext = true;');
  buffer.writeln('    return this;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Combines conditions with AND.');
  buffer.writeln('  $filterClassName operator &($filterClassName other) {');
  buffer.writeln('    final result = $filterClassName();');
  buffer.writeln(
      "    result._conditions.addAll([..._conditions, '&&', ...other._conditions]);");
  buffer.writeln('    return result;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Combines conditions with OR.');
  buffer.writeln('  $filterClassName operator |($filterClassName other) {');
  buffer.writeln('    final result = $filterClassName();');
  buffer.writeln(
      "    result._conditions.addAll([..._conditions, '||', ...other._conditions]);");
  buffer.writeln('    return result;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// Builds the filter string.');
  buffer.writeln('  String build() => _conditions.join(' ');');
  buffer.writeln();

  // Generate filter field getters
  for (var field in collection.fields) {
    final fieldName = removeSnake(field.name);

    buffer.writeln('  /// Filter for field "${field.name}".');

    if (field.type == 'select') {
      final enumName = '${capName(fieldName)}Enum';
      buffer.writeln(
          '  _${className}EnumFilter get $fieldName => _${className}EnumFilter(\'${field.name}\', this, $enumName.values);');
    } else if (field.type == 'number') {
      buffer.writeln(
          '  _${className}NumFilter get $fieldName => _${className}NumFilter(\'${field.name}\', this);');
    } else if (field.type == 'date' || field.type == 'datetime') {
      buffer.writeln(
          '  _${className}DateFilter get $fieldName => _${className}DateFilter(\'${field.name}\', this);');
    } else if (field.type == 'relation') {
      final maxSelect = field.get<int>('options.maxSelect', 0);
      if (maxSelect == 1) {
        buffer.writeln(
            '  _${className}FieldFilter get $fieldName => _${className}FieldFilter(\'${field.name}\', this);');
      } else {
        buffer.writeln(
            '  _${className}ArrayFilter get $fieldName => _${className}ArrayFilter(\'${field.name}\', this);');
      }
    } else if (field.type == 'file') {
      final maxSelect = field.get<int>('options.maxSelect', 0);
      if (maxSelect == 1) {
        buffer.writeln(
            '  _${className}FieldFilter get $fieldName => _${className}FieldFilter(\'${field.name}\', this);');
      } else {
        buffer.writeln(
            '  _${className}ArrayFilter get $fieldName => _${className}ArrayFilter(\'${field.name}\', this);');
      }
    } else if (field.type == 'bool') {
      buffer.writeln(
          '  _${className}FieldFilter get $fieldName => _${className}FieldFilter(\'${field.name}\', this);');
    } else {
      buffer.writeln(
          '  _${className}FieldFilter get $fieldName => _${className}FieldFilter(\'${field.name}\', this);');
    }
    buffer.writeln();
  }

  // Also add id, created, updated fields
  buffer.writeln('  /// Filter for field "id".');
  buffer.writeln(
      '  _${className}FieldFilter get id => _${className}FieldFilter(\'id\', this);');
  buffer.writeln();
  buffer.writeln('  /// Filter for field "created".');
  buffer.writeln(
      '  _${className}DateFilter get created => _${className}DateFilter(\'created\', this);');
  buffer.writeln();
  buffer.writeln('  /// Filter for field "updated".');
  buffer.writeln(
      '  _${className}DateFilter get updated => _${className}DateFilter(\'updated\', this);');

  buffer.writeln('}');
  buffer.writeln();

  // Generate filter helper classes
  buffer.writeln('class _${className}FieldFilter {');
  buffer.writeln('  final String _fieldName;');
  buffer.writeln('  final $filterClassName _builder;');
  buffer.writeln('  _${className}FieldFilter(this._fieldName, this._builder);');
  buffer.writeln();
  buffer.writeln(
      "  $filterClassName eq(dynamic value) => _builder.._add('\$_fieldName = \"\${_escape(value)}\"');");
  buffer.writeln(
      "  $filterClassName neq(dynamic value) => _builder.._add('\$_fieldName != \"\${_escape(value)}\"');");
  buffer.writeln(
      "  $filterClassName gt(dynamic value) => _builder.._add('\$_fieldName > \"\${_escape(value)}\"');");
  buffer.writeln(
      "  $filterClassName gte(dynamic value) => _builder.._add('\$_fieldName >= \"\${_escape(value)}\"');");
  buffer.writeln(
      "  $filterClassName lt(dynamic value) => _builder.._add('\$_fieldName < \"\${_escape(value)}\"');");
  buffer.writeln(
      "  $filterClassName lte(dynamic value) => _builder.._add('\$_fieldName <= \"\${_escape(value)}\"');");
  buffer.writeln(
      "  $filterClassName like(String pattern) => _builder.._add('\$_fieldName ~ \"\$pattern\"');");
  buffer.writeln(
      "  $filterClassName notLike(String pattern) => _builder.._add('\$_fieldName !~ \"\$pattern\"');");
  buffer.writeln(
      "  $filterClassName isNull() => _builder.._add('\$_fieldName = null');");
  buffer.writeln(
      "  $filterClassName isNotNull() => _builder.._add('\$_fieldName != null');");
  buffer.writeln(
      "  $filterClassName contains(String value) => _builder.._add('\$_fieldName ~ \"\${_escape(value)}\"');");
  buffer.writeln();
  buffer.writeln('  static String _escape(dynamic value) {');
  buffer.writeln("    if (value == null) return 'null';");
  buffer.writeln(
      "    if (value is num || value is bool) return value.toString();");
  buffer
      .writeln("    final s = value.toString().replaceall(\"'\", \"\\\\'\");");
  buffer.writeln("    return s;");
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();

  buffer.writeln('class _${className}NumFilter {');
  buffer.writeln('  final String _fieldName;');
  buffer.writeln('  final $filterClassName _builder;');
  buffer.writeln('  _${className}NumFilter(this._fieldName, this._builder);');
  buffer.writeln();
  buffer.writeln(
      "  $filterClassName eq(num value) => _builder.._add('\$_fieldName = \$value');");
  buffer.writeln(
      "  $filterClassName neq(num value) => _builder.._add('\$_fieldName != \$value');");
  buffer.writeln(
      "  $filterClassName gt(num value) => _builder.._add('\$_fieldName > \$value');");
  buffer.writeln(
      "  $filterClassName gte(num value) => _builder.._add('\$_fieldName >= \$value');");
  buffer.writeln(
      "  $filterClassName lt(num value) => _builder.._add('\$_fieldName < \$value');");
  buffer.writeln(
      "  $filterClassName lte(num value) => _builder.._add('\$_fieldName <= \$value');");
  buffer.writeln(
      "  $filterClassName between(num min, num max) => _builder.._add('\$_fieldName >= \$min && \$_fieldName <= \$max');");
  buffer.writeln('}');
  buffer.writeln();

  buffer.writeln('class _${className}DateFilter {');
  buffer.writeln('  final String _fieldName;');
  buffer.writeln('  final $filterClassName _builder;');
  buffer.writeln('  _${className}DateFilter(this._fieldName, this._builder);');
  buffer.writeln();
  buffer.writeln(
      '  static String _format(DateTime dt) => dt.toUtc().toIso8601String().replaceAll("T", " ");');
  buffer.writeln();
  buffer.writeln(
      "  $filterClassName eq(DateTime value) => _builder.._add('\$_fieldName = \"\${_format(value)}\"');");
  buffer.writeln(
      "  $filterClassName neq(DateTime value) => _builder.._add('\$_fieldName != \"\${_format(value)}\"');");
  buffer.writeln(
      "  $filterClassName after(DateTime value) => _builder.._add('\$_fieldName > \"\${_format(value)}\"');");
  buffer.writeln(
      "  $filterClassName before(DateTime value) => _builder.._add('\$_fieldName < \"\${_format(value)}\"');");
  buffer.writeln(
      "  $filterClassName onOrAfter(DateTime value) => _builder.._add('\$_fieldName >= \"\${_format(value)}\"');");
  buffer.writeln(
      "  $filterClassName onOrBefore(DateTime value) => _builder.._add('\$_fieldName <= \"\${_format(value)}\"');");
  buffer.writeln(
      "  $filterClassName isNull() => _builder.._add('\$_fieldName = null');");
  buffer.writeln(
      "  $filterClassName isNotNull() => _builder.._add('\$_fieldName != null');");
  buffer.writeln('}');
  buffer.writeln();

  buffer.writeln('class _${className}EnumFilter<E extends Enum> {');
  buffer.writeln('  final String _fieldName;');
  buffer.writeln('  final $filterClassName _builder;');
  buffer.writeln('  final List<E> _values;');
  buffer.writeln(
      '  _${className}EnumFilter(this._fieldName, this._builder, this._values);');
  buffer.writeln();
  buffer.writeln('  String _escapeValue(E value) {');
  buffer.writeln('    final dynamic v = value;');
  buffer.writeln(
      "    final str = v.value != null ? v.value.toString() : value.name;");
  buffer.writeln("    final escaped = str.replaceAll(\"'\", \"\\\\'\");");
  buffer.writeln("    return \"'\$escaped'\";");
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln(
      "  $filterClassName eq(E value) => _builder.._add('\$_fieldName = '\${_escapeValue(value)}');");
  buffer.writeln(
      "  $filterClassName neq(E value) => _builder.._add('\$_fieldName != '\${_escapeValue(value)}');");
  buffer.writeln(
      "  $filterClassName isIn(List<E> values) => _builder.._add('\$_fieldName ?= ('\${values.map(_escapeValue).join(', ')})');");
  buffer.writeln('}');
  buffer.writeln();

  buffer.writeln('class _${className}ArrayFilter {');
  buffer.writeln('  final String _fieldName;');
  buffer.writeln('  final $filterClassName _builder;');
  buffer.writeln('  _${className}ArrayFilter(this._fieldName, this._builder);');
  buffer.writeln();
  buffer.writeln(
      "  $filterClassName contains(String value) => _builder.._add('\$_fieldName ?= \"\$value\"');");
  buffer.writeln("  $filterClassName containsAny(List<String> values) {");
  buffer.writeln(
      "    final escaped = values.map((v) => \"'\" + v.replaceAll(\"'\", r\"\\'\") + \"'\").join(', ');");
  buffer.writeln(
      "    return _builder.._add('\$_fieldName ?= (' + escaped + ')');");
  buffer.writeln('  }');
  buffer.writeln(
      "  $filterClassName hasLength(int length) => _builder.._add('\$_fieldName.length = \$length');");
  buffer.writeln('}');
}

/// Generates a barrel file that exports all models and extensions.
void generateBarrelFile(
    List<CollectionModel> collections, String outputDirectory) {
  final buffer = StringBuffer();

  buffer.writeln('// This file is auto-generated. Do not modify manually.');
  buffer
      .writeln('// Barrel file exporting all generated models and extensions.');
  buffer.writeln();
  buffer.writeln('library models;');
  buffer.writeln();

  // Sort collections alphabetically for consistent output
  final sortedCollections = List<CollectionModel>.from(collections)
    ..sort((a, b) => a.name.compareTo(b.name));

  for (var collection in sortedCollections) {
    buffer.writeln("export '${collection.name}.dart';");
    buffer.writeln("export '${collection.name}_extension.dart';");
  }

  final filePath = pp.join(outputDirectory, 'models.dart');
  File(filePath).writeAsStringSync(buffer.toString());
}
