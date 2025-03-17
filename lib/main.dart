import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'backgroundrecording.dart';
import 'listingpage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: EmergencyRecordingPage(),
    );
  }
}


class EmergencyRecordingPage extends StatefulWidget {
  const EmergencyRecordingPage({Key? key}) : super(key: key);

  @override
  State<EmergencyRecordingPage> createState() => _EmergencyRecordingPageState();
}

class _EmergencyRecordingPageState extends State<EmergencyRecordingPage> {
  final BackgroundVideoService _videoService = BackgroundVideoService();
  String _status = "Ready";
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeService();

    // Listen for status updates
    _videoService.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });
  }

  Future<void> _initializeService() async {
    // Initialize camera in background
    await _videoService.initialize();

    // Configure video quality (optional)
    _videoService.setResolution(ResolutionPreset.medium);
    _videoService.setMaxRecordingDuration(600); // 10 minutes
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final videoPath = await _videoService.stopRecording();
      if (videoPath != null) {
        // Video successfully saved, you could add code here to:
        // 1. Save metadata (time, location, etc.)
        // 2. Upload to secure server
        // 3. Notify emergency contacts
      }
    } else {
      final started = await _videoService.startRecording();
      if (started) {
        // Recording started successfully
        // Keep the app in the foreground or implement background recording
        // with proper Android/iOS configurations
      }
    }

    setState(() {
      _isRecording = _videoService.isRecording;
    });
  }

  @override
  void dispose() {
    // Make sure to release camera resources
    _videoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Help"),
        backgroundColor: Colors.red,
        actions: [
          IconButton(onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
              return VideoGalleryPage(videoService: _videoService,);
            }));
          }, icon: Icon(Icons.list))
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hidden camera indicator (only for development)
            Text(
              _status,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Main emergency button
            InkWell(
              onTap: _toggleRecording,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.red[100],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.warning_amber_rounded,
                    size: 80,
                    color: _isRecording ? Colors.white : Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Instruction text
            Text(
              _isRecording
                  ? "Recording in progress. Tap to stop."
                  : "Tap the button in case of emergency",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (!_isRecording) ...[
              const SizedBox(height: 20),
              const Text(
                "This will silently record video evidence",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}