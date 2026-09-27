import { test, expect } from "@playwright/test";
import {
  createCapture,
  resetDir,
} from "../../../skills/e2e-video-doc/recipes/playwright-node/capture";
import {
  showApiCall,
  showCard,
  pickFields,
  trimValue,
  postJson,
} from "../../../skills/e2e-video-doc/recipes/playwright-node/apiPanel";

// A flow where the API is the whole story, not a detour in the middle of a screen
// walkthrough — closes https://github.com/kleer-la/claude-plugins/issues/18.
//
// A wholesale partner never opens the storefront. It trades a password for a token,
// tries the guarded endpoint without one and is rejected, tries again with the token and
// is not, and the order it created shows up in the same storefront anyone else uses —
// found by its id, the way support would find it.
//
//   bash <plugin>/engine/run.sh api      # English
//   bash <plugin>/engine/run.sh api es

// Must match server.mjs's PARTNER_PASSWORD. Fine to read in a sample: it is a demo
// constant, not a secret, which is exactly why it is still masked on the card — the
// point being demonstrated is the shape of the flow, not this password in particular.
const PARTNER_PASSWORD = "wholesale-2024";
const PARTNER_ORDER = { customer: "Distribuidora Norte", items: [{ sku: "GFT-100", qty: 5 }] };

// The card headers translate with the narration; the recipe's default is English.
const LABELS = { en: {}, es: { request: "pedido", response: "respuesta" } };

const TEXT = {
  en: {
    token: {
      description: "A wholesale partner trades its password for a token.",
      note: "The token is what proves who is calling from here on — not the password again.",
    },
    rejected: {
      description: "The same order, with no credential at all: rejected.",
      note: "Drawn in red before the narration explains why, so the contrast with the next card carries the point on its own.",
    },
    granted: {
      description: "The token as a bearer credential: created.",
      note: "The header carries the same token the last card returned, cut to its first characters — enough to recognize, useless to steal from the video.",
    },
    log: {
      description: "What the guard kept on the way in: which partner called, never the password or the token it issued.",
      label: "access log · last entry",
      note: "This row came from the server, the same way the order id did. Nothing on this card was typed by hand.",
    },
  },
  es: {
    token: {
      description: "Un mayorista cambia su contraseña por un token.",
      note: "De acá en más, lo que prueba quién llama es el token — no la contraseña otra vez.",
    },
    rejected: {
      description: "El mismo pedido, sin ninguna credencial: rechazado.",
      note: "Se dibuja en rojo antes de que la narración explique por qué, para que el contraste con la próxima tarjeta hable solo.",
    },
    granted: {
      description: "El mismo token como credencial: creado.",
      note: "El encabezado lleva el mismo token que devolvió la tarjeta anterior, cortado a sus primeros caracteres — alcanza para reconocerlo, no sirve para robarlo del video.",
    },
    log: {
      description: "Lo que el guardián guardó al pasar: qué socio llamó, nunca la contraseña ni el token que emitió.",
      label: "registro de acceso · última entrada",
      note: "Esta fila la trajo el servidor, igual que el identificador del pedido. Nada en esta tarjeta se escribió a mano.",
    },
  },
};

test("the API as the whole story", async ({ page, request }, testInfo) => {
  const lang = testInfo.project.name as "en" | "es";
  const shots = `tmp/video_screenshots/api_${lang}`;
  const t = TEXT[lang];
  const labels = LABELS[lang];

  resetDir(shots);
  const capture = createCapture(page, shots);

  // 1. The credential. The password never appears; only its shape does.
  const tokenCall = await postJson(request, "/api/token", { password: PARTNER_PASSWORD });
  await showApiCall(page, {
    description: t.token.description,
    method: "POST",
    url: "/api/token",
    request: { password: "••••••" },
    status: tokenCall.status,
    response: { token: trimValue(tokenCall.body.token), role: tokenCall.body.role },
    note: t.token.note,
    labels,
  });
  await capture("token_emitido");

  // 2. The negative case, filmed first: without the token, the same order is refused.
  const rejected = await postJson(request, "/api/partner/orders", PARTNER_ORDER);
  await showApiCall(page, {
    description: t.rejected.description,
    method: "POST",
    url: "/api/partner/orders",
    request: PARTNER_ORDER,
    status: rejected.status,
    response: rejected.body,
    note: t.rejected.note,
    expect: "reject",
    labels,
  });
  await capture("pedido_sin_token");

  // 3. The same call, this time with the token as a bearer credential.
  const granted = await postJson(request, "/api/partner/orders", PARTNER_ORDER, tokenCall.body.token);
  await showApiCall(page, {
    description: t.granted.description,
    method: "POST",
    url: "/api/partner/orders",
    headers: { Authorization: `Bearer ${trimValue(tokenCall.body.token)}` },
    request: PARTNER_ORDER,
    status: granted.status,
    response: pickFields(granted.body, ["id", "total", "channel"]),
    note: t.granted.note,
    labels,
  });
  await capture("pedido_autorizado");

  // 4. Not an HTTP call: what the guard left behind in the server's own access log.
  const logRes = await request.get("/api/access-log");
  const { entries } = await logRes.json();
  const lastEntry = entries[entries.length - 1];
  await showCard(page, {
    description: t.log.description,
    label: t.log.label,
    text: JSON.stringify(lastEntry, null, 2),
    note: t.log.note,
    labels,
  });
  await capture("registro_de_acceso");

  // 5. Proof on a screen, not just on faith: the order the API created, found by its id
  // in the same storefront anyone else uses — and actually checked, not just shown.
  await page.goto(`/?lang=${lang}`);
  await page.fill("#track-id", granted.body.id);
  await page.click("#track-btn");
  await expect(page.locator("#track-result-id")).toHaveText(granted.body.id);
  await capture("pedido_en_pantalla", {
    scroll: "css:#track-result-id",
    highlight: "#track-result-id",
    assertInFrame: "#track-result-id",
  });
});
