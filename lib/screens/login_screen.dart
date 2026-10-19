import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _playlist = TextEditingController();
  final _epg = TextEditingController();
  bool _useXtream = true;
  bool _obscurePassword = true;
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _playlist.dispose();
    _epg.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_useXtream && !_formKey.currentState!.validate()) return;
    if (!_useXtream && _playlist.text.trim().isEmpty) {
      setState(() => _error = 'Informe a URL M3U ou importe um arquivo.');
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      if (_useXtream) {
        await widget.controller.connectXtream(
          serverUrl: _server.text,
          username: _username.text,
          password: _password.text,
          epgUrl: _epg.text,
        );
      } else {
        await widget.controller.connectM3uUrl(playlistUrl: _playlist.text, epgUrl: _epg.text);
      }
    } catch (_) {
      if (mounted) setState(() => _error = widget.controller.errorMessage ?? 'Não foi possível conectar. Confira os dados.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['m3u', 'm3u8', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FormatException('Não foi possível ler o arquivo selecionado.');
      final content = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _isBusy = true;
        _error = null;
      });
      await widget.controller.connectM3uFile(filename: file.name, contents: content, epgUrl: _epg.text);
    } catch (error) {
      if (mounted) setState(() => _error = error is FormatException ? error.message.toString() : widget.controller.errorMessage ?? 'Falha ao importar a lista.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Este campo é obrigatório.' : null;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tvLayout = width >= 900;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.8),
                  radius: 1.2,
                  colors: [AppTheme.accent.withValues(alpha: 0.14), AppTheme.background, AppTheme.background],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: tvLayout ? 30 : 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 570),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentSecondary]),
                            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.20), blurRadius: 30)],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF051015), size: 49),
                        ),
                      ),
                      const SizedBox(height: 21),
                      const Text('UNEX VISION', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
                      const SizedBox(height: 8),
                      const Text('Seu conteúdo, em uma só tela.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(tvLayout ? 26 : 18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Conectar sua lista', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text('Use uma conta Xtream Codes ou uma lista M3U/M3U8.', style: TextStyle(color: AppTheme.textMuted)),
                                const SizedBox(height: 21),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(value: true, label: Text('Xtream Codes'), icon: Icon(Icons.dns_rounded)),
                                    ButtonSegment(value: false, label: Text('Lista M3U'), icon: Icon(Icons.link_rounded)),
                                  ],
                                  selected: {_useXtream},
                                  onSelectionChanged: _isBusy ? null : (set) => setState(() { _useXtream = set.first; _error = null; }),
                                  showSelectedIcon: false,
                                ),
                                const SizedBox(height: 18),
                                if (_useXtream) ...[
                                  TextFormField(
                                    controller: _server,
                                    validator: _required,
                                    keyboardType: TextInputType.url,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(labelText: 'Servidor / DNS', hintText: 'https://servidor.exemplo:8080', prefixIcon: Icon(Icons.dns_outlined)),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _username,
                                    validator: _required,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(labelText: 'Usuário', prefixIcon: Icon(Icons.person_outline_rounded)),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _password,
                                    validator: _required,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Senha',
                                      prefixIcon: const Icon(Icons.key_rounded),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  TextFormField(
                                    controller: _playlist,
                                    keyboardType: TextInputType.url,
                                    validator: _required,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(labelText: 'URL da playlist M3U', hintText: 'https://servidor/lista.m3u', prefixIcon: Icon(Icons.link_rounded)),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(onPressed: _isBusy ? null : _importFile, icon: const Icon(Icons.upload_file_rounded), label: const Text('Importar arquivo M3U/M3U8')),
                                ],
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _epg,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(labelText: 'URL do EPG XMLTV (opcional)', prefixIcon: Icon(Icons.calendar_month_rounded)),
                                ),
                                if (_error != null || widget.controller.errorMessage != null) ...[
                                  const SizedBox(height: 15),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: const Color(0xFF421F27), borderRadius: BorderRadius.circular(12)),
                                    child: Text(_error ?? widget.controller.errorMessage!, style: const TextStyle(color: Color(0xFFFFB4BD))),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _isBusy ? null : _connect,
                                  icon: _isBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded),
                                  label: Text(_isBusy ? 'Conectando…' : 'Conectar e carregar conteúdo'),
                                ),
                                const SizedBox(height: 14),
                                const Text('A qualidade, disponibilidade e os direitos de acesso dependem do provedor da sua lista.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text('UNEX VISION  •  Mobile + Android TV', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
