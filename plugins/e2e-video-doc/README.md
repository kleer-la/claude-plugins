# e2e-video-doc

Plugin de Claude Code. Recorre la aplicación como un usuario real y produce un
video narrado, capturas y el detalle de las llamadas a la API.

El recorrido es un **test E2E**: si se rompe, la pantalla cambió. Por eso la
documentación que sale de acá no queda desactualizada en silencio.

## Instalar

```
/plugin marketplace add kleer-la/claude-plugins
/plugin install e2e-video-doc@kleer-la
```

Después, en el proyecto: pedile a Claude un video de un flujo, o creá el
`e2e-video-doc.json` (ver `skills/e2e-video-doc/reference/config.md`).

## Requisitos

`edge-tts` (pip), `ffmpeg`, `jq`, `python3`. En Windows no están en el host: la
captura corre ahí y el armado cruza a WSL.

```bash
pip install edge-tts
apt install ffmpeg jq      # o brew install ffmpeg jq
```

## De dónde sale

Cuatro proyectos tenían el mismo pipeline copiado a mano, derivando cada uno por
su lado — jaomai, cenped, crm y kydat-poc. Al comparar las cuatro copias del
motor, cada una tenía arreglos que las otras no:

| | jaomai | cenped | crm | kydat |
|---|---|---|---|---|
| overrides por env | sí | sí | **no** | sí |
| `realpath` en el concat | sí | — | **no** | sí |
| `mkdir -p` del directorio de salida | **no** | **no** | **no** | sí |
| guarda de concat vacío | **no** | **no** | **no** | sí |

El motor de este plugin es la unión de las cuatro. Las recetas de captura salen de
kydat-poc (Playwright, la más completa) y de jaomai/cenped (Rails).

## Estructura

```
.claude-plugin/plugin.json
skills/e2e-video-doc/
  SKILL.md                    # el punto de entrada
  engine/                     # el motor — no depende de ningún proyecto
  recipes/                    # helpers de captura por stack
  reference/                  # config, narración, voces, y lo que ya costó caro
```
