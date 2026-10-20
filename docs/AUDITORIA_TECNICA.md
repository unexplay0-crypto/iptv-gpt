# Auditoria técnica do pacote UNEX Vision / IPTV

**Escopo:** revisão estática do código presente neste ZIP, incluindo `lib/`, `test/`, `pubspec.yaml`, `analysis_options.yaml`, workflows e o script de configuração Android.

**Limitação de validação:** Flutter e Dart SDK não estão instalados no ambiente desta revisão. Portanto, esta auditoria não afirma que `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, APK ou AAB tenham sido executados com sucesso. Os itens abaixo combinam defeitos identificados por inspeção e verificações que ainda precisam ser realizadas em ambiente Flutter.

## Correções aplicadas neste pacote

1. **API de importação de arquivo incompatível** — a variante mais recente do pacote usava `FilePicker.pickFile`, que não corresponde à API moderna de `file_picker`. O fluxo foi atualizado para `FilePicker.platform.pickFiles`, leitura de `bytes` quando disponível e fallback para o caminho local. A variante-base já importava `dart:io` no controller; esse import foi preservado.
2. **Desbloqueio parental persistente** — o estado de exibição de conteúdo adulto era restaurado das preferências, permitindo que o desbloqueio sobrevivesse ao encerramento/reabertura do app. Agora `_loadLibraryState` inicia sempre com conteúdo adulto bloqueado e grava `false`; a pessoa precisa confirmar o PIN novamente para desbloquear durante a sessão.
3. **Repositório de atualizações inconsistente** — o app consultava `unexplay0-crypto/IPTV`, embora o endereço informado para o projeto seja `unexplay0-crypto/IPTV-APP`. A constante e a instrução do README foram alinhadas ao endereço informado.
4. **Correspondência de EPG por nome** — a implementação comparava o nome do canal diretamente com o atributo `channel` dos programas XMLTV, que normalmente é um ID. Agora lê `<channel><display-name>` e usa os nomes para correspondência alternativa quando o `tvg-id` não resolve.
5. **Corrida ao trocar de canal rapidamente** — uma tentativa antiga de inicialização do player podia continuar depois de uma troca e interferir na nova tentativa. Foi adicionada uma verificação da geração após a espera pela liberação do player anterior.
6. **Corrida ao selecionar canais no guia** — uma resposta lenta de um canal selecionado anteriormente podia sobrescrever o EPG do canal atual. A tela agora ignora respostas de requisições antigas.

## Achados que continuam exigindo atenção

### Alta prioridade

- **Dependências não validadas por resolução real:** o ZIP não contém `pubspec.lock`. Sem lockfile, execuções futuras podem resolver versões transitivas diferentes. Gerar e revisar o lockfile com a versão de Flutter/Dart escolhida antes de distribuir.
- **Fluxos IPTV não testados com provedores reais:** a construção de URLs Xtream, autenticação, formatos de stream e suporte a cabeçalhos dependem do servidor. Os testes existentes cobrem construção de URI, mas não autenticação real nem reprodução.
- **Proteção parental baseada em hash rápido:** o PIN de 4–8 dígitos é armazenado como SHA-256 com salt em preferências. SHA-256 não é uma função de derivação lenta; um atacante com acesso aos dados locais pode tentar adivinhar PINs offline. Para uma proteção mais forte, usar KDF apropriada com custo configurável e manter o armazenamento protegido pelo sistema operacional. O bloqueio por tentativas no app ajuda contra uso casual, mas não é defesa contra alteração local das preferências.

### Média prioridade

- **Limite XMLTV aplicado globalmente:** `maxEpgPrograms` limita os primeiros 8.000 elementos `programme` do documento inteiro, não 8.000 por canal. Em arquivos grandes, canais que aparecem mais tarde podem ficar sem EPG. Rever a estratégia de leitura/limite e testar com XMLTV realista.
- **Limite de tamanho XMLTV verificado após download:** o limite de 80 MB é verificado depois que a resposta inteira já foi recebida em memória. Para reduzir risco de consumo excessivo de memória/rede, limitar bytes durante a leitura do stream HTTP.
- **Playlist M3U sem limite de tamanho durante o download:** a playlist é recebida inteira antes do parsing e não há limite de bytes/itens. Uma URL maliciosa ou lista excessiva pode consumir muita memória. Implementar limites de download e de quantidade de itens.
- **Erros de ações Xtream podem ser silenciosos:** `_tryAction` transforma qualquer exceção em `null`. Isso permite catálogo parcial, mas dificulta diferenciar endpoint não suportado de falha de rede, credenciais ou servidor. Registrar um estado de falha sanitizado e mostrar aviso de catálogo parcial.
- **Formatação no CI não é uma verificação:** `dart format lib test` modifica os arquivos no runner em vez de falhar quando o repositório contém arquivos não formatados. Depois de formatar localmente com SDK compatível, preferir `dart format --output=none --set-exit-if-changed lib test`.
- **Cobertura de testes ainda pequena:** existem testes de parser M3U, URI Xtream, decodificação XMLTV e comparação de hash, mas faltam testes de `AppController`, isolamento entre contas, fluxo de PIN/desbloqueio, concorrência do player/guia, falhas HTTP e parser XMLTV completo.
- **EPG Xtream pode falhar silenciosamente:** quando a consulta ao middleware falha, o controller tenta XMLTV ou retorna lista vazia; a interface não distingue sempre “sem programação” de “falha ao consultar”.

### Baixa prioridade / manutenção

- `LocalLibraryStore` mantém métodos de histórico (`readHistory`/`writeHistory`) que não são usados pelo fluxo atual, pois o histórico ativo é guardado em `SecureAccountStore`. Remover ou documentar a estratégia para evitar duas fontes de verdade.
- `PlayerScreen._onTick` chama `setState` a cada atualização do player. Considerar isolar a atualização do progresso/controles para evitar reconstruir toda a tela em alta frequência.
- O arquivo `.gitignore` exclui `android/`, e o workflow gera o scaffold nativo a cada execução. Isso é funcional como estratégia de geração, mas mudanças nativas manuais não persistirão se não forem versionadas ou aplicadas pelo script.
- `usesCleartextTraffic=true` habilita HTTP sem criptografia para compatibilidade com provedores legados. Preferir HTTPS e considerar uma Network Security Config mais restritiva se os provedores-alvo permitirem.

## Validação recomendada antes de distribuição

Executar, na raiz do projeto e com Flutter/Dart compatíveis com `pubspec.yaml`:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

Além dos comandos, cumprir os testes manuais descritos em `docs/TEST_PLAN.md`, em especial login Xtream, playlist M3U real, EPG, reprodução de live/VOD/episódios, troca rápida de canais, PIN parental após reiniciar o app e navegação por D-pad em Android TV.
