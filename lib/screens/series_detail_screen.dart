import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/app_theme.dart';
import '../models/media_item.dart';
import '../widgets/poster_card.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.controller, required this.series, required this.onPlay});
  final AppController controller;
  final MediaItem series;
  final ValueChanged<MediaItem> onPlay;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<MediaItem> _episodes = [];
  MediaItem? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final details = await widget.controller.enrichMetadata(widget.series);
      final episodes = await widget.controller.loadEpisodes(widget.series);
      if (!mounted) return;
      setState(() {
        _details = details;
        _episodes = episodes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _details = widget.series;
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _details ?? widget.series;
    final width = MediaQuery.sizeOf(context).width;
    final tvLayout = width >= 900;
    return Scaffold(
      appBar: AppBar(title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(tvLayout ? 42 : 18, 12, tvLayout ? 42 : 18, 32),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: tvLayout ? 210 : 120, child: PosterCard(item: item, width: tvLayout ? 210 : 120, showGroup: false, onTap: () {})),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 9),
              Text([if (item.year.isNotEmpty) item.year, item.groupTitle].join('  •  '), style: const TextStyle(color: AppTheme.textMuted)),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(item.description, maxLines: tvLayout ? 7 : 5, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
              ],
              const SizedBox(height: 17),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(onPressed: _episodes.isEmpty ? null : () => widget.onPlay(_episodes.first), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Assistir primeiro episódio')),
                OutlinedButton.icon(
                  onPressed: () async { await widget.controller.toggleFavorite(item); if (mounted) setState(() {}); },
                  icon: Icon(widget.controller.isFavorite(item) ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                  label: Text(widget.controller.isFavorite(item) ? 'Na minha lista' : 'Adicionar à minha lista'),
                ),
              ]),
            ])),
          ]),
          const SizedBox(height: 30),
          Text('Episódios', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFFA0AA))),
          if (!_loading && _episodes.isEmpty && _error == null)
            const Text('Não foi possível encontrar episódios para esta série.', style: TextStyle(color: AppTheme.textMuted)),
          ..._episodes.map((episode) => Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  autofocus: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  leading: Container(
                    width: 62,
                    height: 48,
                    decoration: BoxDecoration(color: AppTheme.surfaceRaised, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: Text('${episode.seasonNumber.toString().padLeft(2, '0')} • ${episode.episodeNumber.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: episode.description.isEmpty ? null : Text(episode.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.accent, size: 29),
                  onTap: () => widget.onPlay(episode),
                ),
              )),
        ],
      ),
    );
  }
}
