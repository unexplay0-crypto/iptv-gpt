import 'package:flutter/material.dart';
import 'package:iptv/app_controller.dart';
import 'package:iptv/app_core.dart';
import 'package:iptv/app_player.dart';
import 'package:iptv/app_screens_auth_home.dart';
import 'package:iptv/app_screens_catalog_guide.dart';
import 'package:iptv/app_screens_details_settings.dart';

// ---- Merged from screens/shell_screen.dart ----

enum _Section { home, live, movies, series, search, favorites, history, guide, settings }

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  _Section _section = _Section.home;

  void _select(_Section value) => setState(() => _section = value);

  void _openSearch() => _select(_Section.search);

  Future<void> _refresh() async {
    try {
      await widget.controller.refreshCatalog();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.controller.errorMessage ?? 'Não foi possível atualizar o catálogo.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _playItem(MediaItem item) {
    final controller = widget.controller;
    final account = controller.account;
    if (item.type == MediaType.series && account?.source == IptvSource.xtream && item.seriesId.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SeriesDetailScreen(controller: controller, series: item, onPlay: _playItem),
      ));
      return;
    }
    if (!item.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este item não contém um endereço de reprodução válido.')));
      return;
    }
    final queue = item.type == MediaType.live
        ? controller.liveChannels
        : item.type == MediaType.movie
            ? controller.movies
            : <MediaItem>[item];
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(item: item, controller: controller, queue: queue),
    ));
  }

  Widget _buildPage(bool tvLayout) {
    final controller = widget.controller;
    switch (_section) {
      case _Section.home:
        return HomeScreen(
          live: controller.liveChannels,
          movies: controller.movies,
          series: controller.series,
          history: controller.history,
          favorites: controller.favorites,
          tvLayout: tvLayout,
          onPlay: _playItem,
          onSeeLive: () => _select(_Section.live),
          onSeeMovies: () => _select(_Section.movies),
          onSeeSeries: () => _select(_Section.series),
          onSeeFavorites: () => _select(_Section.favorites),
          onSeeHistory: () => _select(_Section.history),
          onRefresh: _refresh,
        );
      case _Section.live:
        return CatalogScreen(title: 'Canais ao vivo', subtitle: 'Seus canais organizados por categoria.', items: controller.liveChannels, onTap: _playItem);
      case _Section.movies:
        return CatalogScreen(title: 'Filmes', subtitle: 'Explore o catálogo de filmes do seu provedor.', items: controller.movies, onTap: _playItem);
      case _Section.series:
        return CatalogScreen(title: 'Séries', subtitle: 'Séries e temporadas disponíveis na sua lista.', items: controller.series, onTap: _playItem);
      case _Section.search:
        return CatalogScreen(title: 'Buscar conteúdo', subtitle: 'Pesquise por título ou categoria.', items: controller.allItems, onTap: _playItem, searchMode: true);
      case _Section.favorites:
        return CatalogScreen(title: 'Minha lista', subtitle: 'Conteúdos salvos como favoritos.', items: controller.favorites, onTap: _playItem);
      case _Section.history:
        return CatalogScreen(title: 'Continuar assistindo', subtitle: 'Conteúdos abertos recentemente neste perfil.', items: controller.history, onTap: _playItem);
      case _Section.guide:
        return GuideScreen(controller: controller, channels: controller.liveChannels, onPlay: _playItem, tvLayout: tvLayout);
      case _Section.settings:
        return SettingsScreen(controller: controller, onLogout: controller.logout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tvLayout = width >= 850;
    return Scaffold(
      body: Row(
        children: [
          if (tvLayout) _Sidebar(selected: _section, onSelect: _select),
          Expanded(
            child: SafeArea(
              left: false,
              child: Column(children: [
                _TopBar(onSearch: _openSearch, onSettings: () => _select(_Section.settings), onRefresh: _refresh, itemCount: widget.controller.totalItems, tvLayout: tvLayout),
                if (widget.controller.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.fromLTRB(tvLayout ? 30 : 14, 0, tvLayout ? 30 : 14, 7),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF40212A), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB4BD), size: 19),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.controller.errorMessage!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFD0D5), fontSize: 12))),
                      TextButton(onPressed: _refresh, child: const Text('Tentar')),
                    ]),
                  ),
                if (widget.controller.isLoading) const LinearProgressIndicator(minHeight: 2, color: AppTheme.accent, backgroundColor: AppTheme.surface),
                Expanded(child: _buildPage(tvLayout)),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: tvLayout
          ? null
          : NavigationBar(
              selectedIndex: _mobileIndex(_section),
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    _select(_Section.home);
                    break;
                  case 1:
                    _select(_Section.live);
                    break;
                  case 2:
                    _select(_Section.movies);
                    break;
                  case 3:
                    _select(_Section.series);
                    break;
                  case 4:
                    _showMore();
                    break;
                }
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
                NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv_rounded), label: 'Ao vivo'),
                NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie_rounded), label: 'Filmes'),
                NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Séries'),
                NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Mais'),
              ],
            ),
    );
  }

  int _mobileIndex(_Section section) => switch (section) {
        _Section.home => 0,
        _Section.live => 1,
        _Section.movies => 2,
        _Section.series => 3,
        _ => 4,
      };

  Future<void> _showMore() async {
    final selected = await showModalBottomSheet<_Section>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _MoreTile(icon: Icons.search_rounded, label: 'Buscar conteúdo', onTap: () => Navigator.pop(context, _Section.search)),
          _MoreTile(icon: Icons.favorite_border_rounded, label: 'Minha lista / Favoritos', onTap: () => Navigator.pop(context, _Section.favorites)),
          _MoreTile(icon: Icons.history_rounded, label: 'Continuar assistindo', onTap: () => Navigator.pop(context, _Section.history)),
          _MoreTile(icon: Icons.calendar_month_rounded, label: 'Guia de programação', onTap: () => Navigator.pop(context, _Section.guide)),
          _MoreTile(icon: Icons.settings_outlined, label: 'Configurações', onTap: () => Navigator.pop(context, _Section.settings)),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (selected != null && mounted) _select(selected);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearch, required this.onSettings, required this.onRefresh, required this.itemCount, required this.tvLayout});
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;
  final int itemCount;
  final bool tvLayout;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: tvLayout ? 76 : 62,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tvLayout ? 31 : 13),
          child: Row(children: [
            if (!tvLayout) ...[
              Container(width: 31, height: 31, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24)),
              const SizedBox(width: 10),
              const Text('UNEX VISION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 13)),
            ] else
              Text('UNEX VISION', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (tvLayout) Padding(padding: const EdgeInsets.only(right: 16), child: Text('$itemCount itens', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            IconButton(onPressed: onSearch, tooltip: 'Buscar', icon: const Icon(Icons.search_rounded)),
            IconButton(onPressed: onRefresh, tooltip: 'Atualizar lista', icon: const Icon(Icons.refresh_rounded)),
            IconButton(onPressed: onSettings, tooltip: 'Configurações', icon: const Icon(Icons.settings_outlined)),
          ]),
        ),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});
  final _Section selected;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: 238,
        decoration: const BoxDecoration(color: Color(0xFF0B1017), border: Border(right: BorderSide(color: Color(0xFF202B36)))),
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 22, 18, 26),
              child: Row(children: [
                Container(width: 41, height: 41, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 33)),
                const SizedBox(width: 11),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('UNEX VISION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)), SizedBox(height: 4), Text('ENTRETENIMENTO', style: TextStyle(color: AppTheme.textMuted, fontSize: 9, letterSpacing: 1.1))])),
              ]),
            ),
            const _SideSectionLabel('DESCOBRIR'),
            _SideItem(icon: Icons.home_rounded, label: 'Início', value: _Section.home, selected: selected, onSelect: onSelect),
            _SideItem(icon: Icons.live_tv_rounded, label: 'Ao vivo', value: _Section.live, selected: selected, onSelect: onSelect),
            _SideItem(icon: Icons.movie_rounded, label: 'Filmes', value: _Section.movies, selected: selected, onSelect: onSelect),
            _SideItem(icon: Icons.video_library_rounded, label: 'Séries', value: _Section.series, selected: selected, onSelect: onSelect),
            _SideItem(icon: Icons.search_rounded, label: 'Buscar', value: _Section.search, selected: selected, onSelect: onSelect),
            const SizedBox(height: 22),
            const _SideSectionLabel('SUA BIBLIOTECA'),
            _SideItem(icon: Icons.favorite_outline_rounded, label: 'Minha lista', value: _Section.favorites, selected: selected, onSelect: onSelect),
            _SideItem(icon: Icons.history_rounded, label: 'Continuar assistindo', value: _Section.history, selected: selected, onSelect: onSelect),
            _SideItem(icon: Icons.calendar_month_rounded, label: 'Guia de TV', value: _Section.guide, selected: selected, onSelect: onSelect),
            const Spacer(),
            const Divider(indent: 17, endIndent: 17),
            _SideItem(icon: Icons.settings_outlined, label: 'Configurações', value: _Section.settings, selected: selected, onSelect: onSelect),
            const Padding(padding: EdgeInsets.fromLTRB(24, 10, 24, 18), child: Text('Versão 1.0.0', style: TextStyle(fontSize: 10, color: AppTheme.textMuted))),
          ]),
        ),
      );
}

class _SideSectionLabel extends StatelessWidget {
  const _SideSectionLabel(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(24, 5, 18, 9), child: Text(value, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, letterSpacing: 1.35, fontWeight: FontWeight.w900)));
}

class _SideItem extends StatefulWidget {
  const _SideItem({required this.icon, required this.label, required this.value, required this.selected, required this.onSelect});
  final IconData icon;
  final String label;
  final _Section value;
  final _Section selected;
  final ValueChanged<_Section> onSelect;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.selected == widget.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: Material(
          color: active || _focused ? AppTheme.accent.withValues(alpha: active ? 0.14 : 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => widget.onSelect(widget.value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 47,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _focused ? AppTheme.accent : Colors.transparent, width: 1.5)),
              child: Row(children: [
                Icon(widget.icon, size: 19, color: active || _focused ? AppTheme.accent : AppTheme.textMuted),
                const SizedBox(width: 13),
                Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? Colors.white : AppTheme.textMuted))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: AppTheme.accent), title: Text(label), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap);
}
