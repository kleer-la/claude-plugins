# El JSON de narración

Un array, un objeto por pantalla, en el orden del video.

```json
[
  {
    "screenshot": "01_login.png",
    "duration": 6,
    "narration": "El representante entra con el usuario que le llegó por mail."
  },
  {
    "screenshot": "02_alta.png",
    "duration": 8,
    "narration": "Carga el pedido. El total se calcula solo a medida que agrega ítems."
  }
]
```

| Campo | Qué es |
|---|---|
| `screenshot` | Nombre del archivo dentro del directorio de capturas. |
| `duration` | **Piso** en segundos, no valor exacto. |
| `narration` | El texto que se sintetiza. |

## `duration` es un piso

El segmento dura `max(duración del audio + 0.5, duration)`. Si la narración se
alarga, la imagen la acompaña — nunca se corta la voz a la mitad. Poné `duration`
sólo cuando querés que una pantalla se quede más tiempo del que tarda en leerse.

## El nombre del archivo ordena el video

`NN_nombre.png`, con `NN` de dos dígitos empezando en 01. El número lo pone el
helper de captura solo, incrementando; vos le pasás sólo el nombre.

El orden del JSON manda sobre el del disco, pero mantenerlos alineados es lo que
hace que un diff del JSON se lea.

## Si falta una captura

El motor la saltea, avisa, y al final dice cuántas faltaron. Si faltan **todas**,
corta con un mensaje claro en vez de dejar que ffmpeg escupa el suyo.

## Un idioma por archivo

`alta_video_narration.json`, `alta_video_narration_en.json`, `..._ch.json`. Mismo
`screenshot`, misma cantidad de entradas, distinta `narration` y `voice`.

Al agregar o sacar una pantalla hay que tocar **todos** los idiomas. Es el punto
donde más se desincroniza esto.

## Escribir la narración

- Contá lo que el usuario está logrando, no lo que la pantalla muestra. "Carga el
  pedido" y no "se ve el formulario de pedidos".
- Frases cortas. La voz sintética se traba con subordinadas largas.
- Números y siglas: escribilos como se leen si la voz los pronuncia mal.
- 3-4 minutos es el largo que funciona. Más que eso, partilo en dos flujos.
