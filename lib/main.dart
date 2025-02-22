import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:chaquopy/chaquopy.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'SpotScriber App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 4, 11, 224)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var pipelineStage = PipelineStage.takeInput;
  String audioFilePath = "";
  List<dynamic> transcriptionResults = [];

  void setAudioFilePath(String path) {
    audioFilePath = path;
    notifyListeners();
  }

  void setPipelineStage(PipelineStage stage) {
    pipelineStage = stage;
    notifyListeners();
  }

  Future<String> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      return result.files.single.path!;
    }
    return '';
  }

  Future<void> processAudioLocally() async {
    if (audioFilePath.isEmpty) return;

    setPipelineStage(PipelineStage.displayInputProcessing);
    notifyListeners();

    try {
      // Call Python transcription script using Chaquopy
      final pyResult = await Chaquopy.runPythonCode("""
import transcription
result = transcription.process_audio('${audioFilePath}')
print(result)
""");

      transcriptionResults = _parsePythonOutput(pyResult['stdout']);
      setPipelineStage(PipelineStage.handleResponseFromTranscriber);
    } catch (e) {
      print("Processing failed: $e");
    }
  }

  List<dynamic> _parsePythonOutput(String output) {
    try {
      return output.contains("results") ? output.split("results: ")[1].trim() : [];
    } catch (e) {
      print("Parsing error: $e");
      return [];
    }
  }
}

enum PipelineStage {
  takeInput,
  displayInputFileName,
  displayInputProcessing,
  handleResponseFromTranscriber,
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 50),
            Text("SpotScriber App"),
            Visibility(
              visible: appState.pipelineStage == PipelineStage.takeInput,
              child: InputBar(appState: appState),
            ),
            Visibility(
              visible: appState.pipelineStage == PipelineStage.displayInputFileName,
              child: InputFileNameViewer(appState: appState),
            ),
            Visibility(
              visible: appState.pipelineStage == PipelineStage.handleResponseFromTranscriber,
              child: TranscriptionResults(appState: appState),
            ),
          ],
        ),
      ),
    );
  }
}

class InputBar extends StatelessWidget {
  final MyAppState appState;
  InputBar({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () async {
            var filePath = await appState.pickFile();
            if (filePath.isNotEmpty) {
              appState.setAudioFilePath(filePath);
              appState.setPipelineStage(PipelineStage.displayInputFileName);
            }
          },
          child: Text('Choose File'),
        ),
      ],
    );
  }
}

class InputFileNameViewer extends StatelessWidget {
  final MyAppState appState;
  InputFileNameViewer({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Selected File: ${appState.audioFilePath}"),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                appState.processAudioLocally();
              },
              child: Text("Process"),
            ),
          ],
        ),
      ],
    );
  }
}

class TranscriptionResults extends StatelessWidget {
  final MyAppState appState;
  TranscriptionResults({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: appState.transcriptionResults.map((result) {
        return Card(
          child: ListTile(
            title: Text("${result['speaker']}: ${result['content']}"),
            subtitle: Text("Time: ${result['time']}"),
          ),
        );
      }).toList(),
    );
  }
}
