import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

class TextReaderModel extends ChangeNotifier {
  FlutterTts flutterTts = FlutterTts();
  
  String _fileContent = '';
  String _fileName = '';
  TtsState _ttsState = TtsState.stopped;
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;
  
  String get fileContent => _fileContent;
  String get fileName => _fileName;
  TtsState get ttsState => _ttsState;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;
  
  TextReaderModel() {
    _initTts();
  }
  
  Future<void> _initTts() async {
    await flutterTts.setLanguage("ja-JP");
    await flutterTts.setSpeechRate(_speechRate);
    await flutterTts.setVolume(_volume);
    await flutterTts.setPitch(_pitch);
    
    flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      notifyListeners();
    });
    
    flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      notifyListeners();
    });
    
    flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      notifyListeners();
    });
  }
  
  void setFileContent(String content, String fileName) {
    _fileContent = content;
    _fileName = fileName;
    notifyListeners();
  }
  
  Future<void> speak() async {
    if (_fileContent.isNotEmpty) {
      await flutterTts.speak(_fileContent);
    }
  }
  
  Future<void> stop() async {
    await flutterTts.stop();
    _ttsState = TtsState.stopped;
    notifyListeners();
  }
  
  Future<void> pause() async {
    await flutterTts.pause();
    _ttsState = TtsState.paused;
    notifyListeners();
  }
  
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await flutterTts.setSpeechRate(rate);
    notifyListeners();
  }
  
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await flutterTts.setVolume(volume);
    notifyListeners();
  }
  
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await flutterTts.setPitch(pitch);
    notifyListeners();
  }
  
  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }
}