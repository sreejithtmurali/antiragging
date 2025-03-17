import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

class BackgroundVideoService {
  // Singleton instance
  static final BackgroundVideoService _instance = BackgroundVideoService._internal();
  factory BackgroundVideoService() => _instance;
  BackgroundVideoService._internal();

  // Camera controller and variables
  CameraController? _cameraController;
  bool _isRecording = false;
  bool _isInitialized = false;
  Timer? _maxDurationTimer;
  String? _currentVideoPath;

  // Event controller for status updates
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // Configuration
  int _maxRecordingDurationSeconds = 300; // 5 minutes default
  ResolutionPreset _resolutionPreset = ResolutionPreset.medium;
  int _frameRate = 30;

  // Getters
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
  String? get currentVideoPath => _currentVideoPath;

  /// Initialize the camera service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check and request permissions
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      final storageStatus = await Permission.storage.request();

      if (cameraStatus.isDenied || microphoneStatus.isDenied || storageStatus.isDenied) {
        _statusController.add("Permission denied for camera, microphone, or storage");
        return false;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _statusController.add("No cameras available on this device");
        return false;
      }

      // Select rear camera by default
      final CameraDescription selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Initialize the controller
      _cameraController = CameraController(
        selectedCamera,
        _resolutionPreset,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Configure frame rate if possible
      await _configureFrameRate();

      _isInitialized = true;
      _statusController.add("Camera initialized");
      return true;
    } catch (e) {
      _statusController.add("Error initializing camera: $e");
      return false;
    }
  }

  /// Configure camera frame rate if supported
  Future<void> _configureFrameRate() async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;

      // Get available frame rate ranges
      List<int>? fps = await _cameraController!.getExposureOffsetStepSize() as List<int>?;
      if (fps != null && fps.contains(_frameRate)) {
        await _cameraController!.setExposureMode(ExposureMode.auto);
      }
    } catch (e) {
      // Frame rate configuration is optional, so we just log the error
      print("Error configuring frame rate: $e");
    }
  }

  /// Start recording video in the background
  Future<bool> startRecording() async {
    if (_isRecording) return true;
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Create a unique file name
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/${const Uuid().v4()}.mp4';

      // Start recording
      await _cameraController!.startVideoRecording();
      _isRecording = true;
      _currentVideoPath = filePath;
      _statusController.add("Recording started");

      // Start timer for max duration
      _maxDurationTimer = Timer(Duration(seconds: _maxRecordingDurationSeconds), () {
        stopRecording();
        _statusController.add("Recording stopped (max duration reached)");
      });

      return true;
    } catch (e) {
      _statusController.add("Error starting recording: $e");
      return false;
    }
  }

  /// Stop the current recording
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      // Cancel max duration timer if active
      _maxDurationTimer?.cancel();
      _maxDurationTimer = null;

      // Stop recording
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      _isRecording = false;

      // Move file to a more permanent location if needed
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String newPath = '${directory.path}/$fileName';

      final File sourceFile = File(videoFile.path);
      final File newFile = await sourceFile.copy(newPath);
      await sourceFile.delete();

      _currentVideoPath = newPath;
      _statusController.add("Recording stopped, saved to: $newPath");

      return newPath;
    } catch (e) {
      _statusController.add("Error stopping recording: $e");
      return null;
    }
  }

  /// Pause recording (if supported by device)
  Future<bool> pauseRecording() async {
    if (!_isRecording) return false;

    try {
      await _cameraController!.pauseVideoRecording();
      _statusController.add("Recording paused");
      return true;
    } catch (e) {
      _statusController.add("Error pausing recording: $e");
      return false;
    }
  }

  /// Resume recording (if supported by device)
  Future<bool> resumeRecording() async {
    if (!_isRecording) return false;

    try {
      await _cameraController!.resumeVideoRecording();
      _statusController.add("Recording resumed");
      return true;
    } catch (e) {
      _statusController.add("Error resuming recording: $e");
      return false;
    }
  }

  /// Set maximum recording duration in seconds
  void setMaxRecordingDuration(int seconds) {
    _maxRecordingDurationSeconds = seconds;
  }

  /// Set video quality
  void setResolution(ResolutionPreset preset) {
    if (_isInitialized) {
      _statusController.add("Cannot change resolution while camera is initialized");
      return;
    }
    _resolutionPreset = preset;
  }

  /// Set frame rate
  void setFrameRate(int frameRate) {
    if (_isInitialized) {
      _statusController.add("Cannot change frame rate while camera is initialized");
      return;
    }
    _frameRate = frameRate;
  }

  /// Switch between front and back camera
  Future<bool> switchCamera() async {
    if (_isRecording) {
      _statusController.add("Cannot switch camera while recording");
      return false;
    }

    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.length < 2) {
        _statusController.add("Device doesn't have multiple cameras");
        return false;
      }

      // Determine which camera to switch to
      final CameraDescription currentCamera = _cameraController!.description;
      final CameraLensDirection newDirection = currentCamera.lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final CameraDescription newCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == newDirection,
        orElse: () => cameras.first,
      );

      // Dispose current controller
      await _cameraController!.dispose();

      // Create new controller with the other camera
      _cameraController = CameraController(
        newCamera,
        _resolutionPreset,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _configureFrameRate();

      _statusController.add("Camera switched to ${newDirection == CameraLensDirection.back ? 'rear' : 'front'}");
      return true;
    } catch (e) {
      _statusController.add("Error switching camera: $e");
      return false;
    }
  }

  /// Release all resources
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;

    await _statusController.close();
  }

  /// Get a list of recorded videos
  Future<List<String>> getRecordedVideos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      return entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.mp4'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      _statusController.add("Error getting recorded videos: $e");
      return [];
    }
  }

  /// Delete a recorded video
  Future<bool> deleteVideo(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _statusController.add("Video deleted: $path");
        return true;
      }
      return false;
    } catch (e) {
      _statusController.add("Error deleting video: $e");
      return false;
    }
  }
}