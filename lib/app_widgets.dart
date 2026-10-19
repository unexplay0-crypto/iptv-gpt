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
      padding: EdgeInsets.only(bottom: tvLayout ? 34 : 27),
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
            height: tvLayout ? 302 : 258,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length > 25 ? 25 : items.length,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              separatorBuilder: (context, index) => const SizedBox(width: 13),
              itemBuilder: (context, index) => PosterCard(
                item: items[index],
                width: tvLayout ? 184 : 144,
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
    final isLive = widget.item.type == MediaType.live;
    return SizedBox(
      width: widget.width,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        child: AnimatedScale(
          scale: selected ? 1.035 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(15),
              focusColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? AppTheme.accent : Colors.transparent, width: selected ? 2 : 1),
                  boxShadow: selected ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.18), blurRadius: 22, spreadRadius: 1)] : const [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: AspectRatio(
                        aspectRatio: isLive ? 16 / 10 : 2 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF29243D), Color(0xFF171922), Color(0xFF11131A)]),
                                ),
                                child: Center(child: Icon(_iconFor(widget.item.type), size: 40, color: AppTheme.accent.withValues(alpha: 0.9))),
                              ),
                              if (widget.item.posterUrl.isNotEmpty)
                                Image.network(
                                  widget.item.posterUrl,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                                ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33000000), Colors.transparent, Color(0x66000000)], stops: [0, 0.42, 1]),
                                ),
                              ),
                              if (isLive)
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(color: AppTheme.live, borderRadius: BorderRadius.circular(6)),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.circle, size: 6, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('AO VIVO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                                    ]),
                                  ),
                                ),
                              if (widget.item.isAdult)
                                Positioned(right: 7, top: 7, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.lock_rounded, size: 15, color: Colors.white))),
                              if (selected)
                                Center(child: Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12)]), child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF100E1C), size: 32))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, height: 1.2, color: selected ? Colors.white : const Color(0xFFE6E7ED))),
                    if (widget.showGroup) ...[
                      const SizedBox(height: 4),
                      Text(widget.item.groupTitle.isNotEmpty ? widget.item.groupTitle : widget.item.year, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
