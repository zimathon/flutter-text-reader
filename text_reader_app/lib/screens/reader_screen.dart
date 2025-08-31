import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/view_models/player_vm.dart';
import 'package:text_reader_app/view_models/settings_vm.dart';
import 'package:text_reader_app/widgets/playback_controls.dart';
import 'package:text_reader_app/widgets/text_display.dart';
import 'package:text_reader_app/widgets/chapter_drawer.dart';

class ReaderScreen extends HookConsumerWidget {
  final Book book;

  const ReaderScreen({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerViewModelProvider);
    final playerViewModel = ref.read(playerViewModelProvider.notifier);
    final settings = ref.watch(settingsViewModelProvider);
    final playbackPosition = ref.watch(playbackPositionProvider);
    
    final scrollController = useScrollController();
    final isControlsVisible = useState(true);
    final hideControlsTimer = useRef<Timer?>(null);
    final scaffoldKey = useMemoized(() => GlobalKey<ScaffoldState>());
    
    // Load book on mount
    useEffect(() {
      Future.microtask(() async {
        await playerViewModel.loadBook(book);
        
        // Keep screen on if enabled
        if (settings.keepScreenOn) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      });
      
      return () {
        // Restore system UI on dispose
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        hideControlsTimer.value?.cancel();
      };
    }, [book.id]);
    
    // Auto-hide controls
    useEffect(() {
      void resetHideTimer() {
        hideControlsTimer.value?.cancel();
        if (playerState.isPlaying) {
          hideControlsTimer.value = Timer(const Duration(seconds: 3), () {
            isControlsVisible.value = false;
          });
        }
      }
      
      if (isControlsVisible.value) {
        resetHideTimer();
      }
      
      return () => hideControlsTimer.value?.cancel();
    }, [isControlsVisible.value, playerState.isPlaying]);
    
    // Auto-scroll to current position
    useEffect(() {
      if (playerState.autoScroll && playerState.currentTextPosition > 0) {
        // Calculate scroll position based on text position
        final textHeight = MediaQuery.of(context).size.height * 0.6;
        final position = (playerState.currentTextPosition / book.totalLength) * textHeight;
        
        scrollController.animateTo(
          position,
          duration: Duration(milliseconds: (500 * settings.scrollSpeed).round()),
          curve: Curves.easeInOut,
        );
      }
      return null;
    }, [playerState.currentTextPosition]);
    
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: settings.themeMode == ThemeMode.dark
          ? Colors.black
          : Theme.of(context).colorScheme.surface,
      appBar: isControlsVisible.value
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.author != null)
                    Text(
                      book.author!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              actions: [
                // Bookmark button
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () async {
                    await playerViewModel.addBookmark();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ブックマークを追加しました'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                // Chapter list
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: () {
                    scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
                // Settings menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    switch (value) {
                      case 'auto_scroll':
                        playerViewModel.toggleAutoScroll();
                        break;
                      case 'highlight':
                        playerViewModel.toggleHighlightText();
                        break;
                      case 'regenerate':
                        await playerViewModel.regenerateCurrentSegment();
                        break;
                      case 'bookmarks':
                        _showBookmarks(context, playerViewModel);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'auto_scroll',
                      child: Row(
                        children: [
                          Icon(
                            playerState.autoScroll
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(playerState.autoScroll
                              ? '自動スクロールを停止'
                              : '自動スクロールを開始'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'highlight',
                      child: Row(
                        children: [
                          Icon(
                            playerState.highlightText
                                ? Icons.highlight_off
                                : Icons.highlight,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(playerState.highlightText
                              ? 'ハイライトを停止'
                              : 'ハイライトを開始'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'regenerate',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: 8),
                          Text('現在のセグメントを再生成'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'bookmarks',
                      child: Row(
                        children: [
                          Icon(Icons.bookmarks, size: 20),
                          SizedBox(width: 8),
                          Text('ブックマーク一覧'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              backgroundColor: settings.themeMode == ThemeMode.dark
                  ? Colors.black87
                  : null,
            )
          : null,
      body: GestureDetector(
        onTap: () {
          isControlsVisible.value = !isControlsVisible.value;
        },
        child: Stack(
          children: [
            // Text content
            TextDisplay(
              text: book.content,
              currentPosition: playerState.currentTextPosition,
              fontSize: settings.fontSize,
              highlightEnabled: playerState.highlightText,
              scrollController: scrollController,
              onTextTap: (position) {
                playerViewModel.seekToPosition(position);
              },
            ),
            
            // Loading overlay
            if (playerState.isGeneratingAudio)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '音声を生成中... ${(playerState.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Error message
            if (playerState.error != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playerState.error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          // Clear error (would need to add this to ViewModel)
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isControlsVisible.value ? null : 0,
        child: isControlsVisible.value
            ? PlaybackControls(
                isPlaying: playerState.isPlaying,
                isLoading: playerState.isLoading,
                position: playbackPosition.value ?? Duration.zero,
                duration: playerState.totalDuration,
                speed: ref.watch(playbackSpeedProvider),
                volume: ref.watch(playbackVolumeProvider),
                currentSegment: playerState.currentSegmentIndex,
                totalSegments: playerState.segments.length,
                onPlayPause: () => playerViewModel.togglePlayPause(),
                onSeekForward: () => playerViewModel.seekForward(),
                onSeekBackward: () => playerViewModel.seekBackward(),
                onSeek: (position) {
                  final textPosition = (position.inMilliseconds /
                          playerState.totalDuration.inMilliseconds *
                          book.totalLength)
                      .round();
                  playerViewModel.seekToPosition(textPosition);
                },
                onSpeedChange: (speed) => playerViewModel.setSpeed(speed),
                onVolumeChange: (volume) => playerViewModel.setVolume(volume),
                onSegmentJump: (index) => playerViewModel.jumpToSegment(index),
              )
            : null,
      ),
      endDrawer: ChapterDrawer(
        segments: playerState.segments,
        currentSegmentIndex: playerState.currentSegmentIndex,
        onSegmentTap: (index) {
          playerViewModel.jumpToSegment(index);
          Navigator.pop(context);
        },
      ),
    );
  }
  
  void _showBookmarks(BuildContext context, PlayerViewModel viewModel) async {
    final bookmarks = await viewModel.getBookmarks();
    
    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ブックマーク',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (bookmarks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('ブックマークがありません'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final position = bookmarks[index];
                    final percentage = (position / book.totalLength * 100)
                        .toStringAsFixed(1);
                    
                    return ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text('位置: $percentage%'),
                      subtitle: Text('文字位置: $position'),
                      onTap: () {
                        viewModel.seekToPosition(position);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await viewModel.removeBookmark(position);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _showBookmarks(context, viewModel);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}