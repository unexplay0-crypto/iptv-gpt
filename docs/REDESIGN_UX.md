# UNEX Vision — especificação do redesign UX/UI

## Objetivo

Criar uma experiência de streaming coerente em Android mobile e Android TV, preservando a integração IPTV existente. A interface deve priorizar descobrir rapidamente o que assistir, retomar conteúdo e controlar o player sem exigir precisão excessiva.

## Direção visual

- **Canvas:** preto azulado `#08090D`, evitando preto absoluto em todas as superfícies.
- **Superfícies:** grafite `#12141B` e superfície elevada `#1B1E28`, com bordas discretas `#2A2D39`.
- **Ação da marca:** violeta `#9B8CFF`; cor complementar verde-água `#5DE1D1` usada com parcimônia.
- **Ao vivo/alerta:** coral `#FF435A`, reservado para conteúdo ao vivo e estados que realmente exigem atenção.
- **Texto secundário:** `#A5A9B7`; manter contraste e evitar textos pequenos para informação essencial.
- **Forma:** cantos de 12–16 px em controles, 16–26 px em superfícies de destaque. Contorno de foco claramente visível.
- **Movimento:** transições curtas (130–180 ms), com ampliação sutil em foco/hover; não depender de animações para comunicar estado.

## Princípios de experiência

1. O conteúdo e a ação principal devem aparecer antes de configurações e metadados.
2. Diferenciar claramente ao vivo, filmes, séries, favoritos e histórico.
3. Evitar telas sem saída: cada estado vazio oferece uma ação útil (buscar, atualizar ou voltar ao catálogo).
4. Mensagens de erro devem explicar o problema em linguagem simples e apresentar recuperação.
5. Manter as funções do provedor e do player existentes; não substituir falhas de integração por conteúdo fictício.

## Mobile — toque

- Navegação primária inferior: Início, Ao vivo, Filmes, Séries e Mais.
- Área de toque mínima recomendada de 48 × 48 logical pixels.
- Busca e filtros ficam no topo da tela do catálogo; limpar busca é uma ação explícita.
- Usar duas colunas de pôster em telas muito estreitas e ampliar a quantidade de colunas somente quando o espaço permitir.
- Preservar safe areas e permitir rolagem vertical em telas pequenas e em modo paisagem.
- O bottom sheet “Mais” agrupa busca, favoritos, histórico, guia e configurações, sem competir com as quatro tarefas principais.

## Android TV — controle remoto / 10-foot UI

- Navegação lateral persistente em telas largas; alvos e textos maiores que no celular.
- Foco visível com borda violeta de 2 px, fundo sutil e escala moderada. Foco nunca deve depender apenas da cor.
- Elementos interativos precisam responder a setas, OK/Select e Back, mantendo a ordem de foco previsível.
- Manter margens de segurança ao redor do conteúdo e evitar informação essencial nas extremidades.
- Catálogos em grades com espaçamento generoso; prateleiras horizontais no Início.
- Controles do player devem ser grandes, ter rótulos/semântica acessível e não cobrir permanentemente o vídeo.

## Arquitetura de informação

- **Início:** destaque principal, continuar assistindo, canais ao vivo, filmes, séries e Minha lista.
- **Ao vivo:** canais e categorias, com acesso ao guia de programação.
- **Filmes / Séries:** catálogo filtrável por texto e categoria.
- **Buscar:** pesquisa transversal por título e categoria.
- **Minha lista:** favoritos salvos.
- **Continuar assistindo:** histórico recente.
- **Guia de TV:** seleção de canal e programação XMLTV, quando disponível.
- **Configurações:** conta, playlist, EPG, atualização e saída.

## Componentes

- **Pôster:** imagem preenchendo a área, gradiente para legibilidade, badge “AO VIVO” coral e cadeado para conteúdo adulto protegido.
- **Prateleira:** título claro, ação “Ver tudo” quando aplicável, rolagem horizontal e espaçamento consistente.
- **Destaque:** imagem de fundo, gradiente escuro, título em destaque e no máximo duas ações primárias/secundárias.
- **Campos:** rótulos explícitos, estado de foco forte, validação próxima ao campo e ajuda para recuperação.
- **Carregamento:** indicador discreto; evitar bloquear toda a tela se uma seção independente ainda puder ser usada.
- **Vazio/erro:** ícone sem excesso de decoração, frase objetiva e botão de recuperação.

## Acessibilidade e robustez

- Usar contraste adequado, ícones acompanhados de tooltip/label e mensagens sem depender só de cor.
- Respeitar escala de texto do sistema e evitar truncar nomes essenciais sem tooltip ou alternativa.
- Imagens remotas precisam de fallback legível.
- Testar carregamento lento, URL inválida, EPG ausente, lista vazia, poster quebrado e desconexão.
- Em TV, testar foco de todas as ações com controle físico; em mobile, testar com leitor de tela e escala de fonte ampliada.

## Métricas para validação com usuários

- Tempo para abrir um canal a partir do início.
- Tempo para localizar um filme pelo nome.
- Sucesso sem ajuda em conectar uma playlist.
- Número de cliques/pressionamentos até favoritos e guia.
- Erros de foco e ações perdidas usando controle remoto.
- Taxa de abandono durante carregamento e erros recuperáveis.

## Plano de testes

1. Smoke test em Android mobile estreito, mobile grande e Android TV/Google TV.
2. Fluxos: conectar Xtream, importar M3U, abrir canal, trocar canal, buscar filme, favoritar, abrir guia, atualizar playlist e sair.
3. Controle remoto: navegar da barra lateral para o conteúdo, atravessar linhas de cards, abrir detalhes/player e voltar sem perder contexto.
4. Acessibilidade: escala de texto, contraste, TalkBack e foco por teclado.
5. Desempenho: lista grande, posters lentos, rolagem de prateleiras e player em tela cheia.

## Limites desta entrega

Esta atualização aplica o sistema visual e ajustes de navegação/responsividade sobre a base existente. Não altera os protocolos do provedor nem garante compatibilidade com todo firmware de TV sem testes em dispositivos reais. O ambiente de edição não dispõe do SDK Flutter; o workflow GitHub Actions deve confirmar análise, testes e build antes de publicar.
