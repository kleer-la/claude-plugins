# `e2e-video-doc.json`

Lo único que se escribe por proyecto. Va en la raíz del repo, versionado.

```json
{
  "defaults": {
    "voice": "es-AR-ElenaNeural",
    "screenshots": "tmp/video_screenshots/{flow}",
    "narration": "scripts/{flow}_video_narration.json",
    "output": "public/videos/{flow}.mp4"
  },
  "flows": {
    "alta": {
      "capture": "docker exec mi_devcontainer-app-1 bin/rails test test/system/{flow}_video_test.rb"
    },
    "cierre": {
      "capture": "npx playwright test tests/{flow}.video.spec.ts",
      "voice": "es-CO-SalomeNeural"
    }
  }
}
```

`{flow}` se reemplaza por el nombre del flujo. Cada flujo pisa lo que necesite
de `defaults`; en general sólo define `capture`.

| Clave | Qué es |
|---|---|
| `capture` | El comando que corre el recorrido y deja los PNGs. **Del proyecto**: su stack, su devcontainer, sus fixtures. |
| `screenshots` | Dónde los deja (relativo a la raíz del repo). |
| `narration` | El JSON de narración de ese flujo. Ver [narration.md](narration.md). |
| `output` | Dónde va el MP4. **Fuera de `tmp/`** — ver [gotchas.md](gotchas.md). |
| `voice` | Ver [voices.md](voices.md). `VOICE=` en el entorno lo pisa. |

## Por qué el capture no lo trae el plugin

Porque usa los factories, el login helper y los datos sembrados del proyecto — y
tiene que envejecer con él. **Eso es el feature**: si la pantalla cambia y el
recorrido se rompe, el video falla como falla un test E2E, y por eso la
documentación no puede quedar desactualizada en silencio.

El plugin trae el motor, el contrato y las recetas. El recorrido lo escribe cada
proyecto — con ayuda del skill, en el stack que ya tiene.
