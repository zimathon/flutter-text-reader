import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/screens/reader_screen.dart';
import 'package:text_reader_app/screens/settings_screen.dart';
import 'package:text_reader_app/view_models/book_list_vm.dart';
import 'package:text_reader_app/view_models/player_vm.dart';
import 'package:text_reader_app/widgets/book_list_item.dart';
import 'package:text_reader_app/widgets/empty_state.dart';
import 'package:text_reader_app/widgets/search_bar.dart' as app;

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookListState = ref.watch(bookListViewModelProvider);
    final bookListViewModel = ref.read(bookListViewModelProvider.notifier);
    final sortedBooks = ref.watch(sortedBooksProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final sortMode = ref.watch(sortModeProvider);
    
    final isSearching = useState(false);
    final selectedTab = useState(0);
    
    useEffect(() {
      // Load books on mount
      Future.microtask(() => bookListViewModel.loadBooks());
      return null;
    }, []);
    
    return Scaffold(
      appBar: AppBar(
        title: isSearching.value
            ? app.SearchBar(
                onChanged: (query) {
                  ref.read(searchQueryProvider.notifier).state = query;
                },
                onClear: () {
                  ref.read(searchQueryProvider.notifier).state = '';
                  isSearching.value = false;
                },
              )
            : const Text('テキストリーダー'),
        actions: [
          if (!isSearching.value) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => isSearching.value = true,
            ),
            PopupMenuButton<SortMode>(
              icon: const Icon(Icons.sort),
              onSelected: (mode) {
                ref.read(sortModeProvider.notifier).state = mode;
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: SortMode.title,
                  child: Text('タイトル順'),
                ),
                const PopupMenuItem(
                  value: SortMode.author,
                  child: Text('著者順'),
                ),
                const PopupMenuItem(
                  value: SortMode.lastRead,
                  child: Text('最近読んだ順'),
                ),
                const PopupMenuItem(
                  value: SortMode.imported,
                  child: Text('追加日順'),
                ),
                const PopupMenuItem(
                  value: SortMode.progress,
                  child: Text('進捗順'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ],
        bottom: bookListState.isSelectionMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => bookListViewModel.clearSelection(),
                      ),
                      Text(
                        '${bookListState.selectedBookIds.length}件選択中',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        onPressed: () => bookListViewModel.selectAll(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final confirmed = await _showDeleteConfirmation(
                            context,
                            bookListState.selectedBookIds.length,
                          );
                          if (confirmed) {
                            await bookListViewModel.deleteSelectedBooks();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: bookListState.isLoading && sortedBooks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : sortedBooks.isEmpty
              ? EmptyState(
                  icon: Icons.library_books,
                  title: searchQuery.isNotEmpty
                      ? '検索結果がありません'
                      : '書籍がありません',
                  subtitle: searchQuery.isNotEmpty
                      ? '別のキーワードで検索してください'
                      : 'ファイルをインポートして始めましょう',
                  actionLabel: searchQuery.isNotEmpty ? '検索をクリア' : 'ファイルを追加',
                  onAction: searchQuery.isNotEmpty
                      ? () {
                          ref.read(searchQueryProvider.notifier).state = '';
                        }
                      : () async {
                          await _importBooks(context, bookListViewModel);
                        },
                )
              : RefreshIndicator(
                  onRefresh: () => bookListViewModel.refreshBooks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sortedBooks.length,
                    itemBuilder: (context, index) {
                      final book = sortedBooks[index];
                      final isSelected = bookListState.selectedBookIds.contains(book.id);
                      
                      return BookListItem(
                        book: book,
                        isSelected: isSelected,
                        isSelectionMode: bookListState.isSelectionMode,
                        onTap: () {
                          if (bookListState.isSelectionMode) {
                            bookListViewModel.toggleBookSelection(book.id);
                          } else {
                            _openBook(context, ref, book);
                          }
                        },
                        onLongPress: () {
                          if (!bookListState.isSelectionMode) {
                            bookListViewModel.toggleSelectionMode();
                          }
                          bookListViewModel.toggleBookSelection(book.id);
                        },
                        onDelete: () async {
                          final confirmed = await _showDeleteConfirmation(context, 1);
                          if (confirmed) {
                            await bookListViewModel.deleteBook(book.id);
                          }
                        },
                        onEdit: () => _showEditDialog(context, bookListViewModel, book),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _importBooks(context, bookListViewModel);
        },
        icon: const Icon(Icons.add),
        label: const Text('ファイルを追加'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab.value,
        onTap: (index) {
          selectedTab.value = index;
          if (index == 1) {
            // Statistics tab
            _showStatistics(context, bookListViewModel);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'ライブラリ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '統計',
          ),
        ],
      ),
    );
  }
  
  Future<void> _importBooks(BuildContext context, BookListViewModel viewModel) async {
    final importedBooks = await viewModel.importBooks();
    
    if (context.mounted) {
      if (importedBooks.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${importedBooks.length}冊の本をインポートしました'),
            action: SnackBarAction(
              label: '開く',
              onPressed: () {
                if (importedBooks.isNotEmpty) {
                  _openBook(context, ProviderScope.containerOf(context), importedBooks.first);
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ファイルが選択されませんでした'),
          ),
        );
      }
    }
  }
  
  void _openBook(BuildContext context, WidgetRef ref, Book book) {
    // Update current book
    ref.read(currentBookProvider.notifier).state = book;
    
    // Navigate to reader screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(book: book),
      ),
    );
  }
  
  Future<bool> _showDeleteConfirmation(BuildContext context, int count) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('$count冊の本を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  Future<void> _showEditDialog(
    BuildContext context,
    BookListViewModel viewModel,
    Book book,
  ) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('書籍情報を編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: '著者',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    
    if (result == true && context.mounted) {
      final success = await viewModel.updateBookMetadata(
        book.id,
        title: titleController.text,
        author: authorController.text.isEmpty ? null : authorController.text,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '更新しました' : '更新に失敗しました'),
          ),
        );
      }
    }
    
    titleController.dispose();
    authorController.dispose();
  }
  
  void _showStatistics(BuildContext context, BookListViewModel viewModel) {
    final stats = viewModel.getStatistics();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '読書統計',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _StatisticRow(
              label: '総書籍数',
              value: '${stats['totalBooks']}冊',
              icon: Icons.library_books,
            ),
            _StatisticRow(
              label: '読了',
              value: '${stats['completedBooks']}冊',
              icon: Icons.check_circle,
            ),
            _StatisticRow(
              label: '読書中',
              value: '${stats['inProgressBooks']}冊',
              icon: Icons.play_circle,
            ),
            _StatisticRow(
              label: '総単語数',
              value: '約${_formatNumber(stats['totalWords'])}語',
              icon: Icons.text_fields,
            ),
            _StatisticRow(
              label: '平均進捗',
              value: '${(stats['averageProgress'] * 100).toStringAsFixed(1)}%',
              icon: Icons.trending_up,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatisticRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  
  const _StatisticRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}