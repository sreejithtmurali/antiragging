import 'dart:async';

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

class _EmergencyRecordingPageState extends State<EmergencyRecordingPage> with SingleTickerProviderStateMixin {
  final BackgroundVideoService _videoService = BackgroundVideoService();
  String _status = "Ready";
  bool _isRecording = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _blinkTimer;
  bool _showPulse = true;
  List<String> _slogans = [
    "Stay safe. Stay protected.",
    "Your safety is our priority.",
    "Record evidence discreetly.",
    "Help is just a tap away.",
    "Security when you need it most."
  ];
  int _currentSloganIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeService();

    // Animation for pulsing effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate through slogans
    Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentSloganIndex = (_currentSloganIndex + 1) % _slogans.length;
      });
    });

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
        // Video successfully saved
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _blinkTimer?.cancel();
        _pulseController.repeat(reverse: true);
      }
    } else {
      final started = await _videoService.startRecording();
      if (started) {
        // Recording started - create blinking effect
        _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          setState(() {
            _showPulse = !_showPulse;
          });
        });
      }
    }

    setState(() {
      _isRecording = _videoService.isRecording;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkTimer?.cancel();
    _videoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Emergency Help",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.withOpacity(0.9),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                return VideoGalleryPage(videoService: _videoService);
              }));
            },
            icon: Icon(Icons.video_library),
            tooltip: 'View Recorded Videos',
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade100,
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with slogan
              Container(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  child: Text(
                    _slogans[_currentSloganIndex],
                    key: ValueKey<int>(_currentSloganIndex),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Status indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: EdgeInsets.symmetric(horizontal: 50),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Colors.green,
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main emergency button with animations
                      _isRecording && !_showPulse
                          ? SizedBox(height: 200) // Hide during blink
                          : AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isRecording ? 1.0 : _pulseAnimation.value,
                            child: InkWell(
                              onTap: _toggleRecording,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording ? Colors.red : Colors.red[100],
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isRecording ? Colors.red : Colors.red.shade300).withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
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
                          );
                        },
                      ),

                      SizedBox(height: 40),

                      // Instruction text
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _isRecording
                                  ? "Recording in progress"
                                  : "Tap the button in case of emergency",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isRecording ? Colors.red : Colors.black87,
                              ),
                            ),

                            if (_isRecording) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                                  SizedBox(width: 8),
                                  Text(
                                    "Tap to stop recording",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_off, color: Colors.grey, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    "Records silently in the background",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      "Your safety is our priority",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, color: Colors.red.shade300, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "Secure · Private · Reliable",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}