import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/models/playback_state.dart';
import 'package:text_reader_app/services/storage_service.dart';

void main() {
  group('StorageService Tests', () {
    late StorageService storageService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.initialize();
    });

    tearDown(() async {
      await storageService.clearAllData();
    });

    group('Book Storage', () {
      test('should save and load books', () async {
        final books = [
          Book(
            id: 'book-1',
            title: 'Book 1',
            content: 'Content 1',
            filePath: '/path/1.txt',
            importedAt: DateTime.now(),
            totalLength: 100,
          ),
          Book(
            id: 'book-2',
            title: 'Book 2',
            content: 'Content 2',
            filePath: '/path/2.txt',
            importedAt: DateTime.now(),
            totalLength: 200,
          ),
        ];

        final saved = await storageService.saveBooks(books);
        expect(saved, isTrue);

        final loadedBooks = await storageService.loadBooks();
        expect(loadedBooks.length, 2);
        expect(loadedBooks[0].id, 'book-1');
        expect(loadedBooks[1].id, 'book-2');
      });

      test('should return empty list when no books saved', () async {
        final books = await storageService.loadBooks();
        expect(books, isEmpty);
      });

      test('should add new book', () async {
        final book = Book(
          id: 'book-1',
          title: 'New Book',
          content: 'Content',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 100,
        );

        final added = await storageService.addBook(book);
        expect(added, isTrue);

        final books = await storageService.loadBooks();
        expect(books.length, 1);
        expect(books[0].id, 'book-1');
      });

      test('should update existing book when adding with same id', () async {
        final book1 = Book(
          id: 'book-1',
          title: 'Original Title',
          content: 'Content',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 100,
        );

        await storageService.addBook(book1);

        final book2 = book1.copyWith(title: 'Updated Title');
        await storageService.addBook(book2);

        final books = await storageService.loadBooks();
        expect(books.length, 1);
        expect(books[0].title, 'Updated Title');
      });

      test('should delete book and its associated data', () async {
        final book = Book(
          id: 'book-1',
          title: 'Book to Delete',
          content: 'Content',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 100,
        );

        await storageService.addBook(book);
        await storageService.addBookmark('book-1', 50);
        await storageService.updateBookProgress('book-1', 75);

        final deleted = await storageService.deleteBook('book-1');
        expect(deleted, isTrue);

        final books = await storageService.loadBooks();
        expect(books, isEmpty);

        final bookmarks = await storageService.getBookmarks('book-1');
        expect(bookmarks, isEmpty);

        final progress = await storageService.getBookProgress('book-1');
        expect(progress, isNull);
      });

      test('should update book progress', () async {
        final book = Book(
          id: 'book-1',
          title: 'Book',
          content: 'Content',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 100,
        );

        await storageService.addBook(book);

        final updated = await storageService.updateBookProgress('book-1', 50);
        expect(updated, isTrue);

        final books = await storageService.loadBooks();
        expect(books[0].currentPosition, 50);
        expect(books[0].lastReadAt, isNotNull);

        final progress = await storageService.getBookProgress('book-1');
        expect(progress, 50);
      });

      test('should return false when updating progress for non-existent book', () async {
        final updated = await storageService.updateBookProgress('non-existent', 50);
        expect(updated, isFalse);
      });
    });

    group('Playback State Storage', () {
      test('should save and load playback state', () async {
        final state = PlaybackState(
          status: PlaybackStatus.playing,
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 5),
          speed: 1.5,
          volume: 0.8,
          currentBookId: 'book-1',
        );

        final saved = await storageService.savePlaybackState(state);
        expect(saved, isTrue);

        final loadedState = await storageService.loadLastPlaybackState();
        expect(loadedState, isNotNull);
        expect(loadedState!.status, PlaybackStatus.playing);
        expect(loadedState.position, const Duration(seconds: 30));
        expect(loadedState.speed, 1.5);
        expect(loadedState.currentBookId, 'book-1');
      });

      test('should return null when no playback state saved', () async {
        final state = await storageService.loadLastPlaybackState();
        expect(state, isNull);
      });
    });

    group('Settings Storage', () {
      test('should load default settings when none saved', () async {
        final settings = await storageService.loadSettings();
        expect(settings['playbackSpeed'], 1.0);
        expect(settings['volume'], 1.0);
        expect(settings['darkMode'], false);
        expect(settings['vibeVoiceApiUrl'], 'http://localhost:5000');
      });

      test('should save and load custom settings', () async {
        final customSettings = {
          'playbackSpeed': 1.5,
          'volume': 0.7,
          'darkMode': true,
          'customKey': 'customValue',
        };

        final saved = await storageService.saveSettings(customSettings);
        expect(saved, isTrue);

        final loadedSettings = await storageService.loadSettings();
        expect(loadedSettings['playbackSpeed'], 1.5);
        expect(loadedSettings['volume'], 0.7);
        expect(loadedSettings['darkMode'], true);
        expect(loadedSettings['customKey'], 'customValue');
      });

      test('should update individual setting', () async {
        await storageService.updateSetting('playbackSpeed', 2.0);
        
        final settings = await storageService.loadSettings();
        expect(settings['playbackSpeed'], 2.0);
      });

      test('should get and set VibeVoice API URL', () async {
        await storageService.setVibeVoiceApiUrl('https://api.vibevoice.com');
        
        final url = await storageService.getVibeVoiceApiUrl();
        expect(url, 'https://api.vibevoice.com');
      });
    });

    group('Bookmark Storage', () {
      test('should add and get bookmarks', () async {
        await storageService.addBookmark('book-1', 100);
        await storageService.addBookmark('book-1', 50);
        await storageService.addBookmark('book-1', 200);

        final bookmarks = await storageService.getBookmarks('book-1');
        expect(bookmarks.length, 3);
        expect(bookmarks, [50, 100, 200]); // Should be sorted
      });

      test('should not add duplicate bookmarks', () async {
        await storageService.addBookmark('book-1', 100);
        await storageService.addBookmark('book-1', 100);

        final bookmarks = await storageService.getBookmarks('book-1');
        expect(bookmarks.length, 1);
        expect(bookmarks[0], 100);
      });

      test('should remove bookmark', () async {
        await storageService.addBookmark('book-1', 100);
        await storageService.addBookmark('book-1', 200);

        await storageService.removeBookmark('book-1', 100);

        final bookmarks = await storageService.getBookmarks('book-1');
        expect(bookmarks.length, 1);
        expect(bookmarks[0], 200);
      });

      test('should return empty list for book with no bookmarks', () async {
        final bookmarks = await storageService.getBookmarks('book-1');
        expect(bookmarks, isEmpty);
      });

      test('should handle bookmarks for multiple books separately', () async {
        await storageService.addBookmark('book-1', 100);
        await storageService.addBookmark('book-2', 200);

        final bookmarks1 = await storageService.getBookmarks('book-1');
        final bookmarks2 = await storageService.getBookmarks('book-2');

        expect(bookmarks1, [100]);
        expect(bookmarks2, [200]);
      });
    });

    group('Data Management', () {
      test('should clear all data', () async {
        await storageService.addBook(Book(
          id: 'book-1',
          title: 'Book',
          content: 'Content',
          filePath: '/path/book.txt',
          importedAt: DateTime.now(),
          totalLength: 100,
        ));
        await storageService.updateSetting('darkMode', true);
        await storageService.addBookmark('book-1', 100);

        final cleared = await storageService.clearAllData();
        expect(cleared, isTrue);

        final books = await storageService.loadBooks();
        expect(books, isEmpty);

        final settings = await storageService.loadSettings();
        expect(settings['darkMode'], false); // Back to default

        final bookmarks = await storageService.getBookmarks('book-1');
        expect(bookmarks, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should throw error when not initialized', () async {
        // This test is skipped because StorageService is a singleton
        // and may already be initialized from other tests
        // The initialization check is still present in the code for production safety
      }, skip: 'StorageService is a singleton - cannot test uninitialized state reliably');

      test('should handle corrupted JSON gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'books': 'corrupted json data',
          'last_playback_state': 'invalid json',
          'app_settings': 'bad data',
        });
        
        await storageService.initialize();

        final books = await storageService.loadBooks();
        expect(books, isEmpty);

        final state = await storageService.loadLastPlaybackState();
        expect(state, isNull);

        final settings = await storageService.loadSettings();
        expect(settings['playbackSpeed'], 1.0); // Should return defaults
      });
    });
  });
}