---
name: e2e-video-doc
description: Recorre la aplicación como un usuario real y produce un video narrado, capturas y el detalle de las llamadas a la API. Usalo cuando pidan un video de una funcionalidad, un walkthrough narrado, release notes o guía de usuario que se regenere sola, o documentar un flujo end-to-end. El recorrido es un test E2E - si se rompe, la pantalla cambió.
---

# e2e-video-doc

Un script recorre la app haciendo lo que haría una persona —entrar, cargar datos,
navegar— y en el camino saca capturas numeradas. Un JSON les pone narración, y el
motor las convierte en un MP4 de 3-4 minutos con voz sintética.

Lo que sale no es sólo un video: es documentación que **falla cuando el producto
cambia**, porque el recorrido es un test E2E de verdad.

## La línea de corte

```
captura  →  NN_nombre.png  +  [{screenshot, duration, narration}]  →  motor
(por proyecto)         EL CONTRATO                                  (del plugin)
```

**Arriba de la línea el plugin es agnóstico. Abajo trae todo hecho.** El motor es
bash + ffmpeg + edge-tts y no le importa si el PNG salió de Capybara, de
Playwright o de un PDF rasterizado.

El recorrido lo escribe cada proyecto, en el stack que ya tiene, con sus factories
y su login helper — porque tiene que envejecer con el proyecto. Eso es el feature.

## Antes de hacer nada

1. **Leé [reference/gotchas.md](reference/gotchas.md).** Es corto y cada punto se
   pagó una vez. Especialmente: dónde termina el MP4, y dónde están instaladas las
   herramientas en *esta* máquina.
2. **Detectá el stack** — no preguntes lo que se puede mirar:
   - `test/system/` con Capybara → [recipes/rails-capybara](recipes/rails-capybara/)
   - `playwright.config.*` → [recipes/playwright-node](recipes/playwright-node/)
   - Otro: usá la receta Playwright como referencia de qué features debe tener el
     helper de captura, y escribilo en el stack del proyecto.
3. **¿Hay `e2e-video-doc.json` en la raíz?** Si no, crealo — ver
   [reference/config.md](reference/config.md).

## Generar un video de un flujo que ya existe

```bash
bash engine/run.sh <flujo>              # captura y arma
bash engine/run.sh <flujo> --solo-armar # sólo arma, con las capturas que ya están
VOICE=es-CO-SalomeNeural bash engine/run.sh <flujo>
```

En Windows: `engine\make_videos.cmd <flujo>` (captura en el host, arma en WSL).

Reportá al final: ruta del archivo, duración, tamaño, y **cuántas capturas
faltaron** si faltó alguna.

## Crear un flujo nuevo

1. **Preguntá qué tiene que mostrar el recorrido** — no lo adivines. Qué logra el
   usuario, desde dónde arranca, dónde termina.
2. **Escribí el recorrido** en el stack del proyecto, copiando el helper de
   captura de la receta que corresponda. Usá los factories y helpers que el
   proyecto ya tiene; no siembres datos a mano si hay un seed.
3. **Corré sólo la captura** y mirá los PNGs antes de narrar. Es mucho más barato
   corregir el recorrido acá que después del audio.
4. **Escribí el JSON de narración** — ver [reference/narration.md](reference/narration.md).
   Una entrada por captura, en orden.
5. **Agregá el flujo** a `e2e-video-doc.json`.
6. **Generá y mirá el video.**

## Si el recorrido se rompe

**Primero preguntate si el que está mal es el producto.** Este generador existe en
parte para eso: un paginado que falta, un orden roto, un error que el usuario
nunca ve. Si encontrás un bug, decilo antes de arreglar el script para esquivarlo.

## Qué hay acá

| | |
|---|---|
| `engine/make_video.sh` | El motor. Capturas + narración → MP4. Todo por entorno. |
| `engine/run.sh` | Orquesta un flujo leyendo `e2e-video-doc.json`. |
| `engine/make_videos.ps1` `.cmd` | Windows: captura en el host, arma en WSL. |
| `engine/generate_title_cards.sh` | Placas de apertura y cierre. |
| `recipes/playwright-node/` | `capture.ts` (highlight, focus, scroll) y `apiPanel.ts`. |
| `recipes/rails-capybara/` | `video_recording.rb`, mismo contrato. |
| `reference/` | [config](reference/config.md) · [narration](reference/narration.md) · [voices](reference/voices.md) · [gotchas](reference/gotchas.md) |
