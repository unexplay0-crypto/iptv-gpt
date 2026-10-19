import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/media_item.dart';
import 'poster_card.dart';

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
