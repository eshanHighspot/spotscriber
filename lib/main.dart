import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Main function to start the app
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
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 4, 11, 224)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

// Pipeline stages for handling different UI states
enum PipelineStage {
  takeInput, // File selection stage
  displayInputFileName, // Show selected file name
  uploading, // Show loading indicator
  handleResponseFromTranscriber, // Show transcript after API response
}

class MyAppState extends ChangeNotifier {
  var pipelineStage = PipelineStage.takeInput;
  var audioFilePath = ""; 
  var transcript = ""; // Store the transcript from the API
  
  // Store the dialogues from the transcript in a list format
  List<String> transcriptDialougeList = [];

  bool isLoading = false; // Track loading state
  var scrollController = ScrollController();

  void setAudioFilePath(String path) {
    audioFilePath = path;
    notifyListeners();
  }

  void setPipelineStage(PipelineStage stage) {
    pipelineStage = stage;
    notifyListeners();
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String filePath = result.files.single.path!;
      setAudioFilePath(filePath);
      setPipelineStage(PipelineStage.displayInputFileName);
    }
  }

  List<String> processTranscriptForPrettyView(String transcriptJsonString) {
    Map<String, dynamic> transcriptJson = jsonDecode(transcriptJsonString);
    List<dynamic> results = transcriptJson["results"];

    List<String> dialogueList = [];
    
    results.forEach((entry) {
      var prettyDialogueBuffer = StringBuffer();
      prettyDialogueBuffer.writeln(entry["speaker"] + " [" + entry["time"] + "]: ");
      prettyDialogueBuffer.writeln(entry["content"]);

      dialogueList.add(prettyDialogueBuffer.toString());
    });

    // TODO: Add this and check if vertical scrolling works
    // for (int i = 0; i < 50; i++) {
    //    dialogueList.add("I am batman");
    // }

    return dialogueList;
  }

  Future<void> uploadFile() async {
    if (audioFilePath.isEmpty) {
      print("No file selected.");
      return;
    }

    //TODO: var vaibhavUri = "http://172.16.4.224:8000/upload-audio/";
    var vaibhavUri = "http://0.0.0.0:8000/upload-audio/";
    var uri = Uri.parse(vaibhavUri); // Replace with actual API

    var request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", audioFilePath));
    request.fields["user_id"] = "12345";
    request.fields["meeting_id"] = "meeting_001_part1";

    // Show loading indicator
    isLoading = true;
    notifyListeners();

    try {
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        transcript = responseBody;
        print("File uploaded successfully! Transcript: $responseBody");
        
        // Prettify the transcript and get it in form of a dialogue list
        transcriptDialougeList = processTranscriptForPrettyView(transcript);

        setPipelineStage(PipelineStage.handleResponseFromTranscriber);
      } else {
        transcript = "Error: Failed to fetch transcript.";
        print("File upload failed: ${response.statusCode}");
      }
    } catch (e) {
      transcript = "Error: $e";
      print("Error uploading file: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

// UI
class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(title: Text("SpotScriber")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TitleBar(titleText: "SpotScriber"),
            SizedBox(height: 20),

            // File selection UI
            if (appState.pipelineStage == PipelineStage.takeInput) InputBar(appState: appState),

            // Show file name after selection
            if (appState.pipelineStage == PipelineStage.displayInputFileName) 
              InputFileNameViewer(appState: appState),

            // Show loading indicator while uploading
            if (appState.isLoading) CircularProgressIndicator(),

            // Show transcript after response
            if (appState.pipelineStage == PipelineStage.handleResponseFromTranscriber)
              TranscriptViewer(appState: appState, transcriptDialogueList: appState.transcriptDialougeList),
          ],
        ),
      ),
    );
  }
}

// Component to show the transcript
class TranscriptViewer extends StatelessWidget {
  final MyAppState appState;
  final List<String> transcriptDialogueList;

  TranscriptViewer({super.key, required this.appState, required this.transcriptDialogueList});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Transcript:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        SizedBox(
          height: screenHeight / 2.5,
          child: ListView.builder(
            itemCount: transcriptDialogueList.length,
            itemBuilder: (context, index) {
              return Center(child: Text(transcriptDialogueList[index]));
            },
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            appState.setPipelineStage(PipelineStage.takeInput);
          },

          child: Text('Go Back'),
        ),
      ],
    );
  }
}

// Component to show file selection UI
class InputBar extends StatelessWidget {
  final MyAppState appState;

  const InputBar({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () async {
            await appState.pickFile();
          },
          child: Text('Choose File'),
        ),
      ],
    );
  }
}

// Component to display selected file name and process button
class InputFileNameViewer extends StatelessWidget {
  final MyAppState appState;

  const InputFileNameViewer({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Chosen File: "),
            SizedBox(width: 10),
            Text(appState.audioFilePath, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                await appState.uploadFile();
              },
              child: Text("Process & Submit"),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                appState.setPipelineStage(PipelineStage.takeInput);
                appState.setAudioFilePath("");
              },
              child: Text("Cancel"),
            ),
          ],
        ),
      ],
    );
  }
}

// Component for Title Bar
class TitleBar extends StatelessWidget {
  final String titleText;

  const TitleBar({super.key, required this.titleText});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 40, color: Colors.blue),
            SizedBox(width: 10),
            Text(titleText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
