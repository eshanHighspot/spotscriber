import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'dart:async';

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
  takeInput, // File or Audio Recorder selection stage
  displayDeveloperSettings, // Show developer settings
  displayHelpTextToSetIpAndPort, // Show help text to set IP and Port
  displayNoPermissionToRecord, // Show message when no permission to record
  displayRecorder, // Show the audio recorder (when Record Audio selected)
  displayInputFileName, // Show selected file name
  uploading, // Show loading indicator
  handleResponseFromTranscriber, // Show transcript after API response
}

class MyAppState extends ChangeNotifier {
  var pipelineStage = PipelineStage.takeInput;

  String ipAddress = "";
  String port = "";

  var ipAddressTextEditingController = TextEditingController();
  var portTextEditingController = TextEditingController();

  var audioFilePath = ""; 
  var transcript = ""; // Store the transcript from the API
  var transcriptFilePath = ""; // The target path to save the transcript to

  // Store the dialogues from the transcript in a list format
  List<Map<String, String>> transcriptDialogueList = [];

  bool isLoading = false; // Track loading state
  AudioRecorder audioRecorder = AudioRecorder();
  bool isRecording = false;

  Duration recordingTimer = Duration(hours: 0, minutes: 0, seconds: 0);

  void setAudioFilePath(String path) {
    audioFilePath = path;
    notifyListeners();
  }

  void setPipelineStage(PipelineStage stage) {
    pipelineStage = stage;
    notifyListeners();
  }

  void setIpAddress(String ip) {
    ipAddress = ip;
    notifyListeners();
  }

  void setPort(String p) {
    port = p;
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

  List<Map<String, String>> processTranscriptForPrettyView(String transcriptJsonString) {
    Map<String, dynamic> transcriptJson = jsonDecode(transcriptJsonString);
    List<dynamic> results = transcriptJson["results"];

    List<Map<String, String>> dialogueList = [];
    
    results.forEach((entry) {
      Map<String, String> m = {};
      m["speaker"] = entry["speaker"];
      m["time"] = entry["time"];
      m["content"] = entry["content"];
      dialogueList.add(m);
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
    var vaibhavUri = "http://" + ipAddress + ":" + port + "/upload-audio/";
    var uri = Uri.parse(vaibhavUri); // Replace with actual API

    print("Sending request $vaibhavUri");

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
        transcriptDialogueList = processTranscriptForPrettyView(transcript);

        // Save the file in pretty format
        final Directory dir = await getTargetTranscriptFileDir();
        final DateTime now = DateTime.now();
        final audioFileNameWithoutExtension = p.basename(audioFilePath).split(".").first;
        final String transcriptFileName = audioFileNameWithoutExtension + "_transcript_" +
                                          now.day.toString() + "_" + now.month.toString() + "_" + now.year.toString() + "_" +
                                          now.hour.toString() + "_" + now.minute.toString() + "_" + now.second.toString() + ".json";
        
        transcriptFilePath = p.join(dir.path, transcriptFileName); 

        File transcriptFile = File(transcriptFilePath);
        await transcriptFile.writeAsString(transcript);

        print("Transcript saved at: $transcriptFilePath");
        print("I am batman");

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

  Future<bool> checkRecordingPermission() async {
    return await audioRecorder.hasPermission();
  }

  void setIsRecording(bool recording) {
    isRecording = recording;
    notifyListeners();
  }

  Future<Directory> getTargetAudioFileDir() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<Directory> getTargetTranscriptFileDir() async {
    // We'll save generated transcript files (in the pretty
    // format here)
    return await getApplicationDocumentsDirectory();
  }

  void updateRecordingTimer() {
    recordingTimer += Duration(seconds: 1);
    notifyListeners();
  }

  void resetRecordingTimer() {
    recordingTimer = Duration(hours: 0, minutes: 0, seconds: 0);
    notifyListeners();
  }

  String getRecordingTimerString() {
    // The format is hh:mm:ss.uuuuuu
    // so we remove the uuuu part and return [hh::mm::ss, uuuuuu]
    // only the first part (hh:mm:ss) after split
    return recordingTimer.toString().split(".").first;
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
            SizedBox(height: 30),

            // File or Audio Recording selection UI
            if (appState.pipelineStage == PipelineStage.takeInput) InputBar(appState: appState),

            if (appState.pipelineStage == PipelineStage.displayDeveloperSettings)
              DeveloperSettingsViewer(appState: appState),

            if (appState.pipelineStage == PipelineStage.displayNoPermissionToRecord)
              NoPermissionToRecordViewer(appState: appState),

            if (appState.pipelineStage == PipelineStage.displayRecorder)
              RecordingViewer(appState: appState, audioRecorder: appState.audioRecorder),

            if(appState.pipelineStage == PipelineStage.displayHelpTextToSetIpAndPort)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text("Please set IP Address and Port in Developer Settings to proceed.")),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      appState.setPipelineStage(PipelineStage.takeInput);
                    },
                    child: Text("Go Back"),
                  ),
                ],
              ),

            // Show file name after selection
            if (appState.pipelineStage == PipelineStage.displayInputFileName) 
              InputFileNameViewer(appState: appState),

            // Show loading indicator while uploading
            if (appState.isLoading) CircularProgressIndicator(),

            // Show transcript after response
            if (appState.pipelineStage == PipelineStage.handleResponseFromTranscriber)
              TranscriptViewer(appState: appState, transcriptDialogueList: appState.transcriptDialogueList),
          ],
        ),
      ),
    );
  }
}

class DeveloperSettingsViewer extends StatelessWidget {
  const DeveloperSettingsViewer({
    super.key,
    required this.appState,
  });

  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: appState.ipAddressTextEditingController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter ip address'
          )
        ),
      ),
    
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: appState.portTextEditingController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter ports'
          )
        ),
      ),
      ElevatedButton(
        onPressed: () {
          appState.setIpAddress(appState.ipAddressTextEditingController.text);
          appState.setPort(appState.portTextEditingController.text);
          appState.setPipelineStage(PipelineStage.takeInput);
        },
    
        child: Text("Set")
      )
    ],
    );
  }
}

class NoPermissionToRecordViewer extends StatelessWidget {
  const NoPermissionToRecordViewer({
    super.key,
    required this.appState,
  });

  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("SpotScriber doesn't have permission to record audio !"),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            appState.setPipelineStage(PipelineStage.takeInput);
          },
    
          child: Text("Go Back")
        )
      ],
    );
  }
}

// Component to show the transcript
class TranscriptViewer extends StatelessWidget {
  final MyAppState appState;
  final List<Map<String, String>> transcriptDialogueList;

  TranscriptViewer({super.key, required this.appState, required this.transcriptDialogueList});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Transcript:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Divider(color: Colors.black),
        SizedBox(height: 10),
        SizedBox(
          height: screenHeight / 3,
          child: ListView.builder(
            itemCount: transcriptDialogueList.length,
            itemBuilder: (context, index) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${transcriptDialogueList[index]["speaker"]} [${transcriptDialogueList[index]["time"]}]: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  Flexible(child: Text("${transcriptDialogueList[index]["content"]}", textAlign: TextAlign.center)),
                  SizedBox(height:10),
                ],
              ));
            },
          ),
        ),
        Divider(color: Colors.black),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            appState.setPipelineStage(PipelineStage.takeInput);
          },

          child: Text('Go Back'),
        ),

        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text("Transcript saved at: ")),
            Flexible(child: Text(appState.transcriptFilePath, style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        )
        ],
    );
  }
}

// Component to show the audio recorder
class RecordingViewer extends StatelessWidget {
  final MyAppState appState;
  final AudioRecorder audioRecorder;

  RecordingViewer({super.key, required this.appState, required this.audioRecorder});

  @override
  Widget build(BuildContext context) {
    return  ElevatedButton.icon(
          icon: appState.isRecording ? Icon(Icons.pause, size: 25, color: Colors.blue) : 
                                       Icon(Icons.play_arrow, size: 25, color: Colors.blue),
          onPressed: () async {
            var isRecording = appState.isRecording;

            final Directory dir = await appState.getTargetAudioFileDir();

            
            if (isRecording) {
              // button pressed when recording was going on so, we
              // should stop now
              await audioRecorder.stop();

              appState.setPipelineStage(PipelineStage.displayInputFileName);
            } else {
              // button pressed when recording was not going on so,
              // now we should start recording
              // Generate the path to store the audio file at
              final DateTime currTime = DateTime.now();
              final String currTimeStr = currTime.day.toString() + "_" + currTime.month.toString() + "_" + currTime.year.toString() + "_" +
                                         currTime.hour.toString() + "_" + currTime.minute.toString() + "_" + currTime.second.toString();
              final String fullFilePath = p.join(dir.path, "spotscriber_recorded_audio_" + currTimeStr + ".wav"); 

              appState.setAudioFilePath(fullFilePath);
              await audioRecorder.start(const RecordConfig(), path: fullFilePath);

              // Start a timer of 1 second duration
              var oneSec = Duration(seconds: 1);
              Timer.periodic(oneSec, (Timer t) {
                if (appState.isRecording) {
                  // Update timer if we're recording
                  appState.updateRecordingTimer();
                } else {
                  // Stop the timer if we've stopped recording
                  t.cancel();
                  appState.resetRecordingTimer();
                }
              });
            }

            appState.setIsRecording(!isRecording);
          },
          label: appState.isRecording ? Text("Stop Recording (" + appState.getRecordingTimerString() + ")") : 
                                        Text('Start Recording'),
        );
  }
}

// Component to show file selection UI
class InputBar extends StatelessWidget {
  final MyAppState appState;

  const InputBar({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.audio_file, size: 25, color: Colors.blue),
              onPressed: () async {
                if (appState.ipAddress.isEmpty || appState.port.isEmpty) {
                  appState.setPipelineStage(PipelineStage.displayHelpTextToSetIpAndPort);
                  return;
                }

                await appState.pickFile();
              },
              label: Text('Choose Audio File'),
            ),
        
            SizedBox(width: 15),
            
            ElevatedButton.icon(
              icon: Icon(Icons.mic, size: 25, color: Colors.blue),
              onPressed: () async {
                if (appState.ipAddress.isEmpty || appState.port.isEmpty) {
                  appState.setPipelineStage(PipelineStage.displayHelpTextToSetIpAndPort);
                  return;
                }

                bool perm = await appState.checkRecordingPermission();
                if (perm) {
                  appState.setPipelineStage(PipelineStage.displayRecorder);
                } else {
                  appState.setPipelineStage(PipelineStage.displayNoPermissionToRecord);
                }
              },
              label: Text('Record Audio'),
            ),
          ],
        ),
        SizedBox(height: 50),

        ElevatedButton.icon(
          icon: Icon(Icons.settings, size: 25, color: Colors.blue),
          onPressed: ()  {
            appState.setPipelineStage(PipelineStage.displayDeveloperSettings);
          },
          label: Text('Developer Settings'),
        )
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Chosen File: "),
            SizedBox(width: 10),
            Flexible(child: Text(appState.audioFilePath, style: TextStyle(fontWeight: FontWeight.bold))),
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
            Icon(Icons.article_sharp, size: 40, color: Colors.blue),
            SizedBox(width: 10),
            Text(titleText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
