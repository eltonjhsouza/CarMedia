# Checklist de testes — Fiat Pulse 2024/2025

Marque APROVADO/FALHOU/BLOQUEADO + data + versão do app em cada linha.
O app NUNCA deve ser declarado "com CarPlay" sem as seções C e D.

## A. iPhone (sem o carro)
- [ ] A1 Navegador: URL direta carrega; termo vira busca; voltar/avançar/atualizar/home funcionam
- [ ] A2 Favoritos: adicionar, renomear, remover; sobrevivem a reinício do app
- [ ] A3 Histórico aparece e limpa
- [ ] A4 Erros: host inexistente e URL inválida mostram banner sem travar
- [ ] A5 Tema claro/escuro e layout (também em paisagem)
- [ ] A6 Player: Big Buck Bunny (MP4) play/pause/seek/volume
- [ ] A7 Player: HLS Apple (m3u8) adapta bitrate, seek OK
- [ ] A8 Tela cheia OK
- [ ] A9 AVRoutePickerView lista um AirPlay TV/Apple TV (se disponível) e o status "Saída:" atualiza
- [ ] A10 Desconectar a saída no meio não derruba o app (pausa/retoma, logado)
- [ ] A11 Netflix/Disney+ no navegador: páginas abrem; se não reproduzirem (DRM), o aviso está correto — **não é bug**
- [ ] A12 Diagnósticos: iOS/modelo/flags/logs; exportação não contém URLs completas/tokens

## B. Assinatura
- [ ] B1 Build IPA gerado sem secrets → aviso explícito de "sem assinatura", artefatos ok
- [ ] B2 IPA assinado instala no iPhone (UDID cadastrado)
- [ ] B3 Diagnósticos mostra os entitlements do perfil

## C. CarPlay — existência e navegação
Conecte o Pulse (carro parado, freio de mão).
- [ ] C1 O CarMedia aparece na tela inicial do CarPlay? **NÃO esperado** sem os
      entitlements concedidos pela Apple. Se NÃO aparece com build sem
      entitlement → comportamento CORRETO.
- [ ] C2 Com build entitlementado: app abre na central?
- [ ] C3 Índice local mostra botões; toque responde
- [ ] C4 "Enviar página do navegador" → página abre na central
- [ ] C5 Toque em "MP4 de teste" → vídeo em tela cheia no carro, áudio pelos alto-falantes
- [ ] C6 Handoff do Player (vídeo carregado) → toca no carro; iPhone segue utilizável
- [ ] C7 Desconectar/Reconectar (replug USB ou desconexão sem fio) → cena reconecta, nada crasha no iPhone

## D. Vídeo em movimento (restrições)
- [ ] D1 Com porta-aberta/sensor simulando marcha (ou carro em movimento em área segura, **passageiro testando**): vídeo vira só-áudio com banner?
- [ ] D2 A central original do Pulse BLOQUEIA/exibe por si mesmo? Registre o que a Fiat faz independentemente do app — regras do veículo vencem.
- [ ] D3 Localização negada → gate deve reportar "não movendo" e NÃO bloquear (documentado)
- [ ] D4 Retornar a parado → vídeo volta sozinho

## E. Espelhamento (flag ON — PoC)
- [ ] E1 Receptor `receiver.py` na LAN; app informa IP/porta
- [ ] E2 Seletor do sistema inicia; banner de gravação do iOS aparece
- [ ] E3 ffplay/VLC mostra a tela do iPhone com poucos segundos de atraso
- [ ] E4 Contador de quadros/heartbeat vivo na aba Estado
- [ ] E5 Parar via Centro de Controle → status volta a idle
- [ ] E6 App com DRM (Netflix app): receptor mostra preto — esperado, documentado

## F. Segurança/privacidade
- [ ] F1 Nenhum arquivo de gravação fica no aparelho após espelhamento
- [ ] F2 Logs exportados sem dados sensíveis
- [ ] F3 Sem APIs privadas: `ipatool`/strings não mostram símbolos `_` privados (revisão manual)
