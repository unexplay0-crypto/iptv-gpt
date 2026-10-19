# Plano de testes e aceitação

> Testes automatizados e builds precisam ser executados em ambiente com Flutter/Dart e Android SDK. A geração deste pacote não executou o SDK; não considerar os cenários abaixo como aprovados até haver evidência de execução.

## Automatizados (GitHub Actions)

- `flutter pub get`
- `dart format lib test`
- `flutter analyze --no-pub`
- `flutter test --no-pub`
- `flutter build apk --release --no-pub`
- `flutter build appbundle --release --no-pub`

## Login e playlist

- [ ] Xtream Codes com credenciais comuns.
- [ ] Credenciais contendo `@`, `:`, `/`, `?`, `#`, `&`, `+` e espaços; verificar que cada valor chega ao parâmetro correto.
- [ ] M3U por HTTP, HTTPS e arquivo local; playlist vazia, arquivo inválido e resposta HTTP 401/403/404/500.
- [ ] EXTINF com vírgula no nome, acentos, atributos reordenados, URLs com query string, grupos, User-Agent e Referer.
- [ ] Troca de conta: favoritos, histórico, progresso e estado parental isolados por provedor.
- [ ] Nenhum log, diálogo ou relatório exibe senha, token ou URL completa de stream.

## Player e reprodução real

- [ ] Canal ao vivo funcional confirmado em outro player.
- [ ] Filme VOD e episódio funcional.
- [ ] HLS/M3U8, MP4 e TS quando suportados pelo provedor/dispositivo.
- [ ] Pausa, play, sair e retornar; retomada de VOD; seek em VOD; não assumir seek em live.
- [ ] Trocar cinco canais rapidamente e tocar em várias opções durante inicialização.
- [ ] URL de stream 401/403/404, DNS indisponível, certificado TLS inválido, timeout, redirecionamento e rede interrompida.
- [ ] Verificar se controlador antigo não retoma nem altera o estado do stream novo.
- [ ] Validar mensagens claras e registro técnico sem dados sensíveis.

## EPG e catálogo

- [ ] EPG Xtream quando o servidor suporta `get_short_epg.php`.
- [ ] XMLTV válido, inválido, vazio, nomes codificados em Base64/texto comum, fuso horário e resposta não-2xx.
- [ ] Correspondência por `tvg-id` e nome do canal; sem programação fictícia apresentada como real.
- [ ] Busca, categoria vazia, listas grandes, erros de imagem, favoritos, recentes e continuar assistindo.
- [ ] Dados não se misturam entre duas contas com IDs iguais.

## PIN e armazenamento

- [ ] Configurar PIN de 4–8 dígitos, verificar PIN correto/incorreto, alterar e reiniciar o app.
- [ ] Cinco tentativas incorretas provocam bloqueio temporário; PIN correto remove o bloqueio após expirar ou após validação bem-sucedida.
- [ ] Dados corrompidos não encerram a aplicação; limpeza de conta não apaga favoritos indevidamente de outras contas.
- [ ] Inspecionar configurações de backup e armazenamento do Android; testar em aparelho real.

## Android TV / TV Box

- [ ] O app aparece no launcher Leanback.
- [ ] Fazer login usando apenas D-pad/OK/Voltar e teclado virtual.
- [ ] Foco visual forte em cada ação, sem foco perdido ao trocar de prateleira/tela.
- [ ] Abrir player, mostrar/ocultar controles, pausar, trocar canal, voltar e sair sem áudio duplicado.
- [ ] Margens de segurança/overscan, resolução, orientação, fontes e dispositivo de baixa memória.

## Resultado que a equipe deve registrar

Para cada falha, guardar modelo/dispositivo, versão Android, provedor, tipo de stream, estado de rede, código/categoria de erro sanitizada, resultado esperado, resultado observado e logs sem credenciais. Separar “compilou” de “o stream reproduziu corretamente”.
