import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/services/storage_service.dart';

class BookService {
  final StorageService _storageService;
  
  BookService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  Future<void> initialize() async {
    await _storageService.initialize();
  }

  Future<List<Book>> getAllBooks() async {
    return await _storageService.loadBooks();
  }

  Future<Book?> getBook(String bookId) async {
    final books = await getAllBooks();
    try {
      return books.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  Future<List<Book>> importBooksFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'rtf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final importedBooks = <Book>[];
      
      for (final file in result.files) {
        if (file.path == null) continue;
        
        final book = await _importSingleFile(file.path!);
        if (book != null) {
          importedBooks.add(book);
          await _storageService.addBook(book);
        }
      }

      return importedBooks;
    } catch (e) {
      print('Error importing books: $e');
      return [];
    }
  }

  Future<Book?> importBookFromFile(String filePath) async {
    try {
      final book = await _importSingleFile(filePath);
      if (book != null) {
        await _storageService.addBook(book);
      }
      return book;
    } catch (e) {
      print('Error importing book from $filePath: $e');
      return null;
    }
  }

  Future<Book?> _importSingleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('File does not exist: $filePath');
        return null;
      }

      final content = await _readFileWithEncodingDetection(file);
      if (content.isEmpty) {
        print('File is empty: $filePath');
        return null;
      }

      final fileName = path.basename(filePath);
      final title = _extractTitleFromFileName(fileName);
      final author = _extractAuthorFromContent(content);
      
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final bookId = _generateBookId(title);
      final newFilePath = '${booksDir.path}/$bookId.txt';
      final newFile = File(newFilePath);
      await newFile.writeAsString(content);

      return Book(
        id: bookId,
        title: title,
        author: author,
        content: content,
        filePath: newFilePath,
        importedAt: DateTime.now(),
        totalLength: content.length,
        metadata: {
          'originalPath': filePath,
          'fileSize': await file.length(),
          'encoding': 'UTF-8',
        },
      );
    } catch (e) {
      print('Error processing file $filePath: $e');
      return null;
    }
  }

  Future<String> _readFileWithEncodingDetection(File file) async {
    try {
      return await file.readAsString(encoding: utf8);
    } catch (e) {
      try {
        return await file.readAsString(encoding: latin1);
      } catch (e) {
        try {
          return await file.readAsString(encoding: systemEncoding);
        } catch (e) {
          print('Failed to read file with any encoding: $e');
          return '';
        }
      }
    }
  }

  String _extractTitleFromFileName(String fileName) {
    final nameWithoutExtension = path.basenameWithoutExtension(fileName);
    
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

  Future<bool> deleteBook(String bookId) async {
    try {
      final book = await getBook(bookId);
      if (book != null) {
        final file = File(book.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      return await _storageService.deleteBook(bookId);
    } catch (e) {
      print('Error deleting book $bookId: $e');
      return false;
    }
  }

  Future<bool> updateBookContent(String bookId, String newContent) async {
    try {
      final book = await getBook(bookId);
      if (book == null) return false;

      final file = File(book.filePath);
      await file.writeAsString(newContent);

      final updatedBook = book.copyWith(
        content: newContent,
        totalLength: newContent.length,
      );

      return await _storageService.addBook(updatedBook);
    } catch (e) {
      print('Error updating book content for $bookId: $e');
      return false;
    }
  }

  Future<bool> updateBookMetadata(
    String bookId, {
    String? title,
    String? author,
  }) async {
    try {
      final book = await getBook(bookId);
      if (book == null) return false;

      final updatedBook = book.copyWith(
        title: title ?? book.title,
        author: author ?? book.author,
      );

      return await _storageService.addBook(updatedBook);
    } catch (e) {
      print('Error updating book metadata for $bookId: $e');
      return false;
    }
  }

  Future<List<Book>> searchBooks(String query) async {
    if (query.trim().isEmpty) {
      return await getAllBooks();
    }

    final lowerQuery = query.toLowerCase();
    final books = await getAllBooks();
    
    return books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
             (book.author?.toLowerCase().contains(lowerQuery) ?? false) ||
             book.content.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<List<Book>> getRecentBooks({int limit = 10}) async {
    final books = await getAllBooks();
    
    books.sort((a, b) {
      final aDate = a.lastReadAt ?? a.importedAt;
      final bDate = b.lastReadAt ?? b.importedAt;
      return bDate.compareTo(aDate);
    });
    
    return books.take(limit).toList();
  }

  Future<bool> exportBook(String bookId, String exportPath) async {
    try {
      final book = await getBook(bookId);
      if (book == null) return false;

      final exportFile = File(exportPath);
      await exportFile.writeAsString(book.content);
      
      return true;
    } catch (e) {
      print('Error exporting book $bookId: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getBookStatistics(String bookId) async {
    final book = await getBook(bookId);
    if (book == null) {
      return {};
    }

    final words = book.content.split(RegExp(r'\s+'));
    final sentences = book.content.split(RegExp(r'[.!?]+'));
    final paragraphs = book.content.split(RegExp(r'\n\n+'));
    
    final averageReadingSpeed = 200;
    final estimatedReadingMinutes = words.length / averageReadingSpeed;

    return {
      'totalCharacters': book.totalLength,
      'totalWords': words.length,
      'totalSentences': sentences.length,
      'totalParagraphs': paragraphs.length,
      'readingProgress': book.readingProgress,
      'estimatedReadingMinutes': estimatedReadingMinutes.round(),
      'lastReadAt': book.lastReadAt?.toIso8601String(),
      'importedAt': book.importedAt.toIso8601String(),
    };
  }

  Future<void> cleanupOrphanedFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      
      if (!await booksDir.exists()) return;

      final books = await getAllBooks();
      final validFilePaths = books.map((b) => b.filePath).toSet();

      await for (final file in booksDir.list()) {
        if (file is File && !validFilePaths.contains(file.path)) {
          await file.delete();
          print('Deleted orphaned file: ${file.path}');
        }
      }
    } catch (e) {
      print('Error cleaning up orphaned files: $e');
    }
  }
}