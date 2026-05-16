import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Inline video player widget surfaced by `_VideoCard` in `markdown_renderer.dart`
/// when a `![alt](path.mp4)` block is encountered (M201's terracotta-banded
/// video card UI). Tapping the M201 card still opens externally via
/// `Reveal.openUrl` — this widget renders directly inside the card when the
/// caller chooses inline playback.
///
/// Lifecycle:
/// 1. The controller is constructed from the file path in `initState`.
/// 2. While `controller.initialize()` is pending, a fixed-aspect placeholder
///    with a `CircularProgressIndicator` is shown so the renderer doesn't
///    flash an empty box.
/// 3. Once initialised, the actual `VideoPlayer` widget is built inside an
///    `AspectRatio` matching the video's intrinsic dimensions, with overlay
///    play/pause controls.
/// 4. The controller is disposed in `dispose()` to release platform resources.
///
/// Errors during initialise (codec missing, file not found, permission
/// denied) surface as a static error placeholder with the underlying error
/// message — the user's tap can still fall through to the OS player via the
/// surrounding card's gesture handler.
class VideoInlinePlayer extends StatefulWidget {
  const VideoInlinePlayer({super.key, required this.filePath});

  /// Absolute path to the video file on disk. Vault-relative paths must be
  /// resolved against the vault root before construction.
  final String filePath;

  @override
  State<VideoInlinePlayer> createState() => _VideoInlinePlayerState();
}

class _VideoInlinePlayerState extends State<VideoInlinePlayer> {
  VideoPlayerController? _controller;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (err) {
      if (mounted) setState(() => _initError = err);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_initError != null) {
      return _Placeholder(
        height: 160,
        child: Text(
          'Inline video unavailable\n$_initError',
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const _Placeholder(
        height: 160,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(c),
          _PlayPauseOverlay(controller: c),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(child: child),
    );
  }
}

class _PlayPauseOverlay extends StatefulWidget {
  const _PlayPauseOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_PlayPauseOverlay> createState() => _PlayPauseOverlayState();
}

class _PlayPauseOverlayState extends State<_PlayPauseOverlay> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.controller.value.isPlaying
              ? widget.controller.pause()
              : widget.controller.play();
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 200),
        child: widget.controller.value.isPlaying
            ? const SizedBox.shrink()
            : const ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
      ),
    );
  }
}
