import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:io';
// import 'dart:async';
import 'package:file_picker/file_picker.dart';

// For file handling

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

enum PipelineStage {
  // Take input file name, TODO: Audio recording input
  takeInput, 

  // When user selects an input audio file
  displayInputFileName, 

   // When user asks to process the input audio file
  displayInputProcessing,

  // When transcriber service sends a response
  handleResponseFromTranscriber, 

  // When user asks to send the transcript to Meeting Intelligence
  sendToMeetingIntelligence 
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var pipelineStage = PipelineStage.takeInput;
  var audioFilePath = ""; 

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  void setAudioFilePath(String path) {
    audioFilePath = path;
    notifyListeners();
  }

  void setPipelineStage(stage) {
    // TODO: Add code to check here that the state transitions
    // are valid and if not then add debugging logs here.
    pipelineStage = stage;
    notifyListeners();
  }

  Future<String> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      return file.path;
    } else {
      // User canceled the picker
      return '';
    }
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    var titleText = "spotscriber";

    return Scaffold(
      body: Center(
        child: Column(
          children: [
            TitleBar(titleText: titleText),
            SizedBox(height: 50),
            Text(appState.current.asLowerCase),

            // First Stage
            Visibility(
              visible: appState.pipelineStage == PipelineStage.takeInput,
              child: InputBar(appState: appState),
            ),

            // Second Stage
            Visibility(
              visible: appState.pipelineStage == PipelineStage.displayInputFileName,
              child: InputFileNameViewer(appState: appState),
            ),
          ],
        ),
      ),
    );
  }
}

class InputFileNameViewer extends StatelessWidget {
  const InputFileNameViewer({
    super.key,
    required this.appState,
  });

  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Chosen Audio File"),
            SizedBox(width: 20),
            Text(appState.audioFilePath),
          ],
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                print("Process button pressed");
              },
              child: Text("Process")
            ),

            ElevatedButton(
              onPressed: () {
                print("Cancel button pressed");
              },
              child: Text("Cancel")
            )
          ],
        ), 
      ],
    );
  }
}

class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.appState,
  });

  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    return Row(
      // To center stuff out
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
    
        // Get some gap between the row widgets
        SizedBox(width: 20),
    
        Text("I am batman")
      ],
    );
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.titleText
  });

  final String titleText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );


    return Card(
      // color: theme.colorScheme.primary,
      child: Row(
        // Center the row contents
        mainAxisSize: MainAxisSize.min,
        children: [
         ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 100.0, maxWidth: 100.0),
          child: Image.asset("ek_assets/images/highspot_logo.png"),
         ),
          
          SizedBox(width: 20),
          Text(titleText, style: style)
        ],
      ),
    );
  }
}