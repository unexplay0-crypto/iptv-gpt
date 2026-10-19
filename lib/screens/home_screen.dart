import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/media_item.dart';
import '../widgets/media_shelf.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.live,
    required this.movies,
    required this.series,
    required this.history,
    required this.favorites,
    required this.tvLayout,
    required this.onPlay,
    required this.onSeeLive,
    required this.onSeeMovies,
    required this.onSeeSeries,
    required this.onSeeFavorites,
    required this.onSeeHistory,
    required this.onRefresh,
  });

  final List<MediaItem> live;
  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<MediaItem> history;
  final List<MediaItem> favorites;
  final bool tvLayout;
  final ValueChanged<MediaItem> onPlay;
  final VoidCallback onSeeLive;
  final VoidCallback onSeeMovies;
  final VoidCallback onSeeSeries;
  final VoidCallback onSeeFavorites;
  final VoidCallback onSeeHistory;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final featured = movies.isNotEmpty ? movies.first : series.isNotEmpty ? series.first : live.isNotEmpty ? live.first : null;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(tvLayout ? 35 : 18, 14, tvLayout ? 35 : 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (featured != null) _HeroFeature(item: featured, tvLayout: tvLayout, onPlay: () => onPlay(featured), onExplore: onSeeMovies),
                  if (featured == null) _EmptyHero(onRefresh: onRefresh),
                  const SizedBox(height: 30),
                  if (history.isNotEmpty) MediaShelf(title: 'Continue assistindo', items: history, onTap: onPlay, tvLayout: tvLayout, onSeeAll: onSeeHistory),
                  MediaShelf(title: 'Canais ao vivo', items: live, onTap: onPlay, tvLayout: tvLayout, onSeeAll: onSeeLive),
                  MediaShelf(title: 'Filmes para você', items: movies, onTap: onPlay, tvLayout: tvLayout, onSeeAll: onSeeMovies),
                  MediaShelf(title: 'Séries', items: series, onTap: onPlay, tvLayout: tvLayout, onSeeAll: onSeeSeries),
                  if (favorites.isNotEmpty) MediaShelf(title: 'Minha lista', items: favorites, onTap: onPlay, tvLayout: tvLayout, onSeeAll: onSeeFavorites),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({required this.item, required this.tvLayout, required this.onPlay, required this.onExplore});
  final MediaItem item;
  final bool tvLayout;
  final VoidCallback onPlay;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: tvLayout ? 335 : 245,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppTheme.surfaceRaised),
            if (item.backdropUrl.isNotEmpty || item.posterUrl.isNotEmpty)
              Image.network(
                item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppTheme.background.withValues(alpha: 0.98), AppTheme.background.withValues(alpha: 0.68), AppTheme.background.withValues(alpha: 0.05)],
                  stops: const [0, 0.57, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tvLayout ? 34 : 21),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: tvLayout ? 520 : 310),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 15, color: AppTheme.accent),
                          const SizedBox(width: 7),
                          Text(item.type == MediaType.live ? 'DESTAQUE AO VIVO' : 'DESTAQUE PARA VOCÊ', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.accent)),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: tvLayout ? 31 : 23, fontWeight: FontWeight.w900, height: 1.08)),
                      if (item.year.isNotEmpty || item.groupTitle.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text([if (item.year.isNotEmpty) item.year, item.groupTitle].join('  •  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(item.description, maxLines: tvLayout ? 3 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD2DAE1), height: 1.35, fontSize: 12)),
                      ],
                      const SizedBox(height: 17),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(onPressed: item.isPlayable ? onPlay : onExplore, icon: const Icon(Icons.play_arrow_rounded), label: Text(item.isPlayable ? 'Assistir agora' : 'Explorar catálogo')),
                          OutlinedButton.icon(onPressed: onExplore, icon: const Icon(Icons.grid_view_rounded), label: const Text('Explorar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        height: 245,
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.live_tv_rounded, size: 34, color: AppTheme.accent),
            const SizedBox(height: 12),
            Text('Seu conteúdo começa aqui', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            const Text('Puxe para atualizar ou confira os dados da lista nas configurações.', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Atualizar conteúdo')),
          ],
        ),
      );
}
