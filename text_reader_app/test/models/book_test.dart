import 'package:flutter_test/flutter_test.dart';
import 'package:text_reader_app/models/book.dart';

void main() {
  group('Book Model Tests', () {
    late Book testBook;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 1, 12, 0);
      testBook = Book(
        id: 'test-id',
        title: 'Test Book',
        author: 'Test Author',
        content: 'This is test content',
        filePath: '/path/to/book.txt',
        importedAt: testDate,
        lastReadAt: testDate,
        currentPosition: 100,
        totalLength: 1000,
        metadata: {'key': 'value'},
      );
    });

    test('should create Book instance with all properties', () {
      expect(testBook.id, 'test-id');
      expect(testBook.title, 'Test Book');
      expect(testBook.author, 'Test Author');
      expect(testBook.content, 'This is test content');
      expect(testBook.filePath, '/path/to/book.txt');
      expect(testBook.importedAt, testDate);
      expect(testBook.lastReadAt, testDate);
      expect(testBook.currentPosition, 100);
      expect(testBook.totalLength, 1000);
      expect(testBook.metadata, {'key': 'value'});
    });

    test('should calculate reading progress correctly', () {
      expect(testBook.readingProgress, 0.1);

      final completedBook = testBook.copyWith(currentPosition: 1000);
      expect(completedBook.readingProgress, 1.0);

      final emptyBook = testBook.copyWith(totalLength: 0);
      expect(emptyBook.readingProgress, 0.0);
    });

    test('should serialize to JSON correctly', () {
      final json = testBook.toJson();
      
      expect(json['id'], 'test-id');
      expect(json['title'], 'Test Book');
      expect(json['author'], 'Test Author');
      expect(json['content'], 'This is test content');
      expect(json['filePath'], '/path/to/book.txt');
      expect(json['importedAt'], testDate.toIso8601String());
      expect(json['lastReadAt'], testDate.toIso8601String());
      expect(json['currentPosition'], 100);
      expect(json['totalLength'], 1000);
      expect(json['metadata'], {'key': 'value'});
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Book',
        'author': 'Test Author',
        'content': 'This is test content',
        'filePath': '/path/to/book.txt',
        'importedAt': testDate.toIso8601String(),
        'lastReadAt': testDate.toIso8601String(),
        'currentPosition': 100,
        'totalLength': 1000,
        'metadata': {'key': 'value'},
      };

      final book = Book.fromJson(json);
      
      expect(book.id, testBook.id);
      expect(book.title, testBook.title);
      expect(book.author, testBook.author);
      expect(book.content, testBook.content);
      expect(book.filePath, testBook.filePath);
      expect(book.currentPosition, testBook.currentPosition);
      expect(book.totalLength, testBook.totalLength);
    });

    test('should handle null optional fields in JSON', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Book',
        'content': 'Content',
        'filePath': '/path/to/book.txt',
        'importedAt': testDate.toIso8601String(),
        'totalLength': 1000,
      };

      final book = Book.fromJson(json);
      
      expect(book.author, isNull);
      expect(book.lastReadAt, isNull);
      expect(book.currentPosition, 0);
      expect(book.metadata, isNull);
    });

    test('should copy with new values correctly', () {
      final copiedBook = testBook.copyWith(
        title: 'New Title',
        currentPosition: 500,
      );

      expect(copiedBook.title, 'New Title');
      expect(copiedBook.currentPosition, 500);
      expect(copiedBook.id, testBook.id);
      expect(copiedBook.author, testBook.author);
    });

    test('should implement equality based on id', () {
      final sameBook = Book(
        id: 'test-id',
        title: 'Different Title',
        content: 'Different Content',
        filePath: '/different/path.txt',
        importedAt: DateTime.now(),
        totalLength: 2000,
      );

      final differentBook = Book(
        id: 'different-id',
        title: 'Test Book',
        content: 'This is test content',
        filePath: '/path/to/book.txt',
        importedAt: testDate,
        totalLength: 1000,
      );

      expect(testBook == sameBook, isTrue);
      expect(testBook == differentBook, isFalse);
    });

    test('should serialize and deserialize via JSON string', () {
      final jsonString = testBook.toJsonString();
      final deserializedBook = Book.fromJsonString(jsonString);

      expect(deserializedBook.id, testBook.id);
      expect(deserializedBook.title, testBook.title);
      expect(deserializedBook.content, testBook.content);
    });
  });
}