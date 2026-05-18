import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_player_controller_helper.dart';

class YoutubePlayerWidget extends StatefulWidget {
  final String url;

  const YoutubePlayerWidget({super.key, required this.url});

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  VideoPlayerController? _controller;

  bool _isLoading = true;
  bool _showControls = true;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  String? _error;

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final yt = YoutubeExplode();
      final videoId = YoutubePlayerControllerHelper.extractVideoId(widget.url);

      if (videoId == null) {
        setState(() {
          _error = 'Invalid YouTube URL';
          _isLoading = false;
        });
        return;
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(streamInfo.url.toString()),
      );

      await _controller!.initialize();
      await _controller!.setVolume(_volume);
      await _controller!.setPlaybackSpeed(_playbackSpeed);

      _controller!.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() => _isLoading = false);
      yt.close();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showControls = true);
    } else {
      _controller!.play();
      _scheduleHideControls();
    }
    setState(() {});
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller != null && _controller!.value.isPlaying) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _seekBy(Duration offset) {
    if (_controller == null) return;
    final newPos = _controller!.value.position + offset;
    final duration = _controller!.value.duration;
    final clamped = Duration(
      microseconds: newPos.inMicroseconds.clamp(0, duration.inMicroseconds),
    );
    _controller!.seekTo(clamped);
  }

  void _replayVideo() {
    if (_controller == null) return;
    _controller!.seekTo(Duration.zero);
    _controller!.play();
    _scheduleHideControls();
  }

  void _setSpeed(double speed) {
    _playbackSpeed = speed;
    _controller?.setPlaybackSpeed(speed);
    setState(() {});
  }

  void _setVolume(double value) {
    _volume = value;
    _controller?.setVolume(value);
    setState(() {});
  }

  void _openFullscreen() {
    if (_controller == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPlayer(
          url: widget.url,
          startPosition: _controller!.value.position,
          autoPlay: _controller!.value.isPlaying,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  bool get _isFinished =>
      _controller != null &&
      _controller!.value.duration.inSeconds > 0 &&
      _controller!.value.position >= _controller!.value.duration;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        children: [
          // Video layer
          Positioned.fill(child: VideoPlayer(_controller!)),

          // Tap to toggle controls
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          // Controls overlay
          if (_showControls || !_controller!.value.isPlaying)
            Positioned.fill(
              child: _ControlsOverlay(
                controller: _controller!,
                isFinished: _isFinished,
                volume: _volume,
                playbackSpeed: _playbackSpeed,
                speedOptions: _speedOptions,
                onPlayPause: _togglePlayPause,
                onSeekBack: () => _seekBy(const Duration(seconds: -10)),
                onSeekForward: () => _seekBy(const Duration(seconds: 10)),
                onReplay: _replayVideo,
                onVolumeChanged: _setVolume,
                onSpeedChanged: _setSpeed,
                onFullscreen: _openFullscreen,
                formatDuration: _formatDuration,
              ),
            ),

          // Buffering indicator (not covered by controls)
          if (_controller!.value.isBuffering)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

// ─── Controls Overlay ──────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isFinished;
  final double volume;
  final double playbackSpeed;
  final List<double> speedOptions;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onReplay;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onFullscreen;
  final String Function(Duration) formatDuration;

  // Optional back button for fullscreen mode
  final VoidCallback? onBack;

  const _ControlsOverlay({
    required this.controller,
    required this.isFinished,
    required this.volume,
    required this.playbackSpeed,
    required this.speedOptions,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onReplay,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onFullscreen,
    required this.formatDuration,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMuted = volume == 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.3, 0.7, 1.0],
          colors: [
            Color(0x99000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar: [back?] + spacer + speed ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                const Spacer(),
                // Speed selector
                GestureDetector(
                  onTap: () => _showSpeedMenu(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${playbackSpeed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Centre: seek back | play/pause | seek forward ──────────
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SeekButton(icon: Icons.replay_10, onTap: onSeekBack),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: isFinished ? onReplay : onPlayPause,
                    child: Icon(
                      isFinished
                          ? Icons.replay
                          : controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                  const SizedBox(width: 24),
                  _SeekButton(icon: Icons.forward_10, onTap: onSeekForward),
                ],
              ),
            ),
          ),

          // ── Bottom: progress bar + [mute | time | spacer | fullscreen]
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mute toggle — affects player volume only.
                    // Use your device's physical buttons to change system volume.
                    IconButton(
                      onPressed: () => onVolumeChanged(isMuted ? 1.0 : 0.0),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Current position
                    Text(
                      formatDuration(controller.value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Text(
                      ' / ',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    // Total duration
                    Text(
                      formatDuration(controller.value.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // Fullscreen / exit-fullscreen
                    IconButton(
                      onPressed: onFullscreen,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        onBack != null
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSpeedMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    showMenu<double>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width - 80,
        offset.dy + 36,
        offset.dx + box.size.width,
        offset.dy + 36 + speedOptions.length * 48.0,
      ),
      items: speedOptions
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              child: Text(
                '${s}x',
                style: TextStyle(
                  fontWeight: s == playbackSpeed
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    ).then((value) {
      if (value != null) onSpeedChanged(value);
    });
  }
}

class _SeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SeekButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 36),
    );
  }
}

// ─── Fullscreen Player ──────────────────────────────────────────────────────

class FullscreenVideoPlayer extends StatefulWidget {
  final String url;
  final Duration startPosition;
  final bool autoPlay;

  const FullscreenVideoPlayer({
    super.key,
    required this.url,
    required this.startPosition,
    required this.autoPlay,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  VideoPlayerController? _controller;

  bool _showControls = true;
  bool _isLoading = true;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final yt = YoutubeExplode();
    final videoId = YoutubePlayerControllerHelper.extractVideoId(widget.url);
    final manifest = await yt.videos.streamsClient.getManifest(videoId!);
    final streamInfo = manifest.muxed.withHighestBitrate();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(streamInfo.url.toString()),
    );

    await _controller!.initialize();
    await _controller!.seekTo(widget.startPosition);
    await _controller!.setVolume(_volume);
    await _controller!.setPlaybackSpeed(_playbackSpeed);

    if (widget.autoPlay) {
      await _controller!.play();
      _scheduleHideControls();
    }

    _controller!.addListener(() {
      if (mounted) setState(() {});
    });

    setState(() => _isLoading = false);
    yt.close();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller != null && _controller!.value.isPlaying) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showControls = true);
    } else {
      _controller!.play();
      _scheduleHideControls();
    }
    setState(() {});
  }

  void _seekBy(Duration offset) {
    if (_controller == null) return;
    final newPos = _controller!.value.position + offset;
    final duration = _controller!.value.duration;
    final clamped = Duration(
      microseconds: newPos.inMicroseconds.clamp(0, duration.inMicroseconds),
    );
    _controller!.seekTo(clamped);
  }

  void _replayVideo() {
    _controller?.seekTo(Duration.zero);
    _controller?.play();
    _scheduleHideControls();
  }

  void _setSpeed(double speed) {
    _playbackSpeed = speed;
    _controller?.setPlaybackSpeed(speed);
    setState(() {});
  }

  void _setVolume(double value) {
    _volume = value;
    _controller?.setVolume(value);
    setState(() {});
  }

  bool get _isFinished =>
      _controller != null &&
      _controller!.value.duration.inSeconds > 0 &&
      _controller!.value.position >= _controller!.value.duration;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

            // Controls
            if (_showControls)
              Positioned.fill(
                child: _ControlsOverlay(
                  controller: _controller!,
                  isFinished: _isFinished,
                  volume: _volume,
                  playbackSpeed: _playbackSpeed,
                  speedOptions: _speedOptions,
                  onPlayPause: _togglePlayPause,
                  onSeekBack: () => _seekBy(const Duration(seconds: -10)),
                  onSeekForward: () => _seekBy(const Duration(seconds: 10)),
                  onReplay: _replayVideo,
                  onVolumeChanged: _setVolume,
                  onSpeedChanged: _setSpeed,
                  onFullscreen: () => Navigator.pop(context),
                  formatDuration: _formatDuration,
                  onBack: () => Navigator.pop(context),
                ),
              ),

            // Buffering
            if (_controller!.value.isBuffering)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
