import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/models/playback_state.dart';

class StorageService {
  static const String _booksKey = 'books';
  static const String _lastPlaybackStateKey = 'last_playback_state';
  static const String _settingsKey = 'app_settings';
  static const String _bookmarksPrefix = 'bookmarks_';
  static const String _readingProgressPrefix = 'progress_';

  late final SharedPreferences _prefs;
  bool _initialized = false;

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('StorageService not initialized. Call initialize() first.');
    }
  }

  Future<List<Book>> loadBooks() async {
    _ensureInitialized();
    final String? booksJson = _prefs.getString(_booksKey);
    if (booksJson == null) return [];

    try {
      final List<dynamic> booksList = json.decode(booksJson);
      return booksList
          .map((bookMap) => Book.fromJson(bookMap as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading books: $e');
      return [];
    }
  }

  Future<bool> saveBooks(List<Book> books) async {
    _ensureInitialized();
    try {
      final String booksJson = json.encode(
        books.map((book) => book.toJson()).toList(),
      );
      return await _prefs.setString(_booksKey, booksJson);
    } catch (e) {
      print('Error saving books: $e');
      return false;
    }
  }

  Future<bool> addBook(Book book) async {
    final books = await loadBooks();
    final existingIndex = books.indexWhere((b) => b.id == book.id);
    
    if (existingIndex != -1) {
      books[existingIndex] = book;
    } else {
      books.add(book);
    }
    
    return await saveBooks(books);
  }

  Future<bool> deleteBook(String bookId) async {
    final books = await loadBooks();
    books.removeWhere((book) => book.id == bookId);
    
    await _prefs.remove('$_bookmarksPrefix$bookId');
    await _prefs.remove('$_readingProgressPrefix$bookId');
    
    return await saveBooks(books);
  }

  Future<bool> updateBookProgress(String bookId, int position) async {
    _ensureInitialized();
    final books = await loadBooks();
    final bookIndex = books.indexWhere((b) => b.id == bookId);
    
    if (bookIndex == -1) return false;
    
    books[bookIndex] = books[bookIndex].copyWith(
      currentPosition: position,
      lastReadAt: DateTime.now(),
    );
    
    final progressSaved = await _prefs.setInt(
      '$_readingProgressPrefix$bookId',
      position,
    );
    
    return await saveBooks(books) && progressSaved;
  }

  Future<int?> getBookProgress(String bookId) async {
    _ensureInitialized();
    return _prefs.getInt('$_readingProgressPrefix$bookId');
  }

  Future<PlaybackState?> loadLastPlaybackState() async {
    _ensureInitialized();
    final String? stateJson = _prefs.getString(_lastPlaybackStateKey);
    if (stateJson == null) return null;

    try {
      final Map<String, dynamic> stateMap = json.decode(stateJson);
      return PlaybackState.fromJson(stateMap);
    } catch (e) {
      print('Error loading playback state: $e');
      return null;
    }
  }

  Future<bool> savePlaybackState(PlaybackState state) async {
    _ensureInitialized();
    try {
      final String stateJson = json.encode(state.toJson());
      return await _prefs.setString(_lastPlaybackStateKey, stateJson);
    } catch (e) {
      print('Error saving playback state: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> loadSettings() async {
    _ensureInitialized();
    final String? settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson == null) {
      return _getDefaultSettings();
    }

    try {
      return json.decode(settingsJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading settings: $e');
      return _getDefaultSettings();
    }
  }

  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    _ensureInitialized();
    try {
      final String settingsJson = json.encode(settings);
      return await _prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      print('Error saving settings: $e');
      return false;
    }
  }

  Future<bool> updateSetting(String key, dynamic value) async {
    final settings = await loadSettings();
    settings[key] = value;
    return await saveSettings(settings);
  }

  Future<List<int>> getBookmarks(String bookId) async {
    _ensureInitialized();
    final List<String>? bookmarkStrings = 
        _prefs.getStringList('$_bookmarksPrefix$bookId');
    
    if (bookmarkStrings == null) return [];
    
    return bookmarkStrings
        .map((s) => int.tryParse(s))
        .where((position) => position != null)
        .cast<int>()
        .toList()
      ..sort();
  }

  Future<bool> addBookmark(String bookId, int position) async {
    final bookmarks = await getBookmarks(bookId);
    if (!bookmarks.contains(position)) {
      bookmarks.add(position);
      bookmarks.sort();
    }
    
    return await _prefs.setStringList(
      '$_bookmarksPrefix$bookId',
      bookmarks.map((p) => p.toString()).toList(),
    );
  }

  Future<bool> removeBookmark(String bookId, int position) async {
    final bookmarks = await getBookmarks(bookId);
    bookmarks.remove(position);
    
    if (bookmarks.isEmpty) {
      return await _prefs.remove('$_bookmarksPrefix$bookId');
    }
    
    return await _prefs.setStringList(
      '$_bookmarksPrefix$bookId',
      bookmarks.map((p) => p.toString()).toList(),
    );
  }

  Future<bool> clearAllData() async {
    _ensureInitialized();
    return await _prefs.clear();
  }

  Future<String?> getVibeVoiceApiUrl() async {
    final settings = await loadSettings();
    return settings['vibeVoiceApiUrl'] as String?;
  }

  Future<bool> setVibeVoiceApiUrl(String url) async {
    return await updateSetting('vibeVoiceApiUrl', url);
  }

  Map<String, dynamic> _getDefaultSettings() {
    return {
      'playbackSpeed': 1.0,
      'volume': 1.0,
      'autoScroll': true,
      'highlightText': true,
      'darkMode': false,
      'fontSize': 16.0,
      'vibeVoiceApiUrl': 'http://localhost:5000',
      'useFallbackTts': true,
      'keepScreenOn': true,
      'skipSilence': false,
      'chunkSize': 5000,
    };
  }
}