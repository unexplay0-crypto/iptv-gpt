import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/media_item.dart';
import '../widgets/poster_card.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.subtitle,
    this.searchMode = false,
  });

  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;
  final bool searchMode;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  String _group = 'Todas';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _groups {
    final values = widget.items.map((item) => item.groupTitle.trim()).where((item) => item.isNotEmpty).toSet().toList()..sort();
    return ['Todas', ...values];
  }

  List<MediaItem> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return widget.items.where((item) {
      final matchesQuery = query.isEmpty || item.title.toLowerCase().contains(query) || item.groupTitle.toLowerCase().contains(query);
      final matchesGroup = _group == 'Todas' || item.groupTitle == _group;
      return matchesQuery && matchesGroup;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tvLayout = width >= 850;
    final items = _filtered;
    final columns = width >= 1500 ? 8 : width >= 1150 ? 6 : width >= 850 ? 5 : width >= 600 ? 4 : 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(tvLayout ? 34 : 18, 18, tvLayout ? 34 : 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(widget.subtitle!, style: const TextStyle(color: AppTheme.textMuted)),
              ],
              const SizedBox(height: 17),
              LayoutBuilder(builder: (context, constraints) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth > 620 ? 370 : constraints.maxWidth,
                      child: TextField(
                        controller: _search,
                        autofocus: widget.searchMode,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: widget.searchMode ? 'Buscar canais, filmes e séries' : 'Filtrar neste catálogo',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
                        ),
                      ),
                    ),
                    if (_groups.length > 1)
                      SizedBox(
                        width: constraints.maxWidth > 620 ? 230 : constraints.maxWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: _groups.contains(_group) ? _group : 'Todas',
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.filter_list_rounded)),
                          items: _groups.map((value) => DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (value) => setState(() => _group = value ?? 'Todas'),
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 10),
              Text('${items.length} itens', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyCatalog(title: _search.text.isNotEmpty ? 'Nenhum resultado encontrado' : 'Nenhum conteúdo disponível', message: _search.text.isNotEmpty ? 'Experimente outro termo de busca.' : 'Atualize a lista ou confira a categoria selecionada.')
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(tvLayout ? 34 : 18, 10, tvLayout ? 34 : 18, 28),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: tvLayout ? 22 : 12,
                    mainAxisSpacing: tvLayout ? 20 : 14,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => PosterCard(item: items[index], width: double.infinity, onTap: () => widget.onTap(items[index])),
                ),
        ),
      ],
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off_rounded, size: 42, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: AppTheme.textMuted), textAlign: TextAlign.center),
          ]),
        ),
      );
}
