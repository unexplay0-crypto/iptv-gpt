import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/app_theme.dart';
import '../models/epg_program.dart';
import '../models/media_item.dart';

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
