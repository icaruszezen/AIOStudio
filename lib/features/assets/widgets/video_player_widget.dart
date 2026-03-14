import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/format_utils.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key, required this.filePath});

  final String filePath;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _videoController;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100.0;
  bool _isMuted = false;
  double _speed = 1.0;
  bool _showControls = true;
  Timer? _hideTimer;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _speedFlyoutController = FlyoutController();

  static const _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
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
    ]);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _player.open(Media(widget.filePath));
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _speedFlyoutController.dispose();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _player.playOrPause();
  }

  void _seek(double value) {
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

  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    _player.setRate(speed);
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return MouseRegion(
      onHover: (_) => _resetHideTimer(),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: Video(
                controller: _videoController,
                controls: (state) => const SizedBox.shrink(),
              ),
            ),
          ),
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                child: _buildControls(theme),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(FluentThemeData theme) {
    final progress =
        _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.overlayDark(0.8),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 16,
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              max: 1.0,
              onChanged: _seek,
              style: const SliderThemeData(
                thumbRadius: WidgetStatePropertyAll(6.0),
                useThumbBall: false,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _controlButton(
                _isPlaying ? FluentIcons.pause : FluentIcons.play,
                _togglePlay,
              ),
              const SizedBox(width: 8),
              Text(
                '${formatDuration(_position)} / ${formatDuration(_duration)}',
                style: const TextStyle(color: AppColors.textOnMedia, fontSize: 12),
              ),
              const Spacer(),
              _controlButton(
                _isMuted ? FluentIcons.volume_disabled : FluentIcons.volume3,
                _toggleMute,
              ),
              SizedBox(
                width: 80,
                height: 16,
                child: Slider(
                  value: _isMuted ? 0 : _volume,
                  max: 100,
                  onChanged: (v) => _setVolume(v),
                  style: const SliderThemeData(
                    thumbRadius: WidgetStatePropertyAll(5.0),
                    useThumbBall: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSpeedButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(FluentThemeData theme) {
    return FlyoutTarget(
      controller: _speedFlyoutController,
      child: GestureDetector(
        onTap: () {
          _speedFlyoutController.showFlyout(
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            builder: (ctx) {
              return MenuFlyout(
                items: _speeds
                    .map(
                      (s) => MenuFlyoutItem(
                        text: Text('${s}x'),
                        selected: _speed == s,
                        onPressed: () {
                          _setSpeed(s);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderOnMedia),
          ),
          child: Text(
            '${_speed}x',
            style: const TextStyle(color: AppColors.textOnMedia, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Icon(icon, size: 16, color: AppColors.textOnMedia),
    );
  }

}
