# Plano de correção e aceite

## Fase 1 — Correções imediatas (incluídas neste ZIP)

- [x] Atualizar o seletor de arquivos para `FilePicker.platform.pickFiles` e preservar os imports necessários.
- [x] Tornar o desbloqueio de conteúdo adulto temporário e exigir PIN após reinício/reconexão.
- [x] Alinhar a URL usada para consultar releases ao repositório `unexplay0-crypto/IPTV-APP` informado.
- [x] Mapear `<display-name>` do XMLTV para permitir correspondência por nome de canal.
- [x] Ignorar inicializações antigas do player após uma troca rápida de canal.
- [x] Ignorar respostas de EPG referentes a seleções de canal anteriores.
- [x] Documentar os achados e os limites da validação.

## Fase 2 — Validar dependências e análise estática

1. Usar uma versão estável do Flutter que satisfaça a restrição SDK de `pubspec.yaml`.
2. Executar `flutter pub get` e revisar avisos/versões; gerar e versionar `pubspec.lock`.
3. Executar `dart format` e então converter o passo de CI em verificação `--set-exit-if-changed`.
4. Executar `flutter analyze --no-pub`; corrigir todos os erros e avisos. Revisar os infos conforme a política do repositório, sem mascarar resultados com `--no-fatal-infos`.
5. Executar `flutter test --no-pub` e adicionar testes para os fluxos de PIN, conta, EPG e falhas HTTP.

## Fase 3 — Robustez e segurança

1. Substituir SHA-256 simples do PIN por KDF apropriada com salt e custo configurável; testar bloqueio e recuperação.
2. Aplicar limites de bytes durante download de M3U/XMLTV e limites de itens, sem depender de uma verificação após carregar tudo em memória.
3. Melhorar telemetria local sanitizada e apresentação de erros parciais Xtream/EPG, sem registrar credenciais nem URLs completas.
4. Avaliar Network Security Config para reduzir HTTP claro quando compatível com os provedores necessários.
5. Revisar concorrência e desempenho do player em Android de baixa memória e Android TV.

## Fase 4 — Teste de lançamento

- [ ] `flutter pub get` concluído.
- [ ] `dart format --output=none --set-exit-if-changed lib test` concluído.
- [ ] `flutter analyze --no-pub` concluído sem erros/avisos não aceitos.
- [ ] `flutter test --no-pub` concluído.
- [ ] APK release compilado.
- [ ] AAB release compilado.
- [ ] Testes manuais de Xtream/M3U/XMLTV/player/PIN/Android TV concluídos.
- [ ] Conferir que o repositório e a página GitHub Releases usados pela função de atualização são o destino correto e público, se o app não autentica no GitHub.

**Nota:** a Fase 1 foi aplicada por revisão estática. As fases seguintes não podem ser marcadas como concluídas até haver execução real em ambiente Flutter/Android.
