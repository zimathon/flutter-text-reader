import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/services/book_service.dart';
import 'package:text_reader_app/services/storage_service.dart';

// Providers
final bookServiceProvider = Provider<BookService>((ref) {
  return BookService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final bookListViewModelProvider = 
    StateNotifierProvider<BookListViewModel, BookListState>((ref) {
  final bookService = ref.watch(bookServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return BookListViewModel(bookService, storageService);
});

// Search provider
final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredBooksProvider = Provider<List<Book>>((ref) {
  final bookListState = ref.watch(bookListViewModelProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  
  if (searchQuery.isEmpty) {
    return bookListState.books;
  }
  
  final lowerQuery = searchQuery.toLowerCase();
  return bookListState.books.where((book) {
    return book.title.toLowerCase().contains(lowerQuery) ||
           (book.author?.toLowerCase().contains(lowerQuery) ?? false);
  }).toList();
});

// Sort mode provider
enum SortMode { title, author, lastRead, imported, progress }

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.lastRead);

final sortedBooksProvider = Provider<List<Book>>((ref) {
  final books = ref.watch(filteredBooksProvider);
  final sortMode = ref.watch(sortModeProvider);
  
  final sortedBooks = List<Book>.from(books);
  
  switch (sortMode) {
    case SortMode.title:
      sortedBooks.sort((a, b) => a.title.compareTo(b.title));
      break;
    case SortMode.author:
      sortedBooks.sort((a, b) {
        final authorA = a.author ?? '';
        final authorB = b.author ?? '';
        return authorA.compareTo(authorB);
      });
      break;
    case SortMode.lastRead:
      sortedBooks.sort((a, b) {
        final dateA = a.lastReadAt ?? a.importedAt;
        final dateB = b.lastReadAt ?? b.importedAt;
        return dateB.compareTo(dateA);
      });
      break;
    case SortMode.imported:
      sortedBooks.sort((a, b) => b.importedAt.compareTo(a.importedAt));
      break;
    case SortMode.progress:
      sortedBooks.sort((a, b) => b.readingProgress.compareTo(a.readingProgress));
      break;
  }
  
  return sortedBooks;
});

// State class
@immutable
class BookListState {
  final List<Book> books;
  final bool isLoading;
  final String? error;
  final Set<String> selectedBookIds;
  final bool isSelectionMode;

  const BookListState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.selectedBookIds = const {},
    this.isSelectionMode = false,
  });

  BookListState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
    Set<String>? selectedBookIds,
    bool? isSelectionMode,
  }) {
    return BookListState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedBookIds: selectedBookIds ?? this.selectedBookIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

// ViewModel
class BookListViewModel extends StateNotifier<BookListState> {
  final BookService _bookService;
  final StorageService _storageService;
  
  BookListViewModel(this._bookService, this._storageService)
      : super(const BookListState()) {
    initialize();
  }
  
  Future<void> initialize() async {
    try {
      await _bookService.initialize();
      await _storageService.initialize();
      await loadBooks();
    } catch (e) {
      state = state.copyWith(error: 'Initialization failed: $e');
    }
  }
  
  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final books = await _bookService.getAllBooks();
      state = state.copyWith(
        books: books,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load books: $e',
      );
    }
  }
  
  Future<List<Book>> importBooks() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final importedBooks = await _bookService.importBooksFromFiles();
      
      if (importedBooks.isNotEmpty) {
        await loadBooks(); // Reload to get updated list
      }
      
      state = state.copyWith(isLoading: false);
      return importedBooks;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to import books: $e',
      );
      return [];
    }
  }
  
  Future<bool> deleteBook(String bookId) async {
    try {
      final success = await _bookService.deleteBook(bookId);
      
      if (success) {
        state = state.copyWith(
          books: state.books.where((b) => b.id != bookId).toList(),
          selectedBookIds: state.selectedBookIds.difference({bookId}),
        );
      }
      
      return success;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete book: $e');
      return false;
    }
  }
  
  Future<bool> deleteSelectedBooks() async {
    if (state.selectedBookIds.isEmpty) return false;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      bool allSuccess = true;
      
      for (final bookId in state.selectedBookIds) {
        final success = await _bookService.deleteBook(bookId);
        if (!success) allSuccess = false;
      }
      
      await loadBooks();
      clearSelection();
      
      state = state.copyWith(isLoading: false);
      return allSuccess;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete selected books: $e',
      );
      return false;
    }
  }
  
  Future<bool> updateBookMetadata(
    String bookId, {
    String? title,
    String? author,
  }) async {
    try {
      final success = await _bookService.updateBookMetadata(
        bookId,
        title: title,
        author: author,
      );
      
      if (success) {
        await loadBooks();
      }
      
      return success;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update book: $e');
      return false;
    }
  }
  
  Future<void> refreshBooks() async {
    await loadBooks();
  }
  
  Future<List<Book>> getRecentBooks({int limit = 5}) async {
    try {
      return await _bookService.getRecentBooks(limit: limit);
    } catch (e) {
      print('Failed to get recent books: $e');
      return [];
    }
  }
  
  // Selection mode methods
  void toggleSelectionMode() {
    state = state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedBookIds: state.isSelectionMode ? {} : state.selectedBookIds,
    );
  }
  
  void toggleBookSelection(String bookId) {
    final selectedIds = Set<String>.from(state.selectedBookIds);
    
    if (selectedIds.contains(bookId)) {
      selectedIds.remove(bookId);
    } else {
      selectedIds.add(bookId);
    }
    
    state = state.copyWith(selectedBookIds: selectedIds);
  }
  
  void selectAll() {
    state = state.copyWith(
      selectedBookIds: state.books.map((b) => b.id).toSet(),
    );
  }
  
  void clearSelection() {
    state = state.copyWith(
      selectedBookIds: {},
      isSelectionMode: false,
    );
  }
  
  bool isBookSelected(String bookId) {
    return state.selectedBookIds.contains(bookId);
  }
  
  // Statistics
  Map<String, dynamic> getStatistics() {
    final books = state.books;
    
    if (books.isEmpty) {
      return {
        'totalBooks': 0,
        'completedBooks': 0,
        'inProgressBooks': 0,
        'totalWords': 0,
        'averageProgress': 0.0,
      };
    }
    
    int completedCount = 0;
    int inProgressCount = 0;
    int totalWords = 0;
    double totalProgress = 0.0;
    
    for (final book in books) {
      if (book.readingProgress >= 0.95) {
        completedCount++;
      } else if (book.readingProgress > 0) {
        inProgressCount++;
      }
      
      // Estimate word count (rough approximation)
      totalWords += (book.totalLength / 5).round();
      totalProgress += book.readingProgress;
    }
    
    return {
      'totalBooks': books.length,
      'completedBooks': completedCount,
      'inProgressBooks': inProgressCount,
      'totalWords': totalWords,
      'averageProgress': totalProgress / books.length,
    };
  }
  
  // Clean up
  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}