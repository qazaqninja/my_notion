import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Inline audio player surfaced by `_FileAttachment`'s M201 audio card when
/// a `![alt](path.mp3|wav|m4a|flac|ogg)` block is encountered. Renders a
/// compact horizontal strip with play/pause, a scrubber, and a position /
/// duration label — no waveform yet.
///
/// Lifecycle:
/// 1. `initState` constructs an `AudioPlayer`, subscribes to position /
///    duration / completion streams, and calls `setSource(DeviceFileSource)`
///    so duration is known before the user taps play.
/// 2. Tap play → `player.resume()`; tap pause → `player.pause()`.
/// 3. Drag scrubber → `player.seek(target)`.
/// 4. On completion, the play button resets and position rewinds to 00:00.
/// 5. `dispose` releases all streams and calls `player.dispose()`.
class AudioInlinePlayer extends StatefulWidget {
  const AudioInlinePlayer({super.key, required this.filePath});

  /// Absolute file path. Vault-relative paths must be resolved before
  /// construction (renderer side).
  final String filePath;

  @override
  State<AudioInlinePlayer> createState() => _AudioInlinePlayerState();
}

class _AudioInlinePlayerState extends State<AudioInlinePlayer> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _doneSub;

  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _initSource();
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _initSource() async {
    try {
      await _player.setSource(DeviceFileSource(widget.filePath));
    } catch (_) {
      // Swallow — error UI surfaces via the lack of a duration; the user
      // can still tap the metadata row to fall through to the external
      // player via the surrounding card.
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.resume();
      if (mounted) setState(() => _playing = true);
    }
  }

  String _fmt(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dur = _duration ?? Duration.zero;
    final progress = dur.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) async {
                  final ms = (dur.inMilliseconds * v).round();
                  await _player.seek(Duration(milliseconds: ms));
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_fmt(_position)} / ${_fmt(_duration)}',
            style: const TextStyle(fontSize: 11, fontFamily: 'JetBrainsMono'),
          ),
        ],
      ),
    );
  }
}
