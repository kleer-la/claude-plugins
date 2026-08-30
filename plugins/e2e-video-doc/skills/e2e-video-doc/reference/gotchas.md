# Lo que ya nos costó caro

Cada cosa acá se pagó una vez en algún proyecto. Están para no volver a pagarlas.

## El video no puede vivir en `tmp/`

Cada test de captura arranca con `rm -rf` sobre su propio directorio. Si el MP4
queda ahí, lo borra la corrida siguiente — o cualquier `rails test:system`
completo. El `output` de la config va a `public/videos/` o equivalente.

*(jaomai)*

## Las herramientas no están donde creés

`edge-tts`, `ffmpeg` y `jq` pueden estar en el host, en el devcontainer, en
ninguno, o en uno distinto por máquina. **Detectá, no asumas.** Verificado el
2026-08-30 en la devbox: el host no tiene ninguna; el devcontainer de jaomai las
tiene las tres; el de cenped, ninguna.

```bash
for c in edge-tts ffmpeg ffprobe jq; do printf "%-10s %s\n" "$c" "$(command -v $c || echo FALTA)"; done
docker exec <container> bash -lc 'for c in edge-tts ffmpeg ffprobe jq; do printf "%-10s %s\n" "$c" "$(command -v $c || echo FALTA)"; done'
```

Corré el motor donde estén las cuatro. Si no están en ningún lado, decí cuál
falta dónde en vez de instalar paquetes de sistema por tu cuenta.

## Windows

El host no tiene ninguna de las tres, pero WSL Ubuntu sí. **No hay que reescribir
el motor**: `make_videos.ps1` captura en Windows y cruza a WSL para armar.

Dos cosas que ahí adentro no se deducen:

- **No uses `wsl wslpath`.** Al pasar por PowerShell, `wsl.exe` se come las barras
  invertidas y el argumento llega como `C:UsersOmenDev...`. Falla sin decir por
  qué. La conversión se hace local, en `Convert-ToWslPath`.
- **`.Replace` y no `-replace`** para las barras: el segundo es regex y una barra
  invertida sola no compila.
- `npm.ps1` a veces lo bloquea ExecutionPolicy: `cmd /c npm ...`. Para el `.ps1`
  propio está `make_videos.cmd`, que lo llama con `-ExecutionPolicy Bypass`.

*(kydat-poc)*

## Un flujo por corrida

Correr varios specs de video a la vez además de tardar el doble los hace pelear
por el estado compartido: flags de configuración que cada uno prende y apaga,
datos sembrados, sesiones. El orquestador corre **sólo** el spec del flujo pedido.

*(kydat-poc)*

## Lo que no es una captura de pantalla

Un PDF generado no se fotografía bien en headless Chrome — el visor no renderiza
de forma confiable. Hay que generar el PDF de verdad y rasterizarlo aparte
(`pdftoppm`), del lado donde esa herramienta exista, y meter el PNG en el
directorio como una captura más.

Mismo problema, misma salida: **cualquier frame que el navegador no pueda sacar se
genera aparte y entra como PNG numerado.** El motor no distingue.

*(jaomai)*

## Una llamada a la API no tiene nada que fotografiar

Si el video sólo muestra el resultado en pantalla, el espectador tiene que creer
que la API hizo algo. `apiPanel.ts` dibuja la llamada como una ficha —qué se
pidió, qué contestó, qué hay que mirar— y la fotografía con el mismo `capture`,
así entra en el mismo MP4 sin tocar el pipeline de narración.

El recorte es a propósito: un cuerpo de cuarenta campos en pantalla no se lee
ninguno. `recortarCuerpo` deja las claves que la narración está señalando y dice
cuántas quedaron afuera. `recortarValor` deja ver el principio de la credencial,
no la credencial.

*(kydat-poc)*

## Enmarcá antes de recortar

En un video a tamaño completo una celda no se encuentra sola: o se la enmarca
(`highlight:`), o se recorta la imagen alrededor (`focus:`). Sin una de las dos,
la narración señala algo que el espectador no ubica.

**Un `highlight:` que no matchea tiene que fallar ruidoso.** Es narración
apuntando a algo que ya no está en la pantalla — exactamente el cambio que el
video existe para delatar.

*(kydat-poc)*

## Prestar datos del fixture, y devolverlos

Cuando el recorrido necesita tocar datos compartidos (una contraseña conocida, un
flag de configuración, un servicio habilitado), prestalos al empezar y devolvelos
en el `afterAll` / `teardown`, para que vuelvan aunque el test falle.

**El préstamo tiene que ser idempotente.** Si una corrida se corta antes de
devolver, el siguiente préstamo tiene que **devolver primero**. Sin eso, el
segundo préstamo toma el valor ya prestado como si fuera el original y lo deja
pegado — pasó: un `ServiciosHabilitados` que quedó en 51 en vez de 3.

*(kydat-poc)*

## Limpiar la pantalla antes del disparo

Cosas que ensucian el video y no son el producto: la franja de trial de
DevExpress, banners de entorno de desarrollo, barras de debug. Cerralas en el
helper de captura, no en cada test.

En entorno de test Rails, CSRF viene deshabilitado y `csrf_meta_tags` no
renderiza nada — hay flujos que igual lo necesitan presente. Inyectá un meta
dummy después de navegar.

*(kydat-poc, cenped)*

## Los bugs que aparecen solos

Forzar el recorrido completo encuentra cosas que ningún test unitario mira:
paginado que falta, orden roto en listas, errores que el usuario nunca ve.

Ejemplo real: un botón contestaba *"Las siguientes precargas no se pudieron
recibir"* sin decir por qué. Sacando temporariamente el `catch` vacío apareció el
mensaje verdadero — *"No se pudo determinar la zona origen de distribución según
localidad ARG1832"*. El `catch` vacío era un defecto por sí solo: descartaba un
mensaje preciso y accionable. [kydat-poc#77]

Cuando el generador se rompe, **primero preguntate si el que está mal es el
producto.**
