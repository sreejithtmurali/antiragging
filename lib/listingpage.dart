import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

import 'backgroundrecording.dart';

class VideoGalleryPage extends StatefulWidget {
  final BackgroundVideoService videoService;

  const VideoGalleryPage({Key? key, required this.videoService}) : super(key: key);

  @override
  State<VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends State<VideoGalleryPage> {
  List<String> _videoPaths = [];
  bool _isLoading = true;
  String? _selectedVideo;
  VideoPlayerController? _videoPlayerController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    // Listen for new recordings
    widget.videoService.statusStream.listen((status) {
      if (status.contains("Recording stopped")) {
        _loadVideos();
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final videos = await widget.videoService.getRecordedVideos();
      setState(() {
        // Sort videos by filename (most recent first)
        _videoPaths = videos..sort((a, b) => b.compareTo(a));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading videos: $e')),
      );
    }
  }

  String _formatVideoName(String videoPath) {
    final filename = path.basename(videoPath);
    // Try to extract timestamp from filename
    try {
      final timestamp = int.parse(filename.split('.').first);
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('MMM dd, yyyy - HH:mm:ss').format(date);
    } catch (e) {
      return filename;
    }
  }

  Future<void> _deleteVideo(String videoPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.videoService.deleteVideo(videoPath);
      if (success) {
        if (_selectedVideo == videoPath) {
          _videoPlayerController?.pause();
          _videoPlayerController?.dispose();
          _videoPlayerController = null;
          _selectedVideo = null;
        }
        _loadVideos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete video')),
        );
      }
    }
  }

  Future<void> _shareVideo(String videoPath) async {
    try {
      await Share.shareXFiles([XFile(videoPath)], text: 'Sharing recorded video');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing video: $e')),
      );
    }
  }

  Future<void> _playVideo(String videoPath) async {
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }

    setState(() {
      _selectedVideo = videoPath;
      _isPlaying = false;
    });

    _videoPlayerController = VideoPlayerController.file(File(videoPath))
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController!.play();
        _isPlaying = true;
      });

    _videoPlayerController!.addListener(() {
      setState(() {
        _isPlaying = _videoPlayerController!.value.isPlaying;
      });
    });
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;

    setState(() {
      if (_isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorded Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Video Player Section
          if (_selectedVideo != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            color: Colors.white,
                            onPressed: _togglePlayPause,
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _videoPlayerController!,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share),
                            color: Colors.white,
                            onPressed: () => _shareVideo(_selectedVideo!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.white,
                            onPressed: () => _deleteVideo(_selectedVideo!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedVideo != null && _videoPlayerController != null && !_videoPlayerController!.value.isInitialized)
            const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),

          // Video List Section
          Expanded(
            child: _videoPaths.isEmpty
                ? const Center(child: Text('No videos recorded yet'))
                : ListView.builder(
              itemCount: _videoPaths.length,
              itemBuilder: (context, index) {
                final videoPath = _videoPaths[index];
                final isSelected = _selectedVideo == videoPath;

                return ListTile(
                  title: Text(_formatVideoName(videoPath)),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.video_file, size: 30),
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  onTap: () => _playVideo(videoPath),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => _shareVideo(videoPath),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteVideo(videoPath),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pop(); // Return to recording page
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}