# Arquitetura do UNEX Vision

## Organização compacta

O código de produção em `lib/` foi consolidado em dez arquivos Dart para atender ao limite solicitado, sem remover as classes públicas utilizadas pelas telas, serviços ou testes:

- `main.dart`: inicialização e widget raiz.
- `app_core.dart`: constantes, tema, conta, mídia e EPG.
- `app_controller.dart`: estado de sessão, catálogo, favoritos, histórico, EPG e configurações.
- `app_services.dart`: serviços M3U, Xtream, XMLTV, metadados, atualização e persistência.
- `app_widgets.dart`: cards e prateleiras de mídia.
- `app_screens_auth_home.dart`: login e home.
- `app_screens_catalog_guide.dart`: catálogo e guia.
- `app_screens_details_settings.dart`: detalhes de série e configurações.
- `app_player.dart`: player de vídeo.
- `app_shell.dart`: navegação e composição das telas.

Os testes permanecem em `test/` e importam as bibliotecas consolidadas. A consolidação não muda o modelo de dados ou o fluxo funcional intencionalmente; ela reduz a granularidade dos arquivos. Isso não é, por si só, garantia de menos erros, pois arquivos maiores são mais difíceis de revisar.

## Fluxo de dados

1. A pessoa informa uma conta Xtream Codes, uma URL M3U ou importa um ficheiro M3U/M3U8.
2. `AppController` delega autenticação/catálogo ao `XtreamService` ou leitura/parsing ao `PlaylistService` e `M3uParser`.
3. Os itens são normalizados em `MediaItem`; os IDs estáveis são derivados de provedor, URL e metadados para evitar colisões entre contas.
4. O layout apresenta categorias e prateleiras com o mesmo modelo de dados em celular e TV; o foco e os controles aumentam em telas grandes.
5. O player mantém um identificador de geração para invalidar tentativas assíncronas antigas, limita o tempo inicial e oferece retry acionado pela pessoa.
6. Favoritos/progresso guardam referências simples em preferências. Conta ativa, chave opcional TMDb e histórico com URLs de reprodução são guardados em armazenamento seguro do Android.

## Limites deliberados

- Não há backend de conteúdo embutido. A pessoa precisa fornecer um serviço/playlist ao qual tenha direito de acesso.
- M3U genérica pode não expor IDs de série/episódio de forma inequívoca; nesse caso a precisão depende dos metadados do provedor.
- XMLTV grande é parseado localmente; a primeira leitura pode consumir memória/tempo conforme o arquivo e o aparelho.
- O reconhecimento de conteúdo adulto é heurístico e configurável, não é filtro infalível.
- `video_player` aproveita o player de plataforma disponível no Android. Suporte real a contêineres, codecs, headers, redirecionamento, DRM e tipos de stream depende do servidor, do formato e da versão Android; não se promete que qualquer URL IPTV será reproduzida.
- A atualização abre o APK anexado ao GitHub Releases, mas o Android continua controlando a confirmação de instalação.

## CI

O workflow aplica `dart format lib test` no workspace de CI antes de executar `flutter analyze --no-pub`, `flutter test --no-pub` e os builds APK/AAB. A formatação no CI normaliza o código do checkout; não grava essas alterações no repositório remoto. A validação final depende de executar o workflow em um ambiente com Flutter/Dart instalado.
