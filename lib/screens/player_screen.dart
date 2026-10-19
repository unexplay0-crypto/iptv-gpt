import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../controllers/app_controller.dart';
import '../core/app_constants.dart';
import '../core/app_theme.dart';
import '../models/media_item.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, required this.controller, this.queue = const []});
  final MediaItem item;
  final AppController controller;
  final List<MediaItem> queue;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _video;
  Timer? _hideTimer;
  int _generation = 0;
  int _queueIndex = 0;
  int _lastSavedSecond = -10;
  bool _loading = true;
  bool _controlsVisible = true;
  String? _errorCode;

  MediaItem get _item => _queue.isNotEmpty ? _queue[_queueIndex] : widget.item;
  late final List<MediaItem> _queue;

  @override
  void initState() {
    super.initState();
    final initial = widget.queue.isEmpty ? [widget.item] : widget.queue;
    _queue = initial;
    final found = initial.indexWhere((item) => item.id == widget.item.id);
    _queueIndex = found < 0 ? 0 : found;
    widget.controller.markPlayed(_item);
    _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    final previous = _video;
    if (previous != null) {
      previous.removeListener(_onTick);
      _video = null;
      await previous.dispose();
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    VideoPlayerController? next;
    try {
      final uri = Uri.parse(_item.streamUrl);
      if (!{'http', 'https'}.contains(uri.scheme.toLowerCase()) || uri.host.isEmpty) {
        throw const FormatException('Invalid media URL');
      }
      next = VideoPlayerController.networkUrl(uri, httpHeaders: _item.headers);
      _video = next;
      next.addListener(_onTick);
      await next.initialize().timeout(AppConstants.playerInitTimeout);
      if (!mounted || generation != _generation || !identical(_video, next)) {
        await next.dispose();
        return;
      }
      if (!_item.isLive) {
        final resume = widget.controller.progressFor(_item);
        if (resume > const Duration(seconds: 5) && resume < next.value.duration - const Duration(seconds: 15)) {
          await next.seekTo(resume);
        }
      }
      await next.play();
      await widget.controller.markPlayed(_item);
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        _scheduleHide();
      }
    } catch (error) {
      if (next != null) {
        next.removeListener(_onTick);
        if (identical(_video, next)) _video = null;
        await next.dispose();
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _errorCode = _classifyError(error);
      });
    }
  }

  String _classifyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('timeout')) return 'TIMEOUT';
    if (text.contains('401') || text.contains('403') || text.contains('unauthorized')) return 'AUTH';
    if (text.contains('404') || text.contains('not found')) return 'NOT_FOUND';
    if (text.contains('socket') || text.contains('dns') || text.contains('network')) return 'NETWORK';
    if (text.contains('format') || text.contains('decoder') || text.contains('source')) return 'FORMAT';
    return 'PLAYBACK';
  }

  void _onTick() {
    final video = _video;
    if (!mounted || video == null || !video.value.isInitialized) return;
    final second = video.value.position.inSeconds;
    if (!_item.isLive && second > 0 && second ~/ 10 > _lastSavedSecond ~/ 10) {
      _lastSavedSecond = second;
      widget.controller.saveProgress(_item, video.value.position, video.value.duration);
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_item.isLive && _video?.value.isPlaying == true) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    } else {
      _hideTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    if (video.value.isPlaying) {
      await video.pause();
      await widget.controller.saveProgress(_item, video.value.position, video.value.duration);
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      await video.play();
      _showControls();
    }
  }

  Future<void> _seek(Duration delta) async {
    final video = _video;
    if (video == null || !video.value.isInitialized || _item.isLive) return;
    var target = video.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > video.value.duration) target = video.value.duration;
    await video.seekTo(target);
    _showControls();
  }

  Future<void> _changeChannel(int delta) async {
    if (!_item.isLive || _queue.length < 2) return;
    final next = (_queueIndex + delta) % _queue.length;
    _queueIndex = next < 0 ? _queue.length - 1 : next;
    _lastSavedSecond = -10;
    await _initialize();
    if (mounted) setState(() => _controlsVisible = true);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      _togglePlay();
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_item.isLive) {
        _changeChannel(-1);
      } else {
        _seek(const Duration(seconds: -10));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_item.isLive) {
        _changeChannel(1);
      } else {
        _seek(const Duration(seconds: 10));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _item.isLive) {
      _changeChannel(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _item.isLive) {
      _changeChannel(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    _showControls();
    return KeyEventResult.ignored;
  }

  String _messageForError(String code) => switch (code) {
        'TIMEOUT' => 'O vídeo demorou demais para iniciar. A rede ou o servidor pode estar lento.',
        'AUTH' => 'O servidor recusou o acesso ao fluxo. Confira a conta ou as permissões do provedor.',
        'NOT_FOUND' => 'O endereço de mídia não existe ou foi removido pelo provedor.',
        'NETWORK' => 'Não foi possível alcançar o servidor. Confira a conexão.',
        'FORMAT' => 'O dispositivo não conseguiu abrir este formato ou o fluxo está malformado.',
        _ => 'Não foi possível iniciar a reprodução. O provedor pode estar indisponível ou o formato pode não ser compatível.',
      };

  @override
  void dispose() {
    _generation++;
    _hideTimer?.cancel();
    final video = _video;
    if (video != null) {
      video.removeListener(_onTick);
      if (video.value.isInitialized && !_item.isLive) {
        widget.controller.saveProgress(_item, video.value.position, video.value.duration);
      }
      video.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video != null && video.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: video.value.aspectRatio > 0 ? video.value.aspectRatio : 16 / 9,
                    child: VideoPlayer(video),
                  ),
                )
              else
                const Center(child: Icon(Icons.live_tv_rounded, size: 58, color: Color(0xFF34404D))),
              if (_loading)
                Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                ),
              if (_errorCode != null)
                Container(
                  color: Colors.black.withValues(alpha: 0.86),
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline_rounded, size: 50, color: Color(0xFFFF7B86)),
                        const SizedBox(height: 18),
                        Text(_item.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        Text(_messageForError(_errorCode!), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, height: 1.45)),
                        const SizedBox(height: 9),
                        Text('Diagnóstico: $_errorCode', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(height: 20),
                        Wrap(spacing: 12, children: [
                          FilledButton.icon(onPressed: _initialize, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente')),
                          OutlinedButton.icon(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Voltar')),
                        ]),
                      ]),
                    ),
                  ),
                ),
              if (_errorCode == null && !_loading && _controlsVisible)
                _PlayerOverlay(
                  item: _item,
                  video: video,
                  queuePosition: _queueIndex + 1,
                  queueLength: _queue.length,
                  onBack: () => Navigator.of(context).maybePop(),
                  onTogglePlay: _togglePlay,
                  onSeekBackward: () => _item.isLive ? _changeChannel(-1) : _seek(const Duration(seconds: -10)),
                  onSeekForward: () => _item.isLive ? _changeChannel(1) : _seek(const Duration(seconds: 10)),
                  onChannelBackward: () => _changeChannel(-1),
                  onChannelForward: () => _changeChannel(1),
                  onFavorite: () => widget.controller.toggleFavorite(_item),
                  isFavorite: widget.controller.isFavorite(_item),
                  onInteraction: _showControls,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerOverlay extends StatelessWidget {
  const _PlayerOverlay({
    required this.item,
    required this.video,
    required this.queuePosition,
    required this.queueLength,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onChannelBackward,
    required this.onChannelForward,
    required this.onFavorite,
    required this.isFavorite,
    required this.onInteraction,
  });

  final MediaItem item;
  final VideoPlayerController? video;
  final int queuePosition;
  final int queueLength;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onChannelBackward;
  final VoidCallback onChannelForward;
  final VoidCallback onFavorite;
  final bool isFavorite;
  final VoidCallback onInteraction;

  String _time(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '${duration.inMinutes.toString().padLeft(2, '0')}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = video?.value;
    final duration = value?.duration ?? Duration.zero;
    final position = value?.position ?? Duration.zero;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xB8000000), Colors.transparent, Color(0xE6000000)], stops: [0, 0.42, 1]),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(children: [
                IconButton(onPressed: onBack, tooltip: 'Voltar', icon: const Icon(Icons.arrow_back_rounded, size: 28)),
                const SizedBox(width: 7),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(item.isLive ? 'AO VIVO  •  ${item.groupTitle}' : item.groupTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ])),
                IconButton(onPressed: onFavorite, tooltip: isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos', icon: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? const Color(0xFFFF6575) : Colors.white)),
                if (item.isLive && queueLength > 1) Padding(padding: const EdgeInsets.only(left: 6), child: Text('$queuePosition/$queueLength', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              ]),
            ),
            const Spacer(),
            Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (item.isLive && queueLength > 1) IconButton.filledTonal(onPressed: onChannelBackward, tooltip: 'Canal anterior', icon: const Icon(Icons.skip_previous_rounded), iconSize: 34, style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
                if (!item.isLive) IconButton.filledTonal(onPressed: onSeekBackward, tooltip: 'Voltar 10 segundos', icon: const Icon(Icons.replay_10_rounded), iconSize: 34, style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
                const SizedBox(width: 14),
                IconButton.filled(
                  onPressed: onTogglePlay,
                  tooltip: value?.isPlaying == true ? 'Pausar' : 'Reproduzir',
                  icon: Icon(value?.isPlaying == true ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black, minimumSize: const Size(78, 78)),
                ),
                const SizedBox(width: 14),
                if (!item.isLive) IconButton.filledTonal(onPressed: onSeekForward, tooltip: 'Avançar 10 segundos', icon: const Icon(Icons.forward_10_rounded), iconSize: 34, style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
                if (item.isLive && queueLength > 1) IconButton.filledTonal(onPressed: onChannelForward, tooltip: 'Próximo canal', icon: const Icon(Icons.skip_next_rounded), iconSize: 34, style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
              ]),
            ),
            const Spacer(),
            if (!item.isLive && duration > Duration.zero)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(children: [
                  Slider(
                    value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                    max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity).toDouble(),
                    onChanged: video == null ? null : (value) { video!.seekTo(Duration(milliseconds: value.toInt())); onInteraction(); },
                  ),
                  Row(children: [Text(_time(position), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)), const Spacer(), Text(_time(duration), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))]),
                ]),
              )
            else
              const Padding(padding: EdgeInsets.only(bottom: 24), child: Text('Use o controle remoto para navegar • OK para pausar/continuar', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
