# Voces

El país es un parámetro, no una decisión de código. `edge-tts` es gratis y sin
API key; el motor le pasa `--voice` y listo.

## Los que usamos

| País | Voz | Dónde |
|---|---|---|
| Argentina | `es-AR-ElenaNeural` | cenped, crm, kydat-poc |
| Colombia | `es-CO-SalomeNeural` | jaomai |
| Paraguay | `es-PY-TaniaNeural` | disponible, todavía sin usar |

**Paraguay no necesita fallback.** `es-PY` existe en edge-tts (Tania, Mario).

## Otros idiomas en uso

| Idioma | Voz |
|---|---|
| Inglés (US) | `en-US-JennyNeural` |
| Chino (mandarín) | `zh-CN-XiaoxiaoNeural` |

## Ritmo

`RATE` ajusta la velocidad (`+8%` en cenped, sin ajuste en el resto). Un poco
más rápido se escucha menos robótico en narración larga.

## Todas las voces en español

Verificadas contra `edge-tts --list-voices` el 2026-08-30:

```
es-AR-ElenaNeural
es-AR-TomasNeural
es-BO-MarceloNeural
es-BO-SofiaNeural
es-CL-CatalinaNeural
es-CL-LorenzoNeural
es-CO-GonzaloNeural
es-CO-SalomeNeural
es-CR-JuanNeural
es-CR-MariaNeural
es-CU-BelkysNeural
es-CU-ManuelNeural
es-DO-EmilioNeural
es-DO-RamonaNeural
es-EC-AndreaNeural
es-EC-LuisNeural
es-ES-AlvaroNeural
es-ES-ElviraNeural
es-ES-XimenaNeural
es-GQ-JavierNeural
es-GQ-TeresaNeural
es-GT-AndresNeural
es-GT-MartaNeural
es-HN-CarlosNeural
es-HN-KarlaNeural
es-MX-DaliaNeural
es-MX-JorgeNeural
es-NI-FedericoNeural
es-NI-YolandaNeural
es-PA-MargaritaNeural
es-PA-RobertoNeural
es-PE-AlexNeural
es-PE-CamilaNeural
es-PR-KarinaNeural
es-PR-VictorNeural
es-PY-MarioNeural
es-PY-TaniaNeural
es-SV-LorenaNeural
es-SV-RodrigoNeural
es-US-AlonsoNeural
es-US-PalomaNeural
es-UY-MateoNeural
es-UY-ValentinaNeural
es-VE-PaolaNeural
es-VE-SebastianNeural
```

Para ver la lista completa y actualizada:

```bash
edge-tts --list-voices | grep -E "^es-"
```
