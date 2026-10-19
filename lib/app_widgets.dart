import 'package:flutter/material.dart';
import 'package:iptv/app_core.dart';

// ---- Merged from widgets/media_shelf.dart ----

class MediaShelf extends StatelessWidget {
  const MediaShelf({super.key, required this.title, required this.items, required this.onTap, this.onSeeAll, this.tvLayout = false});
  final String title;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;
  final VoidCallback? onSeeAll;
  final bool tvLayout;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: tvLayout ? 29 : 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                if (onSeeAll != null)
                  TextButton.icon(
                    onPressed: onSeeAll,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Ver tudo'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: tvLayout ? 282 : 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length > 25 ? 25 : items.length,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              separatorBuilder: (context, index) => const SizedBox(width: 13),
              itemBuilder: (context, index) => PosterCard(
                item: items[index],
                width: tvLayout ? 170 : 136,
                onTap: () => onTap(items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Merged from widgets/poster_card.dart ----

class PosterCard extends StatefulWidget {
  const PosterCard({super.key, required this.item, required this.onTap, this.width = 148, this.showGroup = true});
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final bool showGroup;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = _focused || _hovered;
    return SizedBox(
      width: widget.width,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        child: AnimatedScale(
          scale: selected ? 1.045 : 1,
          duration: const Duration(milliseconds: 130),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(13),
              focusColor: AppTheme.accent.withValues(alpha: 0.10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: selected ? AppTheme.accent : Colors.transparent, width: selected ? 2 : 1),
                  boxShadow: selected ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.14), blurRadius: 18)] : const [],
                ),
                padding: const EdgeInsets.all(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: widget.item.type == MediaType.live ? 16 / 10 : 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: AppTheme.surfaceRaised,
                              alignment: Alignment.center,
                              child: Icon(_iconFor(widget.item.type), size: 38, color: AppTheme.accent.withValues(alpha: 0.85)),
                            ),
                            if (widget.item.posterUrl.isNotEmpty)
                              Image.network(
                                widget.item.posterUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                                loadingBuilder: (context, child, progress) => child,
                              ),
                            if (widget.item.type == MediaType.live)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFE33C51), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('AO VIVO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                ),
                              ),
                            if (widget.item.isAdult)
                              const Positioned(right: 7, top: 7, child: Icon(Icons.lock_rounded, size: 17, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, height: 1.18),
                    ),
                    if (widget.showGroup) ...[
                      const SizedBox(height: 4),
                      Text(widget.item.groupTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(MediaType type) => switch (type) {
        MediaType.live => Icons.live_tv_rounded,
        MediaType.movie => Icons.local_movies_rounded,
        MediaType.series => Icons.video_library_rounded,
        MediaType.episode => Icons.play_circle_outline_rounded,
      };
}
