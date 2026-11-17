# Relatório — funcionalidades implementadas × limitações

Estado do MVP (v0.1.0). Legenda: ✅ pronto · ⚠️ depende de recurso externo · ❌ sem API pública

## Etapa 1 — Navegador
- ✅ URL + pesquisa (DuckDuckGo), normalização com testes unitários
- ✅ voltar / avançar / atualizar / home
- ✅ Favoritos persistentes (SwiftData), editáveis (renomear) e removíveis (swipe)
- ✅ Histórico com re-abrir, remover e limpar
- ✅ Atalhos YouTube, Pluto TV, Twitch, Netflix, Prime Video, Disney+
- ✅ Aviso honesto de DRM junto aos serviços protegidos — **sem promessa de reprodução**
- ✅ Erros: URL inválida, host inacessível, sem rede — banner + log, nunca tela morta
- ✅ Responsivo + claro/escuro (SwiftUI dinâmico; WKWebView segue o trait do sistema)

## Etapa 2 — Player nativo
- ✅ MP4 e HLS/M3U8; botões play/pause/seek±15s/volume/slider/tela cheia
- ✅ `AVRoutePickerView` com `preferredRouteType = .video` (iOS 18+)
- ✅ Status da rota ("Saída: …") via `AVAudioSession.currentRoute` + mudança de rota
- ✅ Tratamento de interrupção: falha de item, fim da faixa, desconexão enquanto dirige
- ✅ Vídeo público de teste (Big Buck Bunny) e HLS público da Apple
- ✅ Logs de reprodução/erros no EventLog
- ❌ Streams FairPlay (Netflix etc.) não tocam aqui — **decisão**: não contornar DRM

## Etapa 3 — CarPlay (camada isolada)
- ✅ Cena `UIWindowSceneSessionRoleCarPlay` declarada no manifest e delegada em código (fallback)
- ✅ `CarPlayLink` centraliza conexão/desconexão/handoffs; detecta quando a cena existe
- ✅ `CPSessionConfiguration.supportsVideoPlayback` usado na referência de template (iOS 26.4+)
- ✅ Índice navegável na central + vídeo entregue por rota autorizada (window scene)
- ✅ Indisponibilidade de vídeo respeitada: degradação para só-áudio pelo CarGate;
  na rota de template, o próprio sistema a aplica — nada é forçado contra a central
- ✅ Diagnósticos legíveis (status/entitlements/flags/logs)
- ✅ Entitlement opcional e configurável (dois arquivos + input no CI)
- ✅ App compila e funciona no iPhone sem qualquer autorização CarPlay
- ⚠️ Vídeo na central do Pulse **só após a Apple conceder audio+video ao time** ($99+/ano + pedido)
- ❌ Sinais públicos "o carro está em movimento"/"vídeo indisponível agora" para window scenes não existem — aproximação documentada
- ❌ CarPlay não testável em simulador (entitlements não entram em build de simulador)

## Etapa 4 — Espelhamento (PoC, flag OFF)
- ✅ Consentimento real via `RPSystemBroadcastPickerView` (sistema)
- ✅ Extensão Broadcast Upload com captura → H.264 → TCP; sem persistência
- ✅ Estado (frames/heartbeat/erro) visível no app; parada pelo sistema
- ✅ Receptor de teste (LAN) para validar captura + transporte primeiro
- ✅ DRM: tela-preta nativa do ReplayKit, reportada como limitação, não burlada
- ❌ Entrega para receptores AirPlay de terceiros / tela do CarPlay via ReplayKit: sem API pública (plano em docs/MIRRORING.md)

## Etapa 5 — Diagnósticos
- ✅ iOS, modelo (uname), estado da cena CarPlay, rota AirPlay, sessão de vídeo
- ✅ Entitlements lidos do perfil embutido (quando verificável; "indeterminado" no resto)
- ✅ Logs dos eventos principais + exportação com scrub (URLs/tokens/emails/caminhos)
- ✅ Dica de UI separando implementado × autorizado × validado

## Etapa 6 — Build a partir do Windows
- ✅ `build-test.yml`: runner macOS, XcodeGen → build sem assinatura (verificação de código) + testes + artefatos
- ✅ `release-ipa.yml`: assinatura separada via Secrets; **skip explícito** sem credenciais, sem quebrar CI
- ✅ Nenhum segredo/certificado/perfil no repositório (`.gitignore` cobre `Local.xcconfig` etc.)
- ✅ README + docs/SIGNING.md com instalação em iPhone físico a partir do Windows (Sideloadly/AltStore)
- ⚠️ Runner com Xcode 27: usar a imagem macOS que a GitHub publicar com ele; hoje `macos-15` compila o código
- ❌ Assinatura automática App Store (notarização/etc.) fora de escopo: experimento sideload/dev

## Critérios de aceite da primeira versão
Navegador ✅ · Favoritos persistentes ✅ · Player MP4+HLS ✅ · Route picker ✅ ·
CI compila ✅ (primeiro push valida no runner) · Camada CarPlay isolada+documentada ✅ ·
Sem botões fantasmas ✅ · Sem Mac local ✅ · Limitações do iOS 27.2 identificadas ✅ ·
Reprodução/espelhamento no Pulse: **experimentais, aguardando hardware + Apple** ⚠️
