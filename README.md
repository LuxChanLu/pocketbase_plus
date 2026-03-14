# Pocketbase Plus 🚀

Say goodbye to manual PocketBase model generation and let **Pocketbase Plus** do the heavy lifting! 😎

Automatically generates type-safe Dart models with CRUD helper methods from your PocketBase collections.

## Features

- ✅ **Type-safe model classes** with `fromModel`, `toMap`, and `copyWith`
- ✅ **Enum generation** for `select` fields
- ✅ **CRUD extensions** - `save()`, `delete()`, `getOne()`, `getList()`, `getFullList()`, `create()`
- ✅ **Barrel file export** - `models.dart` that exports all generated files
- ✅ **All field types** - text, email, url, editor, number, bool, date, datetime, select, json, file, relation

## Installation

Add as a dev dependency in your `pubspec.yaml`:

```yaml
dev_dependencies:
  pocketbase_plus:
    git: https://github.com/seifalmotaz/pocketbase_plus
```

Or with pub.dev:

```bash
dart pub add dev:pocketbase_plus
```

## Quick Start

### 1. Create Configuration

Create `pocketbase.yaml` in your project:

```yaml
pocketbase:
  hosting:
    domain: 'https://your-pocketbase-domain.com'
    email: 'your-email@example.com'
    password: 'your-password'
  output_directory: './lib/models'  # Optional, default is './lib/models'
```

Or embed in `pubspec.yaml`:

```yaml
pocketbase:
  hosting:
    domain: 'https://your-pocketbase-domain.com'
    email: 'your-email@example.com'
    password: 'your-password'
```

### 2. Generate Models

```bash
# Run with default config
dart run pocketbase_plus:main

# Run with custom config
dart run pocketbase_plus:main --config path/to/config.yaml

# Skip extension generation
dart run pocketbase_plus:main --no-extensions

# Skip barrel file
dart run pocketbase_plus:main --no-barrel

# Override output directory
dart run pocketbase_plus:main --output ./lib/generated
```

### 3. Use Generated Models

```dart
import 'package:pocketbase/pocketbase.dart';
import 'models/models.dart';  // Barrel file

Future<void> example() async {
  final pb = PocketBase('https://your-pocketbase-domain.com');
  
  // Fetch all users
  final users = await pb.getUsersFullList();
  
  // Fetch with filter
  final activeUsers = await pb.getUsersList(filter: 'active=true');
  
  // Get single user
  final user = await pb.getUser('USER_ID');
  
  // Create new user
  final newUser = await pb.createUser({
    'name': 'John Doe',
    'email': 'john@example.com',
  });
  
  // Update user
  final updated = await pb.updateUser('USER_ID', {'name': 'Jane Doe'});
  
  // Save model (creates if new, updates if existing)
  final model = UsersModel(name: 'Test', email: 'test@example.com');
  final saved = await model.save(pb);
  
  // Delete
  await pb.deleteUser('USER_ID');
}
```

## Supported Field Types

| PocketBase Type | Dart Type (Required) | Dart Type (Optional) |
|-----------------|---------------------|----------------------|
| text | `String` | `String?` |
| email | `String` | `String?` |
| url | `String` | `String?` |
| editor | `String` | `String?` |
| number | `num` | `num?` |
| bool | `bool` | `bool?` |
| date | `DateTime` | `DateTime?` |
| datetime | `DateTime` | `DateTime?` |
| select | `XxxEnum` | `XxxEnum?` |
| json | `Map<String, dynamic>` | `Map<String, dynamic>?` |
| file (single) | `String` | `String?` |
| file (multiple) | `List<String>` | `List<String>?` |
| relation (single) | `String` | `String?` |
| relation (multiple) | `List<String>` | `List<String>?` |

## Generated Files

```
lib/models/
├── users.dart              # Model class
├── users_extension.dart    # CRUD extension methods
├── posts.dart
├── posts_extension.dart
└── models.dart             # Barrel file (exports all)
```

## CLI Options

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--config` | `-c` | `./pocketbase.yaml` | Configuration file path |
| `--output` | `-o` | (from config) | Output directory |
| `--extensions` | `-e` | `true` | Generate CRUD extensions |
| `--barrel` | `-b` | `true` | Generate barrel file |
| `--help` | `-h` | - | Show help |

## Generated CRUD Methods

### Instance Methods (on model):

```dart
// Save (create or update)
final saved = await model.save(pb);

// Delete
final deleted = await model.delete(pb);
```

### Static Methods (on PocketBase):

```dart
// Get single record by ID
final user = await pb.getUser('USER_ID');

// Get paginated list
final users = await pb.getUsersList(page: 1, perPage: 30, filter: 'active=true');

// Get all records
final allUsers = await pb.getUsersFullList(filter: 'role="admin"');

// Get first matching filter
final user = await pb.getFirstUser('email="test@example.com"');

// Create
final newUser = await pb.createUser({'name': 'John'});

// Update
final updated = await pb.updateUser('USER_ID', {'name': 'Jane'});

// Delete
await pb.deleteUser('USER_ID');
```

## License

MIT License - see [LICENSE](LICENSE) for details.