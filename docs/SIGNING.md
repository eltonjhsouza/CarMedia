# Assinatura e instalação (do Windows, sem Mac)

## Rota rápida: Apple ID GRÁTIS (sem conta developer, sem TestFlight, sem loja)

É só isto que você precisa para rodar no SEU celular agora:

1. **GitHub** → Actions → **`free-install-ipa`** → *Run workflow*. Ele gera o
   artefato **`CarMedia-unsigned.ipa`** (build LITE: sem a extensão de
   broadcast, que conta grátis costuma rejeitar).
2. No Windows: instale o **Sideloadly** (sideloadly.io). Conecte o iPhone por
   cabo e toque em *Confiar* no aparelho.
3. Abra o Sideloadly: solte o `.ipa` baixado, informe seu **Apple ID** e a
   **senha de app** (appleid.apple.com → Sign-In and Security → App-Specific
   Passwords). Clique *Start*. Ele re-assina com seu time pessoal gratuito e
   instala.
4. No iPhone: **Ajustes → Privacidade e Segurança → Modo de Desenvolvedor →
   Ativar** (o iPhone reinicia; confirme de novo ao ligar). Sem isso, nenhum
   app fora da loja abre no iOS atual.
5. Toque em CarMedia na tela de início. Pronto.

Limitações honestas da rota grátis (não são bugs do app):
- Reinstalar/renovar a cada **7 dias** (deixe o iPhone no mesmo Wi‑Fi do PC e
  repita o passo 3). Máximo **3 apps** assinados assim.
- **Sem App Groups** → o PoC de espelhamento não sincroniza com a extensão
  (já desativado por padrão; no build lite a aba nem existe).
- **CarPlay na central continua indisponível** — isso exige a conta paga E os
  entitlements concedidos pela Apple. Nada muda esse fato.

## O que cada artefato do CI é

| Artefato | Instala no iPhone? |
|---|---|
| `CarMedia-unsigned.ipa` (workflow `free-install-ipa`) | ✅ **depois** de re-assinado pelo Sideloadly com seu Apple ID |
| `build-<sha>` do workflow `build-test` | ❌ build de simulador; nunca instala |
| `unsigned-app` do `release-ipa` | ❌ .app sem empacotar — inspeção apenas |
| `CarMedia.ipa` do `release-ipa` | ✅ instala direto (conta paga, perfil cobrindo o UDID) |

## Pré-requisitos Apple (pontos que exigem recursos externos)

1. **Conta Apple Developer paga** ($99/ano). Apple ID grátis não suporta os
   entitlements CarPlay nem perfis para múltiplos aparelhos.
2. **Certificado de distribuição/developement** (.p12) exportado do Keychain
   de **qualquer** Mac (um amigo/CI próprio serve uma vez).
3. **Provisioning profile** (development ou ad-hoc) cobrindo
   `dev.carmedia.app` **e** `dev.carmedia.app.broadcast`, com o UDID do
   iPhone de teste (development) — o UDID aparece no iTunes/Finder ou em
   `Diagnósticos`.
4. *(Só p/ vídeo no carro)* **Entitlements CarPlay**: pedir à Apple em
   https://developer.apple.com/contact/carplay/ a concessão de
   `com.apple.developer.carplay-audio` **e** `com.apple.developer.carplay-video`
   para a conta. Sem isso o app roda, mas nunca aparece na central.

## Configurar GitHub Secrets (nada disso vai no repositório)

```
APPLE_CERT_P12_BASE64   base64 -w0 certificate.p12
APPLE_CERT_PASSWORD     senha do p12
APPLE_PROFILE_BASE64    base64 -w0 profile.mobileprovision
APPLE_TEAM_ID           ABCDE12345
```

PowerShell (Windows) para gerar os bases:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12")) | Set-Clipboard
```

Antes de rodar `release-ipa`, ajuste no workflow os nomes de perfil em
`ExportOptions.plist` (`REPLACE_WITH_PROFILE_NAME`) para o **Name** do seu
profile, ou comente o dicionário `provisioningProfiles` para seleção
automática (funciona com perfil de desenvolvimento simples).

## Rodar o IPA

Actions → `release-ipa` → Run workflow (`carplay_entitlements` somente se a
Apple já concedeu). Baixe o artefato `CarMedia.ipa`.

## Instalar no iPhone a partir do Windows

- **AltStore / SideStore** (precisa do AltServer num Mac para a primeira
  instalação; depois renova sozinho) — gratuito, Apple ID grátis ou pago.
- **Sideloadly** (roda direto no Windows): arraste o IPA, informe Apple ID;
  com conta paga usa seu certificado; com gratuita assina por você e vale
  7 dias, 3 apps.
- **Foxo / eSigner etc.**: lojas alternativas — não recomendamos; risco de
  revogação e coleta de Apple ID.
- **Xcode + Mac emprestado**: `xcodebuild` direto no dispositivo, sem IPA.

Sem os entitlements CarPlay, o IPA instala e roda no iPhone normalmente —
só não alcança a central. CarPlay **não é testável em simulador** (não há
como embutir entitlements em build de simulador).
