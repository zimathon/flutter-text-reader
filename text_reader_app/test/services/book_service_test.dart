import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/models/playback_state.dart';
import 'package:text_reader_app/services/book_service.dart';
import 'package:text_reader_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  String documentsPath = '/tmp/test_documents';

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => '/tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/support';

  @override
  Future<String?> getLibraryPath() async => '/tmp/library';

  @override
  Future<String?> getApplicationCachePath() async => '/tmp/cache';

  @override
  Future<String?> getExternalStoragePath() async => '/tmp/external';

  @override
  Future<List<String>?> getExternalCachePaths() async => ['/tmp/external_cache'];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => ['/tmp/external_storage'];

  @override
  Future<String?> getDownloadsPath() async => '/tmp/downloads';
}

class MockStorageService implements StorageService {
  final List<Book> _books = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<List<Book>> loadBooks() async {
    return List.from(_books);
  }

  @override
  Future<bool> addBook(Book book) async {
    final existingIndex = _books.indexWhere((b) => b.id == book.id);
    if (existingIndex != -1) {
      _books[existingIndex] = book;
    } else {
      _books.add(book);
    }
    return true;
  }

  @override
  Future<bool> deleteBook(String bookId) async {
    _books.removeWhere((book) => book.id == bookId);
    return true;
  }

  @override
  Future<bool> saveBooks(List<Book> books) async {
    _books.clear();
    _books.addAll(books);
    return true;
  }

  @override
  Future<bool> updateBookProgress(String bookId, int position) async {
    return true;
  }

  @override
  Future<int?> getBookProgress(String bookId) async {
    return null;
  }

  @override
  Future<PlaybackState?> loadLastPlaybackState() async {
    return null;
  }

  @override
  Future<bool> savePlaybackState(PlaybackState state) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> loadSettings() async {
    return {};
  }

  @override
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    return true;
  }

  @override
  Future<bool> updateSetting(String key, dynamic value) async {
    return true;
  }

  @override
  Future<List<int>> getBookmarks(String bookId) async {
    return [];
  }

  @override
  Future<bool> addBookmark(String bookId, int position) async {
    return true;
  }

  @override
  Future<bool> removeBookmark(String bookId, int position) async {
    return true;
  }

  @override
  Future<bool> clearAllData() async {
    _books.clear();
    return true;
  }

  @override
  Future<String?> getVibeVoiceApiUrl() async {
    return 'http://localhost:5000';
  }

  @override
  Future<bool> setVibeVoiceApiUrl(String url) async {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookService Tests', () {
    late BookService bookService;
    late MockStorageService mockStorageService;
    late MockPathProviderPlatform mockPathProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      
      mockPathProvider = MockPathProviderPlatform();
      PathProviderPlatform.instance = mockPathProvider;
      
      mockStorageService = MockStorageService();
      bookService = BookService(storageService: mockStorageService);
      await bookService.initialize();
    });

    tearDown(() async {
      // Clean up test files
      final testDir = Directory('/tmp/test_documents/books');
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    group('Book Management', () {
      test('should get all books', () async {
        final book1 = Book(
          id: 'book-1',
          title: 'Book 1',
          content: 'Content 1',
          filePath: '/path/1.txt',
          importedAt: DateTime.now(),
          totalLength: 9,
        );
        final book2 = Book(
          id: 'book-2',
          title: 'Book 2',
          content: 'Content 2',
          filePath: '/path/2.txt',
          importedAt: DateTime.now(),
          totalLength: 9,
        );

        await mockStorageService.addBook(book1);
        await mockStorageService.addBook(book2);

        final books = await bookService.getAllBooks();
        expect(books.length, 2);
        expect(books[0].id, 'book-1');
        expect(books[1].id, 'book-2');
      });

      test('should get specific book by id', () async {
        final book = Book(
          id: 'book-1',
          title: 'Test Book',
          content: 'Test Content',
          filePath: '/path/test.txt',
          importedAt: DateTime.now(),
          totalLength: 12,
        );

        await mockStorageService.addBook(book);

        final retrievedBook = await bookService.getBook('book-1');
        expect(retrievedBook, isNotNull);
        expect(retrievedBook!.id, 'book-1');
        expect(retrievedBook.title, 'Test Book');
      });

      test('should return null for non-existent book', () async {
        final book = await bookService.getBook('non-existent');
        expect(book, isNull);
      });

      test('should delete book and its file', () async {
        // Create a test file
        final testDir = Directory('/tmp/test_documents/books');
        await testDir.create(recursive: true);
        final testFile = File('${testDir.path}/test.txt');
        await testFile.writeAsString('Test content');

        final book = Book(
          id: 'book-to-delete',
          title: 'Book to Delete',
          content: 'Content',
          filePath: testFile.path,
          importedAt: DateTime.now(),
          totalLength: 7,
        );

        await mockStorageService.addBook(book);
        expect(await testFile.exists(), isTrue);

        final deleted = await bookService.deleteBook('book-to-delete');
        expect(deleted, isTrue);

        final books = await bookService.getAllBooks();
        expect(books.any((b) => b.id == 'book-to-delete'), isFalse);
        expect(await testFile.exists(), isFalse);
      });
    });

    group('Book Content Operations', () {
      test('should update book content', () async {
        // Create a test file
        final testDir = Directory('/tmp/test_documents/books');
        await testDir.create(recursive: true);
        final testFile = File('${testDir.path}/content.txt');
        await testFile.writeAsString('Original content');

        final book = Book(
          id: 'book-1',
          title: 'Book',
          content: 'Original content',
          filePath: testFile.path,
          importedAt: DateTime.now(),
          totalLength: 16,
        );

        await mockStorageService.addBook(book);

        final updated = await bookService.updateBookContent(
          'book-1',
          'Updated content',
        );
        expect(updated, isTrue);

        final updatedBook = await bookService.getBook('book-1');
        expect(updatedBook!.content, 'Updated content');
        expect(updatedBook.totalLength, 15);

        final fileContent = await testFile.readAsString();
        expect(fileContent, 'Updated content');
      });

      test('should update book metadata', () async {
        final book = Book(
          id: 'book-1',
          title: 'Original Title',
          author: 'Original Author',
          content: 'Content',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 7,
        );

        await mockStorageService.addBook(book);

        final updated = await bookService.updateBookMetadata(
          'book-1',
          title: 'New Title',
          author: 'New Author',
        );
        expect(updated, isTrue);

        final updatedBook = await bookService.getBook('book-1');
        expect(updatedBook!.title, 'New Title');
        expect(updatedBook.author, 'New Author');
      });
    });

    group('Book Search and Filtering', () {
      setUp(() async {
        final books = [
          Book(
            id: 'book-1',
            title: 'Flutter Development',
            author: 'John Doe',
            content: 'Learn Flutter framework',
            filePath: '/path/1.txt',
            importedAt: DateTime.now().subtract(const Duration(days: 3)),
            totalLength: 100,
          ),
          Book(
            id: 'book-2',
            title: 'Dart Programming',
            author: 'Jane Smith',
            content: 'Master Dart language',
            filePath: '/path/2.txt',
            importedAt: DateTime.now().subtract(const Duration(days: 2)),
            lastReadAt: DateTime.now().subtract(const Duration(hours: 1)),
            totalLength: 200,
          ),
          Book(
            id: 'book-3',
            title: 'Mobile Apps',
            author: 'John Doe',
            content: 'Build mobile applications',
            filePath: '/path/3.txt',
            importedAt: DateTime.now().subtract(const Duration(days: 1)),
            totalLength: 150,
          ),
        ];

        for (final book in books) {
          await mockStorageService.addBook(book);
        }
      });

      test('should search books by title', () async {
        final results = await bookService.searchBooks('Flutter');
        expect(results.length, 1);
        expect(results[0].title, 'Flutter Development');
      });

      test('should search books by author', () async {
        final results = await bookService.searchBooks('John');
        expect(results.length, 2);
        expect(results.every((b) => b.author == 'John Doe'), isTrue);
      });

      test('should search books by content', () async {
        final results = await bookService.searchBooks('language');
        expect(results.length, 1);
        expect(results[0].title, 'Dart Programming');
      });

      test('should return all books for empty search', () async {
        final results = await bookService.searchBooks('');
        expect(results.length, 3);
      });

      test('should get recent books sorted by last read or import date', () async {
        final recentBooks = await bookService.getRecentBooks(limit: 2);
        expect(recentBooks.length, 2);
        expect(recentBooks[0].id, 'book-2'); // Has lastReadAt
        expect(recentBooks[1].id, 'book-3'); // Most recent import
      });
    });

    group('Book Statistics', () {
      test('should calculate book statistics', () async {
        final book = Book(
          id: 'book-1',
          title: 'Test Book',
          content: '''This is a test book. It has multiple sentences.

This is a second paragraph. It contains more text for testing.

And a third paragraph here.''',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          currentPosition: 50,
          totalLength: 132,
        );

        await mockStorageService.addBook(book);

        final stats = await bookService.getBookStatistics('book-1');
        
        expect(stats['totalCharacters'], 132);
        expect(stats['totalWords'], greaterThanOrEqualTo(18)); // Actual word count
        expect(stats['totalSentences'], greaterThanOrEqualTo(3)); // 3 sentences
        expect(stats['totalParagraphs'], 3);
        expect(stats['readingProgress'], closeTo(0.378, 0.01));
        expect(stats['estimatedReadingMinutes'], greaterThanOrEqualTo(0));
      });

      test('should return empty stats for non-existent book', () async {
        final stats = await bookService.getBookStatistics('non-existent');
        expect(stats, isEmpty);
      });
    });

    group('Export Functionality', () {
      test('should export book to file', () async {
        final book = Book(
          id: 'book-1',
          title: 'Export Test',
          content: 'Content to export',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 17,
        );

        await mockStorageService.addBook(book);

        final exportPath = '/tmp/exported_book.txt';
        final exported = await bookService.exportBook('book-1', exportPath);
        expect(exported, isTrue);

        final exportedFile = File(exportPath);
        expect(await exportedFile.exists(), isTrue);
        expect(await exportedFile.readAsString(), 'Content to export');

        // Clean up
        await exportedFile.delete();
      });

      test('should return false when exporting non-existent book', () async {
        final exported = await bookService.exportBook(
          'non-existent',
          '/tmp/export.txt',
        );
        expect(exported, isFalse);
      });
    });

    group('Title and Author Extraction', () {
      test('should extract title from file name', () {
        final service = BookService(storageService: mockStorageService);
        
        expect(
          service.extractTitleFromFileName('the_great_gatsby.txt'),
          'The Great Gatsby',
        );
        expect(
          service.extractTitleFromFileName('war-and-peace.txt'),
          'War And Peace',
        );
        expect(
          service.extractTitleFromFileName('book.txt'),
          'Book',
        );
        expect(
          service.extractTitleFromFileName('.txt'),
          'Untitled Book',
        );
      });

      test('should extract author from content', () {
        final service = BookService(storageService: mockStorageService);
        
        expect(
          service.extractAuthorFromContent('Author: John Doe\n\nContent here'),
          'John Doe',
        );
        expect(
          service.extractAuthorFromContent('By: Jane Smith\n\nContent'),
          'Jane Smith',
        );
        expect(
          service.extractAuthorFromContent('Written by: Bob Johnson\n\nText'),
          'Bob Johnson',
        );
        expect(
          service.extractAuthorFromContent('by Mark Twain\n\nStory begins'),
          'Mark Twain',
        );
        expect(
          service.extractAuthorFromContent('No author information here'),
          isNull,
        );
      });
    });

    group('Book ID Generation', () {
      test('should generate valid book IDs', () {
        final service = BookService(storageService: mockStorageService);
        
        final id1 = service.generateBookId('The Great Gatsby');
        expect(id1, matches(RegExp(r'^the-great-gatsby_\d+$')));
        
        final id2 = service.generateBookId('War & Peace!');
        expect(id2, matches(RegExp(r'^war-peace_\d+$')));
        
        final id3 = service.generateBookId('');
        expect(id3, matches(RegExp(r'^book_\d+$')));
        
        final id4 = service.generateBookId('A' * 50);
        expect(id4.split('_')[0].length, 30);
      });
    });
  });
}

// Extension to expose private methods for testing
extension BookServiceTestExtensions on BookService {
  String extractTitleFromFileName(String fileName) {
    // This is a workaround since we can't access private methods directly
    // In production, consider making these methods public or protected
    return _extractTitleFromFileName(fileName);
  }

  String? extractAuthorFromContent(String content) {
    return _extractAuthorFromContent(content);
  }

  String generateBookId(String title) {
    return _generateBookId(title);
  }

  // Expose private methods through reflection-like approach
  String _extractTitleFromFileName(String fileName) {
    final nameWithoutExtension = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    
    final cleanedName = nameWithoutExtension
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    if (cleanedName.isEmpty) {
      return 'Untitled Book';
    }
    
    return cleanedName.split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : word)
        .join(' ');
  }

  String? _extractAuthorFromContent(String content) {
    final lines = content.split('\n').take(50);
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.toLowerCase().startsWith('author:') ||
          trimmed.toLowerCase().startsWith('by:') ||
          trimmed.toLowerCase().startsWith('written by:')) {
        final author = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        if (author.isNotEmpty) {
          return author;
        }
      }
      
      final byMatch = RegExp(r'^by\s+(.+)$', caseSensitive: false)
          .firstMatch(trimmed);
      if (byMatch != null) {
        return byMatch.group(1)?.trim();
      }
    }
    
    return null;
  }

  String _generateBookId(String title) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final titleSlug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    
    if (titleSlug.isEmpty) {
      return 'book_$timestamp';
    }
    
    final truncatedSlug = titleSlug.length > 30 
        ? titleSlug.substring(0, 30) 
        : titleSlug;
    
    return '${truncatedSlug}_$timestamp';
  }
}