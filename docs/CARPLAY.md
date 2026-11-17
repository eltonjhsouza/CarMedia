# Camada CarPlay — decisões e limites (estado do iOS 26.4 → 27.2, nov/2026)

## O que a documentação/APIs públicas dizem hoje

1. **Entitlement de vídeo.** `com.apple.developer.carplay-video`
   (iOS 27, CarPlay Developer Guide) é **concedido pela Apple mediante
   pedido** por conta de desenvolvedor. Conta grátis não pode detê-lo.
   Ele é **opcional e configurável** neste projeto: `Entitlements/
   CarPlay.entitlements` só é usado quando o workflow de release é
   disparado com o input explícito. Uma conta **sem** o entitlement recebe
   um build idêntico que simplesmente roda só no iPhone — requisito do
   briefing atendido sem código condicional.

2. **Combinação de entitlements.** Não misture categorias CarPlay que o
   perfil não cobre. A lição verificada pelo Cafari Lite: assinar só com
   `carplay-video` compila, instala, e o app **nunca aparece** na central;
   o combo que funciona é `carplay-audio` + `carplay-video` juntos —
   é o que `CarPlay.entitlements` contém.

3. **Duas rotas oficiais de vídeo no carro:**
   - **Window scene** (o que o CarMedia usa, via Cafari Lite): iOS cria uma
     `UIWindowScene` comum sob o role `UIWindowSceneSessionRoleCarPlay`
     (string do manifest; UIKit não expõe o role em Swift). Tudo que o
     UIKit desenha aparece na central — inclusive WKWebView e AVPlayer.
     Requer os entitlements acima. É a rota do rPlayFling/Cafari para
     *"desenhar na tela do carro"* em qualquer carro CarPlay a partir do
     iOS 26.4.
   - **Template/media scene** (`CPTemplateApplicationScene` +
     `CPSessionConfiguration.supportsVideoPlayback`, iOS 26.4): o *próprio
     carro* decodifica o vídeo que você entrega; apps com entitlement de
     vídeo só aparecem em carros que o suportam, e **quando o carro informa
     que vídeo está indisponível, o sistema degrada sozinho para áudio**.
     Referência comentada em `CarPlayTemplateSupport.swift` — NÃO registrar
     as duas cenas para o mesmo role ao mesmo tempo.

4. **"Indisponibilidade informada pelo sistema".** Para a rota de template,
   a degradação vídeo→áudio é automática do sistema, respeitada por
   construção. Para a window scene, **não há API pública** que entregue esse
   sinal nem um estado "estacionado" — por isso o CarGate (velocidade do
   CoreLocation, ~11 km/h por 3 amostras) pausa a **imagem** mantendo o
   **áudio**, na mesma direção da degradação oficial. Quando o sinal não
   existe (localização negada), o gate NÃO bloqueia: um portão cego não
   finge que vê. O `Fiat Pulse` ainda aplica as regras dele mesmo: se a
   central recusar mostrar vídeo em movimento, nada no app muda isso — e é
   exatamente assim que deve ser.

5. **Por que outros apps tocam vídeo no Pulse e isso não prova nada.**
   Dricast/CarDash/rPlayFling podem ter entitlement próprio, truques de
   fábrica, ou a rota de window scene. Nada disso autoriza presumir que um
   build nosso funcionará. Só o teste com o carro conectado (checklist)
   valida.

## Matriz de recursos deste app

| Recurso | Implementado | Autorizado (depende da Apple) | Validado no Pulse |
|---|---|---|---|
| Cena window CarPlay no código | ✅ | precisa audio+video | ❓ (pelo checklist) |
| `supportsVideoPlayback` em sessão de template | código pronto (referência) | idem | ❓ |
| Degradação vídeo→áudio em template | automática do sistema | idem | ❓ |
| Portão por velocidade (CarGate) | ✅ | não requer | ❓ |
| Handoff página/vídeo telefone→carro | ✅ | requer cena | ❓ |

## Suposições documentadas

- iOS 27.2 mantém o comportamento da window scene introduzida em 26.4
  (rPlayFling documenta funcionamento em 26.4+, "including iOS 27.2").
  Se a Apple remover/renomear o role em alguma versão, o app continua
  normal no iPhone e o diagnóstico ficará honestamente "não conectado".
- Central original do Pulse = CarPlay "clássico" (não Ultra). Vídeo pelo
  caminho do carro (entitlement + template) pode nem existir nela; o
  caminho window-scene é o que os apps citados usam.
