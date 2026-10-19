import 'package:flutter/material.dart';
import 'package:iptv/app_controller.dart';
import 'package:iptv/app_core.dart';
import 'package:iptv/app_widgets.dart';

// ---- Merged from screens/catalog_screen.dart ----

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
    final columns = width >= 1600 ? 7 : width >= 1250 ? 6 : width >= 850 ? 5 : width >= 600 ? 4 : width < 390 ? 2 : 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(tvLayout ? 38 : 14, tvLayout ? 24 : 10, tvLayout ? 38 : 14, tvLayout ? 14 : 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: tvLayout ? Theme.of(context).textTheme.headlineMedium : Theme.of(context).textTheme.titleLarge),
              if (widget.subtitle != null && tvLayout) ...[
                const SizedBox(height: 6),
                Text(widget.subtitle!, style: const TextStyle(color: AppTheme.textMuted)),
              ],
              SizedBox(height: tvLayout ? 17 : 8),
              LayoutBuilder(builder: (context, constraints) {
                final searchField = TextField(
                  controller: _search,
                  autofocus: widget.searchMode,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: !tvLayout,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: tvLayout ? 16 : 10),
                    hintText: widget.searchMode ? 'Buscar canais, filmes e séries' : 'Filtrar neste catálogo',
                    prefixIcon: const Icon(Icons.search_rounded),
                    prefixIconConstraints: BoxConstraints(minWidth: tvLayout ? 48 : 38, minHeight: 40),
                    suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
                  ),
                );
                if (!tvLayout) {
                  return Row(children: [
                    Expanded(child: searchField),
                    if (_groups.length > 1) ...[
                      const SizedBox(width: 7),
                      PopupMenuButton<String>(
                        tooltip: 'Filtrar por categoria',
                        initialValue: _group,
                        onSelected: (value) => setState(() => _group = value),
                        itemBuilder: (context) => _groups.map((value) => PopupMenuItem<String>(value: value, child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: AppTheme.surface, border: Border.all(color: AppTheme.outline), borderRadius: BorderRadius.circular(12)),
                          child: Stack(alignment: Alignment.center, children: [
                            const Icon(Icons.filter_list_rounded),
                            if (_group != 'Todas') Positioned(right: 9, top: 9, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.accentSecondary, shape: BoxShape.circle))),
                          ]),
                        ),
                      ),
                    ],
                  ]);
                }
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: constraints.maxWidth > 620 ? 370 : constraints.maxWidth, child: searchField),
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
              SizedBox(height: tvLayout ? 10 : 5),
              Row(children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentSecondary, shape: BoxShape.circle)), const SizedBox(width: 8), Text('${items.length} títulos disponíveis', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600))]),
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
                    childAspectRatio: width < 600 ? 0.56 : 0.62,
                    crossAxisSpacing: tvLayout ? 24 : 14,
                    mainAxisSpacing: tvLayout ? 24 : 18,
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

// ---- Merged from screens/guide_screen.dart ----

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.controller, required this.channels, required this.onPlay, required this.tvLayout});
  final AppController controller;
  final List<MediaItem> channels;
  final ValueChanged<MediaItem> onPlay;
  final bool tvLayout;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  MediaItem? _selected;
  List<EpgProgram> _programs = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.channels.isNotEmpty) {
      _selected = widget.channels.first;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(_selected!));
    }
  }

  Future<void> _load(MediaItem channel) async {
    setState(() { _selected = channel; _loading = true; _error = null; _programs = []; });
    try {
      final programs = await widget.controller.loadPrograms(channel);
      if (!mounted) return;
      setState(() { _programs = programs; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  String _clock(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final channelList = SizedBox(
      width: widget.tvLayout ? 330 : double.infinity,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: widget.channels.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final item = widget.channels[index];
          final selected = item.id == _selected?.id;
          return Material(
            color: selected ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              autofocus: index == 0,
              leading: const Icon(Icons.live_tv_rounded, color: AppTheme.accent),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(item.groupTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: selected ? const Icon(Icons.chevron_right_rounded, color: AppTheme.accent) : null,
              onTap: () => _load(item),
            ),
          );
        },
      ),
    );
    final programList = Padding(
      padding: EdgeInsets.fromLTRB(widget.tvLayout ? 24 : 18, 16, widget.tvLayout ? 32 : 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guia de programação', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(_selected?.title ?? 'Selecione um canal', style: const TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 17),
          if (_selected != null)
            FilledButton.icon(onPressed: () => widget.onPlay(_selected!), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Assistir canal')),
          const SizedBox(height: 18),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFFA0AA))),
          if (!_loading && _programs.isEmpty && _error == null)
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('Sem programação disponível para este canal. Informe uma URL XMLTV nas configurações ou use o EPG do servidor Xtream.', style: TextStyle(color: AppTheme.textMuted, height: 1.45))),
          if (_programs.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _programs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ProgramTile(program: _programs[index], clock: _clock),
              ),
            )
          else
            const Spacer(),
          if (widget.controller.account?.epgUrl.isNotEmpty == true) const Text('Fonte: XMLTV / servidor IPTV', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );

    if (widget.tvLayout) {
      return Row(children: [channelList, const VerticalDivider(width: 1), Expanded(child: programList)]);
    }
    return Column(children: [
      SizedBox(height: 215, child: channelList),
      const Divider(height: 1),
      Expanded(child: programList),
    ]);
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.program, required this.clock});
  final EpgProgram program;
  final String Function(DateTime) clock;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 66, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(clock(program.start), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent)),
              const SizedBox(height: 4),
              Text(clock(program.end), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(program.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (program.description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(program.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.35)),
              ],
              if (program.isOnNow) ...[
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(100), child: LinearProgressIndicator(value: program.progressPercent / 100, minHeight: 4, color: AppTheme.accent, backgroundColor: AppTheme.surfaceRaised)),
              ],
            ])),
            if (program.isOnNow) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.circle, size: 8, color: Color(0xFFE84D61))),
          ]),
        ),
      );
}
