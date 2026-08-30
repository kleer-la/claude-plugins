# Plugins de Claude Code de Kleer

Marketplace del equipo. Se agrega una vez y los plugins que vengan después
aparecen solos.

```
/plugin marketplace add kleer-la/claude-plugins
/plugin install e2e-video-doc@kleer-la
```

## Plugins

| Plugin | Qué hace |
|---|---|
| [`e2e-video-doc`](plugins/e2e-video-doc/) | Recorre la app como un usuario real y produce un video narrado, capturas y el detalle de las llamadas a la API. El recorrido es un test E2E: si se rompe, la pantalla cambió. |

## Agregar un plugin

1. `plugins/<nombre>/.claude-plugin/plugin.json` con `name`, `version`, `description`, `author`
2. Los skills en `plugins/<nombre>/skills/<skill>/SKILL.md`
3. Una entrada en `.claude-plugin/marketplace.json` con `"source": "./plugins/<nombre>"`

Si alguno crece hasta merecer repo propio, la entrada cambia a
`{"source": "url", "url": "https://github.com/kleer-la/<repo>.git"}` y del lado
de quien lo tiene instalado no cambia nada.
