# Voices

The country is a parameter, not a code decision. `edge-tts` is free and needs no API key;
the engine passes `--voice` and that is it.

## Picking one

```json
{ "defaults": { "voice": "es-AR-ElenaNeural" } }
```

`VOICE=` in the environment overrides the config, so you can render the same flow in
another accent without editing anything.

## Rate

`RATE` adjusts the speed (`+8%` is a good starting point). Slightly faster sounds less
robotic over long narration.

## Every Spanish voice

Verified against `edge-tts --list-voices` on 2026-08-30:

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

Note that every Spanish-speaking country has a voice, including `es-PY`. No fallbacks
needed.

## Other languages

`en-US-JennyNeural`, `en-GB-SoniaNeural`, `zh-CN-XiaoxiaoNeural`, and so on. For the full,
current list:

```bash
edge-tts --list-voices
```

## Multiple languages for one flow

One narration file per language, same `screenshot` keys, same number of entries. See
[narration.md](narration.md).
