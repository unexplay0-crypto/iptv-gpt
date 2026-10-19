# Arquitetura do UNEX Vision

## Camadas

- **UI (`screens/`, `widgets/`)**: telas adaptativas para celular e Android TV; nenhum widget monta endpoints IPTV por conta própria.
- **Estado (`controllers/app_controller.dart`)**: sessão ativa, catálogo, filtros, favoritos, histórico, progresso, EPG e configurações.
- **Domínio (`models/`)**: conta/fonte, mídia e programação EPG com identidade estável.
- **Serviços (`services/`)**: parser M3U, Xtream API, download de playlist, XMLTV, metadados, atualização e persistência.
- **Plataforma Android (`tooling/configure_android.py`)**: configura o Manifest gerado pelo Flutter para o app aparecer no launcher de Android TV, sem exigir touchscreen.
- **CI (`.github/workflows/`)**: prepara o scaffold nativo Android, baixa dependências, formata, analisa, testa e compila APK/AAB.

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
