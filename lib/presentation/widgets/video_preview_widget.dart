import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoPreviewWidget extends StatefulWidget {
  const VideoPreviewWidget({
    super.key,
    required this.videoPath,
    required this.uniqueKey,
  });

  final String videoPath;
  final String uniqueKey;

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVisible = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  Future<void> _initializeVideo() async {
    if (_controller != null || !_isVisible) return;

    print('Initializing video: ${widget.videoPath}');
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });

        // Play silently and loop for preview
        _controller!.setLooping(true);
        _controller!.setVolume(0.0);
        _controller!.play();
      }
    } catch (e) {
      print('Video initialization error for ${widget.videoPath}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
      _disposeController();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.1; // At least 10% visible

    if (_isVisible && !wasVisible) {
      // Became visible - initialize and play
      _initializeVideo();
    } else if (!_isVisible && wasVisible) {
      // Became invisible - pause and dispose to save memory
      _controller?.pause();
      // Dispose after a delay to avoid flicker on quick scrolls
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isVisible && mounted) {
          _disposeController();
          if (mounted) {
            setState(() {
              _isInitialized = false;
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_${widget.uniqueKey}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized && _controller != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ] else if (_hasError) ...[
              _buildErrorWidget(),
            ] else ...[
              _buildLoadingWidget(),
            ],

            // Play icon overlay for video indication
            if (_isInitialized || _hasError) ...[
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],

            // Duration overlay if available
            if (_isInitialized && _controller != null) ...[
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(_controller!.value.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.videocam,
              size: 32,
              color: Color(0xFF8E8E93),
            ),
            SizedBox(height: 8),
            CupertinoActivityIndicator(color: Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 32,
              color: Color(0xFFFF3B30),
            ),
            SizedBox(height: 4),
            Text(
              'Video Error',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}