# Auditoria técnica — UNEX Vision IPTV

Data: 19/10/2026

## 1. Diagnóstico conhecido

O relato anterior indicou 23 ocorrências de `curly_braces_in_flow_control_structures` em 8 arquivos e saída diferente de zero no `flutter analyze --no-pub`. Essa regra pede blocos `{ ... }` nas estruturas de controle para reduzir ambiguidades de fluxo. O Dart tem uma exceção para `if` sem `else` cujo corpo inteiro cabe na mesma linha; portanto, não se deve fazer substituição textual cega nem desativar a regra para mascarar os diagnósticos.

A cópia inspecionada contém `analysis_options.yaml` que herda `package:flutter_lints/flutter.yaml`. Os workflows Android e Release executam `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, testes e builds Android.

## 2. Limite de validação

O ambiente usado nesta auditoria não contém executáveis `flutter` ou `dart` e não consegue acessar a rede para instalar o SDK. Assim, não foi possível reproduzir o código de saída, aplicar os quick-fixes oficiais do analyzer nem executar análise, testes ou builds. Não é correto declarar que os 23 diagnósticos foram eliminados sem esse resultado. A validação final deve ser feita pelo workflow Android em um runner com Flutter instalado.

## 3. Arquivos e risco de compilação

A cópia contém 31 arquivos Dart. Isso não é, por si só, um volume excessivo. Reduzir a contagem juntando telas, serviços, modelos e controladores em poucos arquivos não reduz o número de unidades que o compilador precisa validar e tende a aumentar acoplamento, conflitos de edição e dificuldade de testar. A recomendação é manter separação por responsabilidade e só consolidar arquivos muito pequenos quando forem partes inseparáveis do mesmo componente.

## 4. Sequência de validação recomendada

Na raiz do projeto, com Flutter stable instalado:

```bash
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

Se `flutter analyze` reportar a regra de chaves, usar os diagnósticos atuais do analyzer e aplicar o quick-fix correspondente em cada ocorrência; depois formatar e repetir todos os comandos. Não usar `--no-fatal-infos` como solução definitiva, pois isso pode apenas ocultar a condição que fez a verificação falhar. Se houver erros além dessa regra, corrigi-los separadamente conforme o diagnóstico real.

## 5. Critério de conclusão

Considerar a correção validada apenas quando formatação, análise estática, testes, APK e AAB terminarem com código zero no mesmo commit. O ZIP por si só não prova que a compilação foi concluída.
