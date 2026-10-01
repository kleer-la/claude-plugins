---
name: empresas-ar
description: Cross-reference an Argentine company by CUIT, domain, email or razón social. Validates and normalises the identifiers, then looks the company up in Fugazzeta, Keventer, Gmail and OpenArg public data and reports duplicates and mismatches. Use when the user asks who a company is, whether a CUIT or mail belongs to a client already on file, or to clean up contacts.
---

# empresas-ar

Answer "is this the same company?" from identifiers, never from names alone.

## 1. Normalise first

Run the helper on everything the user gave you before any lookup. It needs no network.

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/empresas-ar/scripts/ident.py auto "<cuit | mail | url>" ...
```

It accepts several arguments, or one value per line on stdin. For each it returns JSON:

- **CUIT**: `valid` (check digit), `formatted` (`30-12345678-9`), `kind` (`company` for prefixes 30/33/34, `person` for 20/23/24/27). A person's CUIT carries the DNI.
- **email**: the `domain`, `free_mail`, and `company_signal`.
- **domain**: the registrable domain, so `www.x.com.ar/contacto` becomes `x.com.ar`.

Rules that follow from it:

- An **invalid CUIT** is a typo until proven otherwise. Say so, do not search with it.
- A **free-mail address** (gmail, hotmail, fibertel...) identifies a person, never a company. Do not use its domain to match a company.
- A **corporate domain** is a strong hint, not proof: agencies and consultants mail from their own domain on behalf of clients.

## 2. Look it up, strongest key first

Order of trust: **CUIT** > corporate **domain** > exact **email** > razón social. Stop widening as soon as one key hits, and say which key matched.

| Source | Use it for |
|---|---|
| Fugazzeta (`list_contacts`, `list_invoices`) | Is it a billed client or supplier, with which CUIT and invoices |
| Keventer (`contacts`, `participants`) | Who attended our events, under which company name |
| Gmail (`search_threads`) | Existing conversations, searched by `from:@domain` |
| OpenArg (`buscar_datasets`, `describir_tabla`, `obtener_datos`) | Public datasets, only where a table carries a CUIT column |

The tools above are deferred: load their schemas with ToolSearch before calling, and read the parameters rather than guessing them. If a connector is not connected, say it was skipped; do not present a partial answer as complete.

OpenArg is a catalogue of public datasets with a free quota (monthly request cap, 500 rows per call, an `OPENARG_API_KEY` bearer token). It is **not** an AFIP/ARCA padrón lookup, and its tools do not take a CUIT directly. Find a dataset with `buscar_datasets`, inspect it with `describir_tabla`, and filter in `obtener_datos` only when it has a CUIT column. Do not spend the quota on a company that Fugazzeta or Keventer already identify.

## 3. Report

One block per company:

- **Identity**: razón social, CUIT (formatted, valid or not), domain(s).
- **Where it appears**: one line per source, with the key that matched.
- **Conflicts**: the same CUIT under two names, the same domain under two CUITs, a mail in Keventer whose domain differs from the company's. Show both values side by side.
- **Not found**: list the sources that returned nothing, so absence is visible.

Propose merges or edits but do not write to Fugazzeta or Keventer (`manage_contact` and similar) unless the user asks for that specific change.
