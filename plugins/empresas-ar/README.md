# empresas-ar

Cross-reference an Argentine company by **CUIT, domain and email**. It validates the
identifiers locally, then finds the same company in the systems Kleer already uses and
tells you where records disagree.

## What is in it

- A **skill** (`empresas-ar`) with the lookup order and the report format.
- `scripts/ident.py`: CUIT check digit, email and domain normalisation, free-mail detection.
  Standard library Python, no network.
- An **OpenArg MCP** entry in `.mcp.json` (`https://mcp.openarg.org/mcp`).

## Setup

```
/plugin install empresas-ar@kleer-la
export OPENARG_API_KEY=oarg_sk_...      # free key from openarg.org/desarrolladores
```

The helper works without the key. Without it only the OpenArg lookups are skipped.

It uses whichever of the Fugazzeta, Keventer and Gmail connectors you have connected.

## Try it

> ¿Qué sabemos de la empresa con CUIT 30-50001091-2? ¿Y de `ana@kleer.la`?

## What it does not do

- It does not query ARCA/AFIP. OpenArg is a catalogue of public datasets with a free quota
  (the repository documents 200 data requests and 10 answers per month; check the current
  limits), not a padrón by CUIT. A name for an arbitrary CUIT will come back only if a
  dataset happens to carry it.
- The OpenArg tool list comes from its public README and was not run from here: the first
  session should confirm the tools and that `${OPENARG_API_KEY}` expands in the `headers`.
- The Fugazzeta and Keventer parameters are read from their schemas at run time, not
  hard-coded.
- It never edits contacts unless you ask for that change.

## Test

```
python3 skills/empresas-ar/scripts/ident.py cuit 30-50001091-2   # valid: true
```
