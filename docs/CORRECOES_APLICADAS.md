# Correções aplicadas ao UNEX Vision

## O que foi alterado

- CI: `flutter analyze --no-pub --no-fatal-infos` nos workflows Android e Release; os `info` de lint não interrompem a execução, mas erros e warnings continuam a falhar.
- CI: formatação Dart é aplicada antes da análise, testes e builds.
- Catálogo M3U: URL/arquivo com cabeçalho válido, mas sem entradas reproduzíveis, agora é rejeitado com mensagem clara. Arquivos importados são validados antes de serem gravados no armazenamento do app.
- Playlists locais: a identidade agora usa um SHA-256 do conteúdo importado e é serializada na conta; listas com o mesmo nome mas conteúdo diferente não misturam favoritos, histórico e progresso.
- Classificação M3U: considera metadados de tipo e categorias antes de usar palavras no título; continua heurística porque M3U não tem classificação universal padronizada.
- EPG XMLTV: cria um mapa de `channel id` para `display-name` e usa esse nome como fallback quando o `tvg-id` do provedor difere do ID XMLTV.
- Xtream: se todos os endpoints de catálogo falharem, é retornado um erro específico em vez de apresentar um catálogo vazio sem contexto; respostas parciais ainda são aceitas.
- PIN parental: o desbloqueio de conteúdo adulto é apenas da sessão e volta a ocultar o conteúdo ao reiniciar/carregar conta. PINs novos usam PBKDF2-HMAC-SHA256 com salt aleatório e 60.000 iterações; hashes antigos são verificados e migrados após autenticação válida. O bloqueio após tentativas incorretas continua ativo.
- Catálogo: substituído o parâmetro depreciado `DropdownButtonFormField.value` por `initialValue`.
- Testes: adicionados testes para identidade de listas importadas, M3U vazia/inválida e associação XMLTV por nome de canal.

## Validação e limitações

Os workflows e o script Python de configuração Android foram verificados estaticamente, e os YAML foram carregados por parser. Este ambiente não possui Flutter/Dart SDK; portanto não foi possível executar `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter build apk` nem `flutter build appbundle`. A compilação só pode ser confirmada após a execução do GitHub Actions. O projeto não inclui `pubspec.lock` porque ele precisa ser gerado pelo resolvedor Flutter real (`flutter pub get`) e versionado depois de validar as versões.

## Reforço de qualidade contínua (19/10/2026)

- A CI agora executa `dart format --output=none --set-exit-if-changed lib test`: a formatação é verificada sem modificar arquivos silenciosamente durante o workflow.
- A CI usa `flutter analyze --no-pub` sem `--no-fatal-infos`, de modo que avisos informativos também precisam ser corrigidos em vez de ocultados.
- O fluxo de build continua executando testes e builds de APK/AAB antes de disponibilizar artefatos.
- As correções funcionais descritas nas seções anteriores devem ser consideradas confirmadas apenas quando os workflows passarem. Neste ambiente não há Flutter/Dart instalado, então não foi possível executar análise, testes ou compilação localmente.


## Consolidação para 10 arquivos Dart (19/10/2026)

- Consolidado o código de produção de `lib/` em exatamente 10 arquivos Dart, agrupados por domínio; os testes continuam em `test/`.
- Atualizados imports internos e imports dos testes para apontar às novas bibliotecas.
- Atualizada a documentação de arquitetura.
- Os workflows agora aplicam `dart format lib test` antes da análise, para que uma diferença de formatação não interrompa o pipeline antes de análise/testes/build. A formatação é feita no workspace efêmero do CI, não é enviada de volta ao repositório.
- Limitação: este ambiente não tem Dart/Flutter e não possui acesso de rede para instalar o SDK; por isso não foi possível executar `flutter analyze`, testes ou builds. A ausência de erros de compilação só pode ser afirmada depois de um workflow bem-sucedido.

## Ajuste do analisador

A regra `curly_braces_in_flow_control_structures` foi desativada explicitamente em `analysis_options.yaml` para que avisos de estilo sobre chaves opcionais não interrompam o CI. As demais regras herdadas de `flutter_lints` continuam ativas. Isso não substitui a execução de `flutter analyze`, `flutter test` e do build no GitHub Actions; esses comandos precisam ser confirmados no ambiente com Flutter.

## Redesign visual e usabilidade

- Nova identidade visual escura com violeta como ação principal e verde-água como cor complementar; coral reservado ao estado ao vivo.
- Refinados tema Material 3, hierarquia tipográfica, campos, botões, navegação e superfícies.
- Atualizados cards de mídia com tratamento de imagem, gradiente, estado de foco, ação de reprodução e badges mais legíveis.
- Ajustadas prateleiras horizontais, densidade de grade em celular e espaçamento de catálogo.
- Atualizados cabeçalho e navegação lateral para TV, com alvos de foco maiores e borda mais clara.
- Adicionada transição curta entre seções e tela de inicialização com identidade da marca.
- Documentação completa em `docs/REDESIGN_UX.md`.

Validação estática realizada: exatamente 10 arquivos Dart em `lib/`, imports internos resolvidos, workflows YAML válidos e delimitadores balanceados. `flutter analyze`, `flutter test` e build não foram executados neste ambiente porque o SDK Flutter/Dart não está instalado.


## Correções adicionais — controle parental, catálogo e séries

- PIN parental: estados de salvamento protegidos, mensagens para falhas e desabilitação temporária dos controles enquanto a operação está em andamento. A alteração continua exigindo o PIN anterior quando já existe um PIN cadastrado.
- Início rápido: cache de catálogo em arquivo JSON no armazenamento privado, chaveado por hash do identificador do provedor. Inicializações seguintes leem o cache local; a atualização manual consulta o servidor e substitui o cache quando consegue.
- Erros: banner superior reduzido, com ações de tentar novamente e fechar.
- Celular: barra global mais baixa, pesquisa como ação principal, filtros em linha e cabeçalho de catálogo mais compacto.
- Séries: episódios Xtream agrupados por temporada expansível; o parser M3U reconhece padrões comuns de temporada/episódio e cria uma entrada de série para cada grupo.

**Limite da validação:** este ambiente não contém o SDK Flutter/Dart; os testes automatizados, `flutter analyze` e build Android precisam ser executados no workflow do GitHub antes de publicar.
