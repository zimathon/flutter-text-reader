import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_config.freezed.dart';
part 'speech_config.g.dart';

/// Configuration for speech synthesis
@freezed
class SpeechConfig with _$SpeechConfig {
  const factory SpeechConfig({
    String? voice,
    @Default(1.0) double speed,
    @Default(1.0) double pitch,
    @Default('ja-JP') String language,
    @Default(0.0) double volumeGainDb,
  }) = _SpeechConfig;

  factory SpeechConfig.fromJson(Map<String, dynamic> json) =>
      _$SpeechConfigFromJson(json);

  /// Default Japanese configuration
  static const japanese = SpeechConfig(
    voice: 'ja-JP-Standard-A',
    language: 'ja-JP',
  );

  /// Default English configuration
  static const english = SpeechConfig(
    voice: 'en-US-Standard-C',
    language: 'en-US',
  );
}

/// Available voice types
enum VoiceType {
  jaJpStandardA('ja-JP-Standard-A', 'Japanese Female A'),
  jaJpStandardB('ja-JP-Standard-B', 'Japanese Female B'),
  jaJpStandardC('ja-JP-Standard-C', 'Japanese Male C'),
  jaJpStandardD('ja-JP-Standard-D', 'Japanese Male D'),
  jaJpWavenetA('ja-JP-Wavenet-A', 'Japanese Female A (High Quality)'),
  jaJpWavenetB('ja-JP-Wavenet-B', 'Japanese Female B (High Quality)'),
  jaJpWavenetC('ja-JP-Wavenet-C', 'Japanese Male C (High Quality)'),
  jaJpWavenetD('ja-JP-Wavenet-D', 'Japanese Male D (High Quality)'),
  enUsStandardA('en-US-Standard-A', 'English Male A'),
  enUsStandardB('en-US-Standard-B', 'English Male B'),
  enUsStandardC('en-US-Standard-C', 'English Female C'),
  enUsStandardD('en-US-Standard-D', 'English Male D');

  const VoiceType(this.id, this.displayName);
  final String id;
  final String displayName;

  bool get isJapanese => id.startsWith('ja-JP');
  bool get isEnglish => id.startsWith('en-US');
  bool get isHighQuality => id.contains('Wavenet');
}