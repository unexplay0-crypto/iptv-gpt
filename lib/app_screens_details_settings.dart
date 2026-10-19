import 'package:flutter/material.dart';
import 'package:iptv/app_controller.dart';
import 'package:iptv/app_core.dart';
import 'package:iptv/app_services.dart';
import 'package:iptv/app_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

// ---- Merged from screens/series_detail_screen.dart ----

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
    final episodesBySeason = <int, List<MediaItem>>{};
    for (final episode in _episodes) {
      episodesBySeason.putIfAbsent(episode.seasonNumber, () => []).add(episode);
    }
    final seasons = episodesBySeason.keys.toList()..sort();
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
          ...seasons.map((season) {
            final seasonEpisodes = episodesBySeason[season]!;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                initiallyExpanded: season == seasons.first,
                leading: const Icon(Icons.video_library_rounded, color: AppTheme.accent),
                title: Text(season == 0 ? 'Episódios' : 'Temporada ${season.toString().padLeft(2, '0')}'),
                subtitle: Text('${seasonEpisodes.length} ${seasonEpisodes.length == 1 ? 'episódio' : 'episódios'}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                children: seasonEpisodes.map((episode) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 54,
                    height: 44,
                    decoration: BoxDecoration(color: AppTheme.surfaceRaised, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: Text('E${episode.episodeNumber.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: episode.description.isEmpty ? null : Text(episode.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.accent, size: 27),
                  onTap: () => widget.onPlay(episode),
                )).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---- Merged from screens/settings_screen.dart ----

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller, required this.onLogout});
  final AppController controller;
  final VoidCallback onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _epg;
  late final TextEditingController _tmdb;
  bool _busy = false;
  bool _parentalBusy = false;

  @override
  void initState() {
    super.initState();
    _epg = TextEditingController(text: widget.controller.account?.epgUrl ?? '');
    _tmdb = TextEditingController(text: widget.controller.tmdbApiKey);
  }

  @override
  void dispose() {
    _epg.dispose();
    _tmdb.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), behavior: SnackBarBehavior.floating));
  }

  String _safeServerLabel(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return 'Servidor configurado';
    return uri.replace(userInfo: '', query: null, fragment: null).toString();
  }

  Future<String?> _askPin({required String title, String label = 'PIN parental'}) async {
    final pin = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(labelText: label, counterText: ''),
            validator: (value) => value == null || !RegExp(r'^\d{4,8}$').hasMatch(value) ? 'Use de 4 a 8 números.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(dialogContext, pin.text); }, child: const Text('Confirmar')),
        ],
      ),
    );
    pin.dispose();
    return result;
  }

  Future<void> _changePin() async {
    if (_parentalBusy) return;
    setState(() => _parentalBusy = true);
    try {
    final hasPin = await widget.controller.hasParentalPin();
    if (hasPin) {
      final existing = await _askPin(title: 'Confirmar PIN atual', label: 'PIN atual');
      if (existing == null) return;
      if (!await widget.controller.verifyParentalPin(existing)) {
        _message('PIN incorreto. O PIN não foi alterado.');
        return;
      }
    }
    if (!mounted) return;
    final first = TextEditingController();
    final second = TextEditingController();
    final form = GlobalKey<FormState>();
    final newPin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(hasPin ? 'Alterar PIN parental' : 'Criar PIN parental'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: first, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Novo PIN', counterText: ''), validator: (value) => value == null || !RegExp(r'^\d{4,8}$').hasMatch(value) ? 'Use de 4 a 8 números.' : null),
            const SizedBox(height: 12),
            TextFormField(controller: second, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Confirmar PIN', counterText: ''), validator: (value) => value != first.text ? 'Os PINs não são iguais.' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(dialogContext, first.text); }, child: const Text('Salvar PIN')),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    if (newPin == null) return;
    await widget.controller.setParentalPin(newPin);
    _message('PIN parental salvo com segurança.');
    } catch (_) {
      _message('Não foi possível salvar o PIN. Verifique o armazenamento do aparelho e tente novamente.');
    } finally {
      if (mounted) setState(() => _parentalBusy = false);
    }
  }

  Future<void> _toggleAdult(bool show) async {
    if (_parentalBusy) return;
    setState(() => _parentalBusy = true);
    try {
    if (!show) {
      await widget.controller.setAdultVisibility(false);
      _message('Conteúdo adulto bloqueado.');
      return;
    }
    final hasPin = await widget.controller.hasParentalPin();
    if (!hasPin) {
      _message('Configure primeiro um PIN parental para liberar conteúdo adulto.');
      return;
    }
    final input = await _askPin(title: 'Liberar conteúdo adulto');
    if (input == null) return;
    if (!await widget.controller.verifyParentalPin(input)) {
      _message('PIN incorreto. O conteúdo adulto continuará bloqueado.');
      return;
    }
    await widget.controller.setAdultVisibility(true);
    _message('Conteúdo adulto liberado nesta conta.');
    } catch (_) {
      _message('Não foi possível alterar o controle parental. Tente novamente.');
    } finally {
      if (mounted) setState(() => _parentalBusy = false);
    }
  }

  Future<void> _saveEpg() async {
    final value = _epg.text.trim();
    if (value.isNotEmpty) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.host.isEmpty || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
        _message('Informe uma URL XMLTV válida usando HTTP ou HTTPS.');
        return;
      }
    }
    await widget.controller.updateEpgUrl(value);
    _message('Fonte do EPG salva.');
  }

  Future<void> _saveTmdb() async {
    await widget.controller.saveTmdbApiKey(_tmdb.text.trim());
    _message('Configuração de metadados salva.');
  }

  Future<void> _checkUpdates() async {
    setState(() => _busy = true);
    try {
      final info = await widget.controller.checkForUpdate();
      if (!mounted || info == null) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Versão ${info.tag} disponível'),
          content: Text(info.notes.isEmpty ? 'Consulte as notas da versão e baixe o APK publicado oficialmente.' : info.notes, maxLines: 8, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
            FilledButton.icon(
              onPressed: () async {
                final url = info.apkUrl.isNotEmpty ? info.apkUrl : info.releaseUrl;
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(info.apkUrl.isNotEmpty ? 'Baixar APK' : 'Abrir versão'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(error is UpdateException ? error.message : 'Não foi possível consultar atualizações.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trocar de conta?'),
        content: const Text('A sessão atual será removida deste dispositivo. Seus favoritos e histórico local dessa conta serão mantidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Trocar conta')),
        ],
      ),
    );
    if (confirm == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.controller.account;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 1100 ? 1000.0 : double.infinity;
    return ListView(
      padding: EdgeInsets.fromLTRB(width >= 900 ? 34 : 18, 22, width >= 900 ? 34 : 18, 35),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Configurações', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('Conta, proteção e preferências de reprodução.', style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 23),
              _SectionTitle(title: 'Conta conectada'),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.account_circle_rounded, color: AppTheme.accent, size: 29)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(account?.label ?? 'Sem conta', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text(_sourceLabel(account?.source.name), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))])),
                ]),
                if (account?.source.name == 'xtream') ...[
                  const SizedBox(height: 14),
                  Text('Servidor: ${_safeServerLabel(account!.serverUrl)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  Text('Usuário: ${account.username}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
                const SizedBox(height: 15),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  OutlinedButton.icon(onPressed: _busy ? null : () async { setState(() => _busy = true); try { await widget.controller.refreshCatalog(); _message('Catálogo atualizado.'); } catch (_) { _message(widget.controller.errorMessage ?? 'Falha ao atualizar catálogo.'); } finally { if (mounted) setState(() => _busy = false); } }, icon: const Icon(Icons.refresh_rounded), label: const Text('Atualizar catálogo')),
                  OutlinedButton.icon(onPressed: _busy ? null : _checkUpdates, icon: const Icon(Icons.system_update_alt_rounded), label: const Text('Verificar atualização')),
                  OutlinedButton.icon(onPressed: _confirmLogout, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Trocar conta')),
                ]),
                if (_busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
              ]))),
              const SizedBox(height: 20),
              _SectionTitle(title: 'EPG / Guia de programação'),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fonte XMLTV externa (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Use uma URL XMLTV para completar o guia quando o provedor não fornecer programação pelo Xtream.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
                const SizedBox(height: 14),
                TextField(controller: _epg, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL do arquivo XMLTV', prefixIcon: Icon(Icons.calendar_month_rounded))),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(onPressed: _saveEpg, icon: const Icon(Icons.save_rounded), label: const Text('Salvar EPG'))),
              ]))),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Controle parental'),
              Card(child: Column(children: [
                SwitchListTile.adaptive(
                  value: widget.controller.showAdultContent,
                  onChanged: _parentalBusy ? null : _toggleAdult,
                  secondary: const Icon(Icons.shield_rounded, color: AppTheme.accent),
                  title: const Text('Mostrar conteúdo adulto'),
                  subtitle: Text(widget.controller.showAdultContent ? 'Conteúdo adulto está liberado nesta conta.' : 'Conteúdo identificado como adulto fica oculto.', style: const TextStyle(color: AppTheme.textMuted)),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: Text(_parentalBusy ? 'Salvando controle parental…' : 'Configurar / alterar PIN'),
                  subtitle: const Text('PIN numérico de 4 a 8 dígitos', style: TextStyle(color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _parentalBusy ? null : _changePin,
                ),
              ])),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Metadados de filmes e séries'),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Chave opcional da API do TMDb', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('O aplicativo não inclui uma chave de terceiros. Sem chave, usa os metadados enviados pelo provedor IPTV.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
                const SizedBox(height: 14),
                TextField(controller: _tmdb, obscureText: true, decoration: const InputDecoration(labelText: 'API key do TMDb', prefixIcon: Icon(Icons.movie_filter_rounded))),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(onPressed: _saveTmdb, icon: const Icon(Icons.save_rounded), label: const Text('Salvar chave'))),
              ]))),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Sobre'),
              Card(child: const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: AppTheme.accent),
                title: Text(AppConstants.appName),
                subtitle: Text('Versão ${AppConstants.version}\nPlayer Android nativo via video_player / ExoPlayer.', style: TextStyle(color: AppTheme.textMuted, height: 1.5)),
              )),
              const SizedBox(height: 15),
              const Text('Use apenas listas e fluxos para os quais você tenha autorização de acesso. Prefira HTTPS; conexões HTTP não criptografam credenciais nem tráfego.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.45)),
            ]),
          ),
        ),
      ],
    );
  }

  String _sourceLabel(String? source) => switch (source) {
        'xtream' => 'Xtream Codes API',
        'm3uUrl' => 'Playlist M3U por URL',
        'm3uFile' => 'Arquivo M3U local',
        _ => 'Desconectado',
      };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)));
}
