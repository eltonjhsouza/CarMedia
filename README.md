# CarMedia

Aplicativo iOS experimental, open source (MIT), para reproduzir vídeo na tela
CarPlay do **Fiat Pulse 2024/2025** usando apenas APIs públicas, e para testar
um navegador + player nativo + diagnósticos no iPhone (iOS 27.2).

Desenvolvido **inteiramente do Windows**: nenhum Mac local é necessário.
A compilação e os testes rodam no GitHub Actions (runner macOS / Xcode 27).

> **Honestidade primeiro.** Vídeo no carro só funciona com os entitlements
> `com.apple.developer.carplay-audio` + `com.apple.developer.carplay-video`,
> concedidos **pela Apple, por conta de desenvolvedor paga, mediante pedido**
> (https://developer.apple.com/contact/carplay/). Sem eles, o app é 100%
> funcional no iPhone e **silenciosamente ausente** na central — é assim que
> o iOS se comporta, não é um bug nosso. Nenhuma tela deste app afirma que o
> CarPlay "funciona" sem teste real no Pulse; a tela Diagnósticos separa
> *implementado* / *autorizado* / *validado em hardware*.

## O que tem

| Aba | Função |
| --- | --- |
| Navegador | URL + busca (DuckDuckGo), voltar/avançar/atualizar/home, favoritos persistentes (SwiftData, editáveis/removíveis), histórico, atalhos (YouTube, Pluto TV, Twitch, Netflix, Prime, Disney+) com aviso honesto sobre DRM |
| Player | MP4 + HLS, play/pause/seek/volume/tela cheia, `AVRoutePickerView` priorizando vídeo, status da rota, tratamento de interrupções, vídeos públicos de teste, logs |
| CarPlay | Estado da cena, flags, diagnóstico de entitlements, "enviar página/vídeo para o carro" quando conectado |
| Espelhamento | PoC ReplayKit → receptor TCP de LAN (atrás de flag, **OFF** por padrão) |
| Diagnósticos | iOS, modelo, estado CarPlay/rotas, entitlements assinados, logs, exportação anonimizada |

## Estrutura

```
CarMedia/            fontes do app (App/, Browser/, Player/, CarPlay/, Mirroring/, Diagnostics/, Persistence/, Core/)
CarMediaBroadcast/   Broadcast Upload Extension (ReplayKit PoC)
CarMediaTests/       testes Swift Testing (lógica pura, rodam no CI)
Entitlements/        CarMedia.entitlements (default, sem CarPlay) e CarPlay.entitlements (opt-in)
.github/workflows/   build-test.yml (sempre) e release-ipa.yml (assinado, separado)
docs/                arquitetura, CarPlay, espelhamento, assinatura, checklist do Pulse
tools/               receptor de teste do stream de tela
project.yml          XcodeGen — o .xcodeproj É GERADO, nunca commitado
```

## Trabalhando do Windows

1. Instale: VS Code, Git, Codex (ou qualquer agente CLI). Nada da Apple.
2. Edite/commit normalmente; cada push roda o workflow `build-test`
   (XcodeGen → xcodebuild → testes no simulador).
3. O projeto Xcode é gerado a partir de `project.yml` — se precisar mexer em
   configuração de target, mexa no YAML, não em `.pbxproj` (que não existe aqui).

## Instalar no iPhone físico

Dois caminhos, documentados em [docs/SIGNING.md](docs/SIGNING.md):

- **Assinatura própria (recomendado para testar):** conta Apple Developer
  ($99/ano), certificate + profile, workflow `release-ipa`, instalar IPA via
  AltStore/Sideloadly/Foxo (funcionam do Windows) ou Xcode num Mac emprestado.
- **Build sem assinatura:** serve só para verificação de código no CI.
  **Não instala no iPhone.** Não confunda os dois artefatos.

## Testes no carro

Checklist passo a passo com o Fiat Pulse em
[docs/FIAT_PULSE_CHECKLIST.md](docs/FIAT_PULSE_CHECKLIST.md).

## Referências e licença

MIT (LICENSE). Partes da abordagem CarPlay são adaptações creditadas do
[Cafari Lite](https://github.com/rPlayAI/cafari-lite) (MIT) — ver NOTICE e
comentários no código. [Cafari](https://github.com/rPlayAI/cafari-public) e
[rPlayFling](https://github.com/rPlayAI/rPlayFling-public) serviram de
referência de comportamento (fonte não pública). Documentação Apple:
developer.apple.com/carplay e o bundle de entitlements
`com.apple.developer.carplay-video`.
