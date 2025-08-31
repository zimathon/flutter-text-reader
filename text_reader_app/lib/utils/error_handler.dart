import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Error types
enum ErrorType {
  network,
  storage,
  audio,
  tts,
  fileAccess,
  permission,
  unknown,
}

class AppError {
  final String message;
  final ErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? actionLabel;
  final VoidCallback? retryAction;

  AppError({
    required this.message,
    required this.type,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
    this.actionLabel,
    this.retryAction,
  }) : timestamp = timestamp ?? DateTime.now();

  String get userFriendlyMessage {
    switch (type) {
      case ErrorType.network:
        return 'ネットワーク接続エラーが発生しました。接続を確認してください。';
      case ErrorType.storage:
        return 'ストレージエラーが発生しました。空き容量を確認してください。';
      case ErrorType.audio:
        return '音声再生エラーが発生しました。';
      case ErrorType.tts:
        return '音声合成エラーが発生しました。';
      case ErrorType.fileAccess:
        return 'ファイルアクセスエラーが発生しました。';
      case ErrorType.permission:
        return '必要な権限が付与されていません。';
      case ErrorType.unknown:
      default:
        return 'エラーが発生しました。しばらくしてから再試行してください。';
    }
  }

  bool get isRetryable {
    switch (type) {
      case ErrorType.network:
      case ErrorType.audio:
      case ErrorType.tts:
        return true;
      case ErrorType.storage:
      case ErrorType.fileAccess:
      case ErrorType.permission:
      case ErrorType.unknown:
        return false;
    }
  }
}

// Error state provider
final errorStateProvider = StateNotifierProvider<ErrorStateNotifier, List<AppError>>((ref) {
  return ErrorStateNotifier();
});

class ErrorStateNotifier extends StateNotifier<List<AppError>> {
  ErrorStateNotifier() : super([]);

  void addError(AppError error) {
    state = [...state, error];
    
    // Auto-remove non-critical errors after 10 seconds
    if (error.type != ErrorType.permission && error.type != ErrorType.storage) {
      Future.delayed(const Duration(seconds: 10), () {
        removeError(error);
      });
    }
  }

  void removeError(AppError error) {
    state = state.where((e) => e != error).toList();
  }

  void clearAll() {
    state = [];
  }
}

// Error handler utility
class ErrorHandler {
  static ErrorType classifyError(dynamic error) {
    if (error is SocketException || 
        error is HttpException ||
        error.toString().contains('Network') ||
        error.toString().contains('Connection')) {
      return ErrorType.network;
    }
    
    if (error is FileSystemException ||
        error.toString().contains('Storage') ||
        error.toString().contains('Disk')) {
      return ErrorType.storage;
    }
    
    if (error.toString().contains('Audio') ||
        error.toString().contains('Player')) {
      return ErrorType.audio;
    }
    
    if (error.toString().contains('TTS') ||
        error.toString().contains('Speech') ||
        error.toString().contains('Voice')) {
      return ErrorType.tts;
    }
    
    if (error is PlatformException && 
        error.code.contains('permission')) {
      return ErrorType.permission;
    }
    
    if (error is FileSystemException ||
        error.toString().contains('File')) {
      return ErrorType.fileAccess;
    }
    
    return ErrorType.unknown;
  }

  static Future<T?> tryWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool Function(dynamic)? shouldRetry,
    void Function(dynamic, int)? onRetry,
  }) async {
    int retryCount = 0;
    dynamic lastError;

    while (retryCount <= maxRetries) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        
        if (retryCount >= maxRetries) {
          break;
        }
        
        if (shouldRetry != null && !shouldRetry(error)) {
          break;
        }
        
        retryCount++;
        
        if (onRetry != null) {
          onRetry(error, retryCount);
        }
        
        await Future.delayed(
          retryDelay * retryCount, // Exponential backoff
        );
      }
    }
    
    throw lastError;
  }

  static void handleError(
    BuildContext context,
    WidgetRef ref,
    dynamic error, {
    StackTrace? stackTrace,
    String? customMessage,
    VoidCallback? retryAction,
  }) {
    final errorType = classifyError(error);
    
    final appError = AppError(
      message: customMessage ?? error.toString(),
      type: errorType,
      originalError: error,
      stackTrace: stackTrace,
      actionLabel: retryAction != null ? '再試行' : null,
      retryAction: retryAction,
    );
    
    ref.read(errorStateProvider.notifier).addError(appError);
    
    // Log error for debugging
    debugPrint('Error: ${appError.message}');
    debugPrint('Type: ${appError.type}');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
    
    // Show snackbar for immediate feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appError.userFriendlyMessage),
          action: retryAction != null
              ? SnackBarAction(
                  label: '再試行',
                  onPressed: retryAction,
                )
              : null,
          duration: Duration(
            seconds: appError.isRetryable ? 5 : 3,
          ),
          backgroundColor: _getErrorColor(errorType),
        ),
      );
    }
  }

  static Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange.shade700;
      case ErrorType.permission:
        return Colors.red.shade700;
      case ErrorType.storage:
        return Colors.red.shade900;
      default:
        return Colors.red.shade600;
    }
  }
}

// Error boundary widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    
    // Catch Flutter errors
    FlutterError.onError = (details) {
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
      });
    };
  }

  void _resetError() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }
      
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'エラーが発生しました',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _resetError,
                    icon: const Icon(Icons.refresh),
                    label: const Text('アプリを再起動'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return widget.child;
  }
}

// Error display widget
class ErrorDisplay extends ConsumerWidget {
  const ErrorDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(errorStateProvider);
    
    if (errors.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 56,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: errors.map((error) => _ErrorCard(
            error: error,
            onDismiss: () {
              ref.read(errorStateProvider.notifier).removeError(error);
            },
          )).toList(),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final AppError error;
  final VoidCallback onDismiss;

  const _ErrorCard({
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          _getErrorIcon(error.type),
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(
          error.userFriendlyMessage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error.retryAction != null)
              TextButton(
                onPressed: () {
                  error.retryAction!();
                  onDismiss();
                },
                child: Text(error.actionLabel ?? '再試行'),
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.storage:
        return Icons.storage_rounded;
      case ErrorType.audio:
        return Icons.volume_off;
      case ErrorType.tts:
        return Icons.record_voice_over;
      case ErrorType.fileAccess:
        return Icons.folder_off;
      case ErrorType.permission:
        return Icons.lock;
      case ErrorType.unknown:
      default:
        return Icons.error_outline;
    }
  }
}