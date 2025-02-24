import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';


// Define pipeline stages for UI state management
enum PipelineStage {
  takeInput,
  displayInputFileName,
  displayInputProcessing,
  handleResponseFromTranscriber,
}

// Application state management using ChangeNotifier
class MyAppState extends ChangeNotifier {
  var pipelineStage = PipelineStage.takeInput;
  String audioFilePath = "";
  List<Map<String, dynamic>> transcriptionResults = [];

  void setPipelineStage(PipelineStage stage) {
    pipelineStage = stage;
    notifyListeners();
  }

  void setAudioFilePath(String path) {
    audioFilePath = path;
    notifyListeners();
  }

  void setTranscriptionResults(List<Map<String, dynamic>> results) {
    transcriptionResults = results;
    notifyListeners();
  }

  Future<String?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    }
    return null;
  }

  Future<void> processAudioLocally() async {
    if (audioFilePath.isEmpty) {
      return;
    }

    setPipelineStage(PipelineStage.displayInputProcessing);

    // Call Python script for transcription & diarization
    final process = await Process.run(
  'python3',
  ['android/app/src/main/python/transcription.py', '"$audioFilePath"'], // Add quotes
);


    if (process.exitCode == 0) {
      try {
        var output = jsonDecode(process.stdout);
        if (output.containsKey("results")) {
          setTranscriptionResults(output["results"]);
        }
      } catch (e) {
        print("Error parsing transcription output: $e");
      }
    } else {
      print("Error in processing audio: ${process.stderr}");
    }

    setPipelineStage(PipelineStage.handleResponseFromTranscriber);
  }
}

// Main entry point of the app
void main() {
  runApp(MyApp());
}

// Root widget of the app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Diarization App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage(),
      ),
    );
  }
}

// HomePage which handles UI state changes based on pipeline stage
class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();


    return Scaffold(
      appBar: AppBar(title: Text("Audio Diarization")),
      body: Column(
        children: [
          Visibility(
            visible: appState.pipelineStage == PipelineStage.takeInput,
            child: InputBar(appState: appState),
          ),
          Visibility(
            visible: appState.pipelineStage == PipelineStage.displayInputFileName,
            child: InputFileNameViewer(appState: appState),
          ),
          Visibility(
            visible: appState.pipelineStage == PipelineStage.displayInputProcessing,
            child: Center(child: CircularProgressIndicator()),
          ),
          Visibility(
            visible: appState.pipelineStage == PipelineStage.handleResponseFromTranscriber,
            child: TranscriptionResults(appState: appState),
          ),
        ],
      ),
    );
  }
}

// Widget for selecting an audio file
class InputBar extends StatelessWidget {
  final MyAppState appState;
  InputBar({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            var filePath = await appState.pickFile();
            if (filePath != null) {
              appState.setAudioFilePath(filePath);
              appState.setPipelineStage(PipelineStage.displayInputFileName);
            }
          },
          child: Text("Pick Audio File"),
        ),
      ],
    );
  }
}

// Widget for displaying selected file name
class InputFileNameViewer extends StatelessWidget {
  final MyAppState appState;
  InputFileNameViewer({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Selected File: ${appState.audioFilePath}"),
        ElevatedButton(
          onPressed: () {
            appState.processAudioLocally();
          },
          child: Text("Process Audio"),
        ),
      ],
    );
  }
}

// Widget for displaying transcription & speaker diarization results
class TranscriptionResults extends StatelessWidget {
  final MyAppState appState;
  TranscriptionResults({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: appState.transcriptionResults.map((result) {
        return ListTile(
          title: Text(result["text"]),
          subtitle: Text(result["speaker"]),
        );
      }).toList(),
    );
  }
}
