import { test } from "@playwright/test";
import {
  createCapture,
  resetDir,
} from "../../../plugins/e2e-video-doc/skills/e2e-video-doc/recipes/playwright-node/capture";
import {
  showApiCall,
  pickFields,
  postJson,
} from "../../../plugins/e2e-video-doc/skills/e2e-video-doc/recipes/playwright-node/apiPanel";

// Captures the walkthrough this sample demonstrates: browse, add to the cart, order, and
// see the API call that made it happen.
//
// Unlike your project, which COPIES the recipe into itself, this imports it straight from
// recipes/playwright-node/. That is deliberate: it makes the sample a regression fixture,
// so a change that breaks `capture` or `apiPanel` fails here before it reaches anyone.
//
//   bash <plugin>/engine/run.sh checkout

const SHOTS = "tmp/video_screenshots/checkout";

test("checkout walkthrough", async ({ page, request }) => {
  resetDir(SHOTS);
  const capture = createCapture(page, SHOTS);

  await page.goto("/");
  await page.waitForSelector("#catalog tr");
  await capture("catalogo");

  // A red box around the row the narration is about to name.
  await capture("producto_elegido", { highlight: '[data-sku="CUP-010"]' });

  await page.click('button.add[data-sku="CUP-010"]');
  await page.click('button.add[data-sku="TEA-001"]');
  await capture("carrito_con_articulos", { highlight: "#cart-total" });

  await page.fill("#customer", "Ana Gutierrez");
  await capture("datos_del_cliente");

  // Placed through the API, so the card can show what actually crossed the wire.
  // pickFields keeps what the narration points at; the rest stays off screen.
  const { status, body } = await postJson(request, "/api/orders", {
    customer: "Ana Gutierrez",
    items: [
      { sku: "CUP-010", qty: 1 },
      { sku: "TEA-001", qty: 1 },
    ],
  });

  await showApiCall(page, {
    description: "El pedido se confirma con una sola llamada.",
    method: "POST",
    url: "/api/orders",
    request: { customer: "Ana Gutierrez", items: [{ sku: "CUP-010", qty: 1 }] },
    status,
    response: pickFields(body as Record<string, unknown>, ["id", "total", "status"]),
    note: "El identificador del pedido lo asigna el servidor, no el navegador.",
  });
  await capture("api_pedido_confirmado");

  // Back to the browser, where the same order is placed on screen.
  await page.goto("/");
  await page.waitForSelector("#catalog tr");
  await page.click('button.add[data-sku="CUP-010"]');
  await page.fill("#customer", "Ana Gutierrez");
  await page.click("#place-order");
  await page.waitForSelector("#confirmation:not(.hidden)");
  await capture("pedido_confirmado", { highlight: "#confirmation" });
});
