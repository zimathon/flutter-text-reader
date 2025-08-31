import 'package:flutter/material.dart';
import 'package:text_reader_app/models/audio_segment.dart';

class ChapterDrawer extends StatelessWidget {
  final List<AudioSegment> segments;
  final int currentSegmentIndex;
  final ValueChanged<int> onSegmentTap;

  const ChapterDrawer({
    super.key,
    required this.segments,
    required this.currentSegmentIndex,
    required this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.list,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  'チャプター',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${segments.length}個のセグメント',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: segments.length,
              itemBuilder: (context, index) {
                final segment = segments[index];
                final isCurrentSegment = index == currentSegmentIndex;
                final preview = _getSegmentPreview(segment.text);
                
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentSegment
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrentSegment
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isCurrentSegment ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'セグメント ${index + 1}',
                    style: TextStyle(
                      fontWeight: isCurrentSegment ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  selected: isCurrentSegment,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  trailing: isCurrentSegment
                      ? Icon(
                          Icons.play_arrow,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : segment.duration != null
                          ? Text(
                              _formatDuration(segment.duration!),
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : null,
                  onTap: () => onSegmentTap(index),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '現在',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${currentSegmentIndex + 1} / ${segments.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '進捗',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${((currentSegmentIndex + 1) / segments.length * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getSegmentPreview(String text) {
    // Remove extra whitespace and newlines
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Get first 100 characters or less
    if (cleaned.length <= 100) {
      return cleaned;
    }
    
    // Try to break at a sentence boundary
    final truncated = cleaned.substring(0, 100);
    final lastPeriod = truncated.lastIndexOf('。');
    final lastSpace = truncated.lastIndexOf(' ');
    
    if (lastPeriod > 50) {
      return '${cleaned.substring(0, lastPeriod + 1)}...';
    } else if (lastSpace > 50) {
      return '${cleaned.substring(0, lastSpace)}...';
    } else {
      return '${truncated}...';
    }
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}