import 'dart:convert';

class Book {
  final String id;
  final String title;
  final String? author;
  final String content;
  final String filePath;
  final DateTime importedAt;
  final DateTime? lastReadAt;
  final int currentPosition;
  final int totalLength;
  final Map<String, dynamic>? metadata;

  Book({
    required this.id,
    required this.title,
    this.author,
    required this.content,
    required this.filePath,
    required this.importedAt,
    this.lastReadAt,
    this.currentPosition = 0,
    required this.totalLength,
    this.metadata,
  });

  double get readingProgress {
    if (totalLength == 0) return 0.0;
    return (currentPosition / totalLength).clamp(0.0, 1.0);
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? content,
    String? filePath,
    DateTime? importedAt,
    DateTime? lastReadAt,
    int? currentPosition,
    int? totalLength,
    Map<String, dynamic>? metadata,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      currentPosition: currentPosition ?? this.currentPosition,
      totalLength: totalLength ?? this.totalLength,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'content': content,
      'filePath': filePath,
      'importedAt': importedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'currentPosition': currentPosition,
      'totalLength': totalLength,
      'metadata': metadata,
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      content: json['content'] as String,
      filePath: json['filePath'] as String,
      importedAt: DateTime.parse(json['importedAt'] as String),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'] as String)
          : null,
      currentPosition: json['currentPosition'] as int? ?? 0,
      totalLength: json['totalLength'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() => json.encode(toJson());

  factory Book.fromJsonString(String jsonString) =>
      Book.fromJson(json.decode(jsonString) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}