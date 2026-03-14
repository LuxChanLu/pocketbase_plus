// String helper functions for model generation.

/// Field type constants for PocketBase schema types.
class FieldType {
  static const String text = 'text';
  static const String email = 'email';
  static const String url = 'url';
  static const String editor = 'editor';
  static const String number = 'number';
  static const String bool = 'bool';
  static const String date = 'date';
  static const String datetime = 'datetime';
  static const String select = 'select';
  static const String json = 'json';
  static const String file = 'file';
  static const String relation = 'relation';
}

/// Capitalizes the first letter of a string.
String capName(String str) {
  if (str == 'date_time' || str == 'datetime' || str == 'dateTime') {
    return 'DateTimez';
  }
  if (str.isEmpty) return str;
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
String getDartType(String fieldType, bool required, String fieldName) {
  switch (fieldType) {
    case 'text':
      return required ? 'String' : 'String?';
    case 'email':
      return required ? 'String' : 'String?';
    case 'url':
      return required ? 'String' : 'String?';
    case 'editor':
      return required ? 'String' : 'String?';
    case 'number':
      return required ? 'num' : 'num?';
    case 'bool':
      return required ? 'bool' : 'bool?';
    case 'date':
      return required ? 'DateTime' : 'DateTime?';
    case 'datetime':
      return required ? 'DateTime' : 'DateTime?';
    case 'select':
      final enumName = '${capName(removeSnake(fieldName))}Enum';
      return required ? enumName : '$enumName?';
    case 'json':
      return required ? 'Map<String, dynamic>' : 'Map<String, dynamic>?';
    default:
      return 'dynamic';
  }
}

/// Generates a Dart type string for a field considering maxSelect for relations/files.
String getDartTypeWithMaxSelect(
  String fieldType,
  bool required,
  int maxSelect,
) {
  if (fieldType == 'file' || fieldType == 'relation') {
    if (maxSelect == 1) {
      return required ? 'String' : 'String?';
    }
    return required ? 'List<String>' : 'List<String>?';
  }
  return getDartType(fieldType, required, '');
}
