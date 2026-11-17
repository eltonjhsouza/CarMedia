# Espelhamento — PoC atual e plano de evolução

## O que existe hoje (flag `mirroring`, OFF por padrão)

1. **Consentimento real**: a aba usa `RPSystemBroadcastPickerView` — o seletor
   do sistema. Nada começa sem o gesto do usuário no aviso de gravação do iOS.
2. **Captura**: Broadcast Upload Extension (`CarMediaBroadcast`) recebe os
   buffers de vídeo via `RPSampleBufferType.video`.
3. **Transporte validável**: frames → `VTCompressionSession` (H.264) →
   Annex-B → TCP para um receptor de testes na LAN (`tools/receiver/`).
   Isso valida captura + codec + transporte **sem persistir nada**: nenhum
   arquivo de gravação é criado — regra do projeto.
4. **Estado e parada**: extensão escreve status/heartbeat no App Group; a aba
   mostra quadros/último sinal. A parada é a oficial (Centro de Controle),
   porque extensões de broadcast não têm botão de stop próprio.
5. **Conteúdo protegido**: ReplayKit entrega quadros em branco para conteúdo
   com DRM — o sistema já bloqueia; não há (nem será feito) contorno. O
   receiver simplesmente verá tela preta, e isso é reportado como esperado.

## Limites honestos (sem API pública)

| Desejo | Situação |
|---|---|
| Enviar tela de app para receptor AirPlay de terceiro via ReplayKit | Sem API pública; o caminho oficial é `AVPlayer`/`AVRoutePickerView` (aba Player) ou o espelhamento do sistema (Control Center), que é decisão do usuário, não do app |
| Screen mirroring do iPhone na tela do CarPlay | Recurso central/Apple: algumas centrais suportam CarPlay sem fio "Screen Mirroring" só fora de movimento; apps NÃO têm API para forçar/abrir isso |
| Substituir o vídeo do carro por espelhamento | Não faz sentido: para vídeo no carro existe a cena CarPlay oficial (aba CarPlay), que é o caminho suportado |

## Plano de evolução

1. **MVP do receptor**: validar stream TCP → ffplay ao vivo (feito por você
   com `tools/receiver/receiver.py` + VLC/ffmpeg). Métricas: fps, latência,
   bitrate.
2. **Áudio**: adicionar AAC (LATM/raw-ASC) ao multiplexador do receptor e
   sincronizar por PTS. Sem API para mixar audioApp+mic aqui? Não — os
   buffers já chegam na extensão; é trabalho de container, não de API.
3. **Resiliência**: buffer ring pequeno, request-rate do encoder por
   largura de banda, reconexão com `NWConnection`-retry.
4. **Formatos de transporte**: RTSP ou WebRTC apenas se a validação TCP
   puro mostrar latência inaceitável — manter sem serviços pagos.
5. **Saída para destinos autorizados**: pesquisar se `AVSampleBufferDisplayLayer`
   + rota AirPlay ativa dentro da própria extensão melhora o quadro;
   continua sem garantia — documentar o que falhar.
6. **CarPlay como destino**: se um dia existir API pública (não há hoje),
   pluga aqui. Até lá, o CarMedia usa a cena CarPlay para vídeo no carro.
