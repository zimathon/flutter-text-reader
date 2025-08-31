import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class PlaybackControls extends HookWidget {
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  final int currentSegment;
  final int totalSegments;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekForward;
  final VoidCallback onSeekBackward;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onSpeedChange;
  final ValueChanged<double> onVolumeChange;
  final ValueChanged<int> onSegmentJump;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.speed,
    required this.volume,
    required this.currentSegment,
    required this.totalSegments,
    required this.onPlayPause,
    required this.onSeekForward,
    required this.onSeekBackward,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onVolumeChange,
    required this.onSegmentJump,
  });

  @override
  Widget build(BuildContext context) {
    final showVolumeSlider = useState(false);
    final showSpeedOptions = useState(false);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Time labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'セグメント ${currentSegment + 1} / $totalSegments',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Progress slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: duration.inSeconds > 0
                          ? (position.inSeconds / duration.inSeconds)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: duration.inSeconds > 0
                          ? (value) {
                              final newPosition = Duration(
                                seconds: (duration.inSeconds * value).round(),
                              );
                              onSeek(newPosition);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Volume button
                  IconButton(
                    icon: Icon(
                      volume == 0
                          ? Icons.volume_off
                          : volume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                    ),
                    onPressed: () {
                      showVolumeSlider.value = !showVolumeSlider.value;
                      showSpeedOptions.value = false;
                    },
                  ),
                  
                  // Skip backward
                  IconButton(
                    icon: const Icon(Icons.replay_30),
                    iconSize: 32,
                    onPressed: onSeekBackward,
                  ),
                  
                  // Play/Pause button
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: IconButton(
                      icon: isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      iconSize: 40,
                      padding: const EdgeInsets.all(12),
                      onPressed: isLoading ? null : onPlayPause,
                    ),
                  ),
                  
                  // Skip forward
                  IconButton(
                    icon: const Icon(Icons.forward_30),
                    iconSize: 32,
                    onPressed: onSeekForward,
                  ),
                  
                  // Speed button
                  TextButton(
                    onPressed: () {
                      showSpeedOptions.value = !showSpeedOptions.value;
                      showVolumeSlider.value = false;
                    },
                    child: Text(
                      '${speed.toStringAsFixed(1)}x',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            
            // Volume slider (shown when volume button is pressed)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: showVolumeSlider.value ? 56 : 0,
              child: showVolumeSlider.value
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down, size: 20),
                          Expanded(
                            child: Slider(
                              value: volume,
                              onChanged: onVolumeChange,
                            ),
                          ),
                          const Icon(Icons.volume_up, size: 20),
                        ],
                      ),
                    )
                  : null,
            ),
            
            // Speed options (shown when speed button is pressed)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: showSpeedOptions.value ? 56 : 0,
              child: showSpeedOptions.value
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (final speedOption in [
                            0.5,
                            0.75,
                            1.0,
                            1.25,
                            1.5,
                            1.75,
                            2.0,
                            2.5,
                            3.0
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('${speedOption.toStringAsFixed(speedOption == 1.0 ? 0 : 2)}x'),
                                selected: (speed - speedOption).abs() < 0.01,
                                onSelected: (selected) {
                                  if (selected) {
                                    onSpeedChange(speedOption);
                                    showSpeedOptions.value = false;
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    )
                  : null,
            ),
            
            // Bottom controls
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 8,
              ),
              child: Row(
                children: [
                  // Previous segment
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: currentSegment > 0
                        ? () => onSegmentJump(currentSegment - 1)
                        : null,
                  ),
                  
                  // Segment indicator
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          totalSegments.clamp(0, 10),
                          (index) {
                            final segmentIndex = _getDisplaySegmentIndex(
                              index,
                              currentSegment,
                              totalSegments,
                            );
                            
                            if (segmentIndex == -1) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  '...',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }
                            
                            return GestureDetector(
                              onTap: () => onSegmentJump(segmentIndex),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: segmentIndex == currentSegment ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: segmentIndex == currentSegment
                                      ? Theme.of(context).colorScheme.primary
                                      : segmentIndex < currentSegment
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Next segment
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: currentSegment < totalSegments - 1
                        ? () => onSegmentJump(currentSegment + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  int _getDisplaySegmentIndex(
    int displayIndex,
    int currentSegment,
    int totalSegments,
  ) {
    if (totalSegments <= 10) {
      return displayIndex;
    }
    
    // Show first 3, current-1, current, current+1, and last 3
    if (displayIndex < 3) {
      return displayIndex;
    } else if (displayIndex == 3 && currentSegment > 4) {
      return -1; // Show ellipsis
    } else if (displayIndex >= 7) {
      return totalSegments - (10 - displayIndex);
    } else if (displayIndex == 6 && currentSegment < totalSegments - 5) {
      return -1; // Show ellipsis
    } else {
      // Show segments around current
      return currentSegment - 1 + (displayIndex - 4);
    }
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}