# Arquitetura

```
┌────────────────────────────── iPhone (SwiftUI/UIKit) ─────────────────────────────┐
│ main.swift → AppDelegate → PhoneSceneDelegate ── UIHostingController(RootView)     │
│      TabView:                                                                       │
│   BrowserView ── BrowserModel (WKWebView) ── URLNormalizer / QuickLinks             │
│        │                                                                            │
│   PlayerView ── PlayerModel (AVPlayer + AVPlayerViewController + AVRoutePickerView) │
│        │                                                                            │
│   CarPlayStatusView ──┐                                                             │
│   MirroringView ──────┼── FeatureFlags · EventLog · LogScrubber · SharedStore       │
│   DiagnosticsView ────┘                                                             │
│      SwiftData: Favorite, HistoryEntry (persistente)                                │
│      CarGate (CoreLocation speed) ── notificação de estado p/ todo o app            │
└──────────────┬──────────────────────────────────────────────────────────────────────┘
               │ entitlements concedidas? então…
        UIWindowScene role "UIWindowSceneSessionRoleCarPlay"
               │
   CarPlaySceneDelegate → CarPlayScreenViewController
        ├── WKWebView (índice local + páginas enviadas do telefone)
        ├── AVPlayer (handoff de URL; NÃO divide o AVPlayer do telefone)
        └── portão: movendo ⇒ só áudio (imagem some, som continua)
                ▲
     CarPlayLink │ (única ponte telefone↔carro)

   [extensão] CarMediaBroadcast (RPBroadcastSampleHandler)
        video → VTCompressionSession H.264 → Annex-B → NWConnection(TCP) → receptor LAN
        status/heartbeat → App Group group.dev.carmedia.app → SharedStore → MirroringView
```

## Módulos e fronteiras

| Módulo | Responsabilidade | Depende de |
|---|---|---|
| `Core/` | flags, log, scrubber, conversor AnnexB | Foundation |
| `Browser/` | UI + modelo de navegação | WebKit, SwiftData, Core |
| `Player/` | reprodução nativa + rotas | AVKit/AVFoundation, Core |
| `CarPlay/` | cena do carro, gate, handoff, status | CarPlay, UIKit, Core — **camada independente: o resto do app não a chama, exceto Player/Browser via CarPlayLink** |
| `Mirroring/` + extensão | PoC de captura/transporte | ReplayKit, Network, VideoToolbox |
| `Diagnostics/` | verdade observável | todos, read-only |
| `Persistence/` | SwiftData | Foundation |

## Decisões

- **XcodeGen**: o `.xcodeproj` nasce de `project.yml` no CI — sem Mac local,
  sem merge conflicts de pbxproj.
- **Vida UIKit + UI SwiftUI**: a cena de window do CarPlay só aparece de
  forma previsível com manifesto de cenas no Info.plist (verificado pelo
  Cafari Lite); o SwiftUI App lifecycle interferiria.
- **Dois AVPlayers** (telefone e carro) por design: um AVPlayer renderiza
  em uma janela por vez — compartilhar moveria o vídeo de uma tela para a
  outra.
- **Handoff por URL**, não por fila compartilhada: simples, sem estado
  dual.
- **Entitlements em dois arquivos** (`CarMedia.entitlements` default sem
  CarPlay; `CarPlay.entitlements` opt-in) para o clone de qualquer pessoa
  compilar e rodar.
- **EventLog** é o canudo único: tudo que as abas mostram/exporta vem dele,
  já scrubado na saída.
