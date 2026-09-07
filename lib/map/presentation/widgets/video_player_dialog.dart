import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A dialog that safely plays a local video file.
///
/// Encapsulates the [VideoPlayerController] within [StatefulWidget] so that
/// controller disposal occurs only after the dialog route is completely popped.
class VideoPlayerDialog extends StatefulWidget {
  const VideoPlayerDialog({
    super.key,
    required this.filePath,
  });

  final String filePath;

  static Future<void> show(BuildContext context, String filePath) {
    return showDialog<void>(
      context: context,
      builder: (context) => VideoPlayerDialog(filePath: filePath),
    );
  }

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath));
    _initializeFuture = _controller.initialize().then((_) {
      if (mounted) {
        _controller.play();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !_controller.value.hasError) {
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            );
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '동영상 파일을 재생할 수 없습니다.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
