import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/text_reader_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('テキスト読み上げアプリ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<TextReaderModel>(
        builder: (context, model, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.upload_file, size: 48),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _pickFile(context, model),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('テキストファイルを選択'),
                        ),
                        if (model.fileName.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'ファイル: ${model.fileName}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (model.fileContent.isNotEmpty) ...[
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'テキスト内容',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  model.fileContent,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: model.ttsState == TtsState.playing
                                    ? () => model.pause()
                                    : () => model.speak(),
                                icon: Icon(
                                  model.ttsState == TtsState.playing
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  size: 48,
                                ),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              IconButton(
                                onPressed: () => model.stop(),
                                icon: const Icon(Icons.stop_circle, size: 48),
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              Text('速度: ${model.speechRate.toStringAsFixed(1)}'),
                              Slider(
                                value: model.speechRate,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                label: model.speechRate.toStringAsFixed(1),
                                onChanged: (value) => model.setSpeechRate(value),
                              ),
                              Text('音量: ${model.volume.toStringAsFixed(1)}'),
                              Slider(
                                value: model.volume,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                label: model.volume.toStringAsFixed(1),
                                onChanged: (value) => model.setVolume(value),
                              ),
                              Text('ピッチ: ${model.pitch.toStringAsFixed(1)}'),
                              Slider(
                                value: model.pitch,
                                min: 0.5,
                                max: 2.0,
                                divisions: 15,
                                label: model.pitch.toStringAsFixed(1),
                                onChanged: (value) => model.setPitch(value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, TextReaderModel model) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      String? filePath = result.files.single.path;
      if (filePath != null) {
        File file = File(filePath);
        String content = await file.readAsString();
        String fileName = result.files.single.name;
        model.setFileContent(content, fileName);
      }
    }
  }
}