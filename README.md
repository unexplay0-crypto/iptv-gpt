# IPTV — UNEX Vision (Flutter / Android + Android TV)

Projeto Flutter preparado para compilar APK e AAB via GitHub Actions. A interface é adaptativa para celular, TV Box e Android TV: navegação por toque, teclado e controle remoto (D-pad), foco de alto contraste, catálogos em carrosséis/grades e player em tela cheia.

> **Estado honesto da entrega:** os arquivos-fonte, testes, configurações e workflows foram gerados nesta entrega. O ambiente usado para gerar o pacote não contém Flutter/Dart SDK, então `flutter pub get`, `flutter analyze`, `flutter test` e a compilação ainda não foram executados aqui. O primeiro workflow no GitHub é o mecanismo previsto para realizar essas verificações e revelar qualquer incompatibilidade restante.

## Funcionalidades nesta base

- Login por **Xtream Codes** (DNS/servidor, usuário, senha) e por **URL M3U/M3U8**.
- Importação de playlist M3U/M3U8 do armazenamento local.
- Parser M3U que preserva nomes com vírgulas, acentos, atributos em ordens diferentes, query strings e cabeçalhos `EXTVLCOPT` para User-Agent/Referer.
- Catálogo de canais ao vivo, filmes e séries com busca, filtro por categoria, capas, descrição, ano e agrupamento.
- Xtream API: autenticação, categorias, canais, VOD, séries e carregamento de episódios por temporada.
- Player baseado no `video_player` oficial, usando o mecanismo nativo Android/ExoPlayer, controles próprios, tela cheia, pausa/retomada, seek VOD, troca rápida de canais, retry limitado por ação, timeout de inicialização e diagnósticos de erro sem exibir a URL completa.
- EPG do endpoint Xtream e suporte opcional a XMLTV externo, incluindo decodificação defensiva de campos Base64.
- Favoritos, histórico e progresso VOD separados por provedor/conta.
- Sessão, URL de playlist e histórico com URL de reprodução armazenados em armazenamento seguro; preferências persistentes para favoritos e progresso guardam somente IDs e valores simples.
- Filtro de conteúdo adulto, PIN parental numérico com salt e hash, e exigência de PIN para liberar conteúdo identificado como adulto.
- Enriquecimento opcional de metadados via TMDb, usando chave fornecida pelo próprio usuário; nenhuma chave de API é embutida no código.
- Verificação de versão publicada no GitHub Releases e abertura do APK de release para download manual.
- CI para `dart format`, `flutter analyze`, `flutter test`, APK release e AAB. Criar uma tag `v1.0.0` (ou maior) publica os artefatos no GitHub Releases.

## Arquitetura

```text
lib/
  main.dart                      Inicialização, tema e roteamento inicial
  core/                           Constantes e design system
  models/                         Conta, mídia e programa de EPG
  controllers/app_controller.dart Estado de sessão, catálogo e ações de usuário
  services/                       Xtream, M3U, XMLTV, metadados, armazenamento e updates
  screens/                        Login, navegação, home, catálogo, player, série, guia e ajustes
  widgets/                        Cards e prateleiras de conteúdo

test/                             Testes de parsing, URLs Xtream, XMLTV e PIN
.github/workflows/                Build CI e publicação de release
```

## Publicar no repositório existente

Este pacote está alinhado ao repositório informado: `https://github.com/unexplay0-crypto/IPTV-APP`.

1. Extraia o ZIP e abra a pasta raiz `IPTV/`.
2. Substitua/adapte os arquivos no repositório, preservando a estrutura `.github`, `lib`, `test`, `tooling`, `pubspec.yaml` e `README.md`. Revise as alterações antes de confirmar o commit.
3. Aguarde o workflow **Build Android APK and AAB** em **Actions**. Ao concluir, baixe o artefato `UNEX-Vision-Android`.

A configuração de atualização do app consulta os releases desse repositório. A consulta de releases é pública; se o repositório permanecer privado, o recurso de atualização não funcionará sem autenticação adicional.

## Compilar localmente

Instale uma versão estável do Flutter/Dart e o Android SDK. Depois, na raiz do projeto:

```bash
SCAFFOLD="$(mktemp -d)/iptv-scaffold"
flutter create --no-pub --platforms=android --org com.unexplay --project-name iptv "$SCAFFOLD"
cp -R "$SCAFFOLD/android" ./android
python3 tooling/configure_android.py android/app/src/main/AndroidManifest.xml
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

O workflow do GitHub cria a pasta `android/` durante a execução caso ela não esteja versionada. Para Android TV, a rotina ajusta o Manifest para expor o app ao launcher Leanback, não exigir touchscreen, manter navegação por controle remoto e definir `minSdk` Android 24 (Android 7.0) pelas dependências atuais.

## Publicar uma versão baixável

Depois que `main` estiver funcionando, crie e envie uma tag, por exemplo:

```bash
git tag v1.0.0
git push origin v1.0.0
```

O workflow de release compila APK/AAB e publica ambos no GitHub Releases. O app consegue consultar essa página e abrir o link do APK; a instalação continua sendo confirmada pelo Android e não é silenciosa. A consulta de releases é pública, portanto o recurso de atualização não funciona sem autenticação quando o repositório permanece privado.

**Assinatura de produção:** o build automático inicial é voltado a testes/sideload. Para distribuir atualizações sobre uma instalação existente ou publicar no Google Play, configure uma chave de assinatura de release persistente em Secrets e use a mesma chave em cada versão. Não compartilhe nem versione arquivos `.jks` ou senhas. O build não configura essa chave por conta própria.

## Compatibilidade de rede e segurança

- HTTPS é preferível. O Manifest permite cleartext HTTP para compatibilidade com provedores IPTV legados, mas **HTTP não protege credenciais nem o conteúdo da transmissão**. Use-o apenas quando o provedor não oferecer HTTPS.
- As URLs completas de reprodução podem incluir credenciais em servidores Xtream. O app evita mostrá-las em mensagens de erro e guarda histórico/conta em armazenamento seguro, mas o próprio provedor pode registrar acessos no seu servidor. A cópia de uma M3U importada de arquivo fica no diretório privado do aplicativo; essa cópia não recebe criptografia adicional por arquivo.
- O filtro parental é heurístico: identifica termos conhecidos em nomes/categorias. Ele não substitui controles parentais do dispositivo e pode deixar passar conteúdo mal rotulado.
- A chave TMDb é opcional e configurada pelo usuário; confirme os termos e limites de uso do serviço antes de habilitá-la.
- Atualizações são baixadas de GitHub Releases. O usuário confirma a instalação do APK; atualizações silenciosas exigiriam uma distribuição gerenciada com assinatura e permissões apropriadas.

## Testes manuais obrigatórios antes de distribuir

Consulte [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md). Ainda é necessário testar um canal ao vivo, um VOD e um episódio reais em celular Android e Android TV/TV Box, incluindo credenciais especiais, URLs HTTP/HTTPS, erro 401/403/404, rede instável, controle remoto, PIN, cache e retomada. A compilação bem-sucedida não prova que todo provedor IPTV é compatível.
