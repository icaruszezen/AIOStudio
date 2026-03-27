import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../../../shared/utils/format_utils.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  final String filePath;
  final String fileName;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final Player _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100.0;
  bool _isMuted = false;
  String? _error;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _setupListeners();
    _player.open(Media(widget.filePath));
  }

  void _setupListeners() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      }),
      _player.stream.position.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
      _player.stream.duration.listen((dur) {
        if (mounted) setState(() => _duration = dur);
      }),
      _player.stream.volume.listen((vol) {
        if (mounted) setState(() => _volume = vol);
      }),
      _player.stream.error.listen((error) {
        if (mounted) setState(() => _error = error);
      }),
    ]);
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _player.open(Media(widget.filePath));
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _seek(double value) {
    if (_duration.inMilliseconds <= 0) return;
    final ms = (value * _duration.inMilliseconds).round();
    _player.seek(Duration(milliseconds: ms));
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _player.setVolume(_isMuted ? 0 : _volume);
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      _isMuted = false;
    });
    _player.setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final ext = p
        .extension(widget.filePath)
        .toUpperCase()
        .replaceFirst('.', '');

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 48,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 8),
            Text('无法播放音频', style: theme.typography.body),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.music_in_collection,
              size: 64,
              color: theme.accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              widget.fileName,
              style: theme.typography.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              ext,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _WaveformVisualizer(
                progress: progress.clamp(0.0, 1.0),
                isPlaying: _isPlaying,
                accentColor: theme.accentColor,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Row(
                children: [
                  Text(
                    formatDuration(_position),
                    style: theme.typography.caption,
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 16,
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: _seek,
                      ),
                    ),
                  ),
                  Text(
                    formatDuration(_duration),
                    style: theme.typography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isMuted
                        ? FluentIcons.volume_disabled
                        : FluentIcons.volume3,
                    size: 16,
                  ),
                  onPressed: _toggleMute,
                ),
                SizedBox(
                  width: 80,
                  height: 16,
                  child: Slider(
                    value: _isMuted ? 0 : _volume,
                    max: 100,
                    onChanged: (v) => _setVolume(v),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(FluentIcons.previous, size: 16),
                  onPressed: () => _player.seek(Duration.zero),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _player.playOrPause(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _isPlaying ? FluentIcons.pause : FluentIcons.play,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FluentIcons.next, size: 16),
                  onPressed: () {
                    if (_duration.inMilliseconds > 0) {
                      _player.seek(_duration);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformVisualizer extends StatelessWidget {
  const _WaveformVisualizer({
    required this.progress,
    required this.isPlaying,
    required this.accentColor,
  });

  final double progress;
  final bool isPlaying;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: CustomPaint(
        size: const Size(double.infinity, 60),
        painter: _WaveformPainter(
          progress: progress,
          activeColor: accentColor,
          inactiveColor: accentColor.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  static final _rng = math.Random(42);
  static final _heights = List.generate(
    64,
    (_) => 0.2 + _rng.nextDouble() * 0.8,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _heights.length;
    final barWidth = size.width / barCount - 2;
    if (barWidth <= 0) return;

    final activePaint = Paint()..color = activeColor;
    final inactivePaint = Paint()..color = inactiveColor;

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + 2);
      final h = _heights[i] * size.height;
      final y = (size.height - h) / 2;
      final isActive = i / barCount <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(1.5),
        ),
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress;
}
