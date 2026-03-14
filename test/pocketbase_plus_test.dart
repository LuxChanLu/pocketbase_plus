import 'package:test/test.dart';
import 'package:pocketbase_plus/pocketbase_plus.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('String Helpers', () {
    group('capName', () {
      test('capitalizes first letter of simple string', () {
        expect(capName('hello'), equals('Hello'));
      });

      test('capitalizes first letter of already capitalized string', () {
        expect(capName('Hello'), equals('Hello'));
      });

      test('handles single character', () {
        expect(capName('h'), equals('H'));
      });

      test('handles empty string', () {
        expect(capName(''), equals(''));
      });

      test('converts datetime variations to DateTimez', () {
        expect(capName('date_time'), equals('DateTimez'));
        expect(capName('datetime'), equals('DateTimez'));
        expect(capName('dateTime'), equals('DateTimez'));
      });

      test('handles lowercase string', () {
        expect(capName('user'), equals('User'));
      });
    });

    group('removeSnake', () {
      test('converts snake_case to camelCase', () {
        expect(removeSnake('user_name'), equals('userName'));
        expect(removeSnake('first_name'), equals('firstName'));
      });

      test('handles string without underscores', () {
        expect(removeSnake('user'), equals('user'));
      });

      test('handles multiple underscores', () {
        expect(removeSnake('user_first_name'), equals('userFirstName'));
      });

      test('handles trailing underscore', () {
        expect(removeSnake('user_'), equals('user'));
      });

      test('handles leading underscore', () {
        expect(removeSnake('_user'), equals('user'));
      });

      test('handles single underscore', () {
        expect(removeSnake('_'), equals(''));
      });

      test('preserves already capitalized parts', () {
        expect(removeSnake('user_Name'), equals('userName'));
      });
    });
  });

  group('Config', () {
    group('copyWith', () {
      test('copies all values when all parameters provided', () {
        final original = Config(
          domain: 'https://example.com',
          email: 'test@example.com',
          password: 'password123',
          outputDirectory: './lib/models',
        );

        final copy = original.copyWith(
          domain: 'https://new.com',
          email: 'new@example.com',
          password: 'newpassword',
          outputDirectory: './lib/new',
        );

        expect(copy.domain, equals('https://new.com'));
        expect(copy.email, equals('new@example.com'));
        expect(copy.password, equals('newpassword'));
        expect(copy.outputDirectory, equals('./lib/new'));
      });

      test('preserves original values when parameters are null', () {
        final original = Config(
          domain: 'https://example.com',
          email: 'test@example.com',
          password: 'password123',
          outputDirectory: './lib/models',
        );

        final copy = original.copyWith();

        expect(copy.domain, equals(original.domain));
        expect(copy.email, equals(original.email));
        expect(copy.password, equals(original.password));
        expect(copy.outputDirectory, equals(original.outputDirectory));
      });

      test('allows partial updates', () {
        final original = Config(
          domain: 'https://example.com',
          email: 'test@example.com',
          password: 'password123',
          outputDirectory: './lib/models',
        );

        final copy = original.copyWith(outputDirectory: './lib/generated');

        expect(copy.domain, equals(original.domain));
        expect(copy.email, equals(original.email));
        expect(copy.password, equals(original.password));
        expect(copy.outputDirectory, equals('./lib/generated'));
      });
    });
  });

  group('CollectionField', () {
    test('accesses nested properties via get() method with dot notation', () {
      final field = CollectionField({
        'id': 'field1',
        'name': 'user',
        'type': 'relation',
        'options': {
          'maxSelect': 1,
          'collectionId': 'users_collection',
        },
      });

      expect(field.type, equals('relation'));
      expect(field.get<int>('options.maxSelect', 0), equals(1));
      expect(field.get<String>('options.collectionId', ''),
          equals('users_collection'));
    });

    test('returns default value when nested property is missing', () {
      final field = CollectionField({
        'id': 'field1',
        'name': 'user',
        'type': 'text',
      });

      expect(field.get<int>('options.maxSelect', 99), equals(99));
    });
  });
}
