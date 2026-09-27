// The smallest app worth filming. No database, no framework, no build step: `npm start`.
//
// Deliberately small but not a toy screen — it has the five things a walkthrough needs to
// exercise the plugin: a list to scroll, a total to highlight, a form to fill, an API call
// that has nothing to photograph until `apiPanel` draws it, and a second, guarded API that
// is the whole story instead of a detour — a credential, a rejection, an authorized call,
// and an audit trail.
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("./public", import.meta.url));
const PORT = Number(process.env.PORT ?? 3210);

// Names in both languages: a walkthrough narrated in English over a Spanish catalogue
// reads as a mistake rather than as a translation, which is the rule the plugin's own
// gotchas insist on. Prices and SKUs are the same either way.
const PRODUCTS = [
  { sku: "TEA-001", price: 4200, name: { en: "Yerba mate, 1kg", es: "Yerba mate, 1kg" } },
  { sku: "TEA-002", price: 1850, name: { en: "Mint tea, 100g", es: "Té de menta, 100g" } },
  { sku: "CUP-010", price: 9500, name: { en: "Gourd mate cup", es: "Mate de calabaza" } },
  { sku: "CUP-011", price: 3400, name: { en: "Steel straw", es: "Bombilla de acero" } },
  { sku: "GFT-100", price: 15800, name: { en: "Gift set", es: "Set de regalo" } },
];

const orders = [];
const MIME = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript" };

const json = (res, status, body) => {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
};

// The problem-details shape is what the negative card in the `api` flow draws: a real
// rejection, not a hand-typed one.
const problem = (res, status, extra) => {
  res.writeHead(status, { "content-type": "application/problem+json" });
  res.end(JSON.stringify({ type: "about:blank", status, ...extra }));
};

// The one credential this sample recognizes. A wholesale partner — a client that places
// orders through the API rather than through the storefront — trades it for a token.
const PARTNER_PASSWORD = "wholesale-2024";
const TOKENS = new Map(); // token -> { role }

// What the guard on /api/partner/orders records, and nothing else: not the password, not
// the token, not the order body. Capped so a long-running demo server does not grow forever.
const ACCESS_LOG = [];
function logAccess(method, path, user) {
  ACCESS_LOG.push({ method, path, user });
  if (ACCESS_LOG.length > 50) ACCESS_LOG.shift();
}

function makeOrder(body) {
  const total = body.items.reduce((sum, i) => {
    const p = PRODUCTS.find((p) => p.sku === i.sku);
    return sum + (p ? p.price * i.qty : 0);
  }, 0);
  return {
    id: `ORD-${String(orders.length + 1).padStart(4, "0")}`,
    customer: body.customer,
    items: body.items,
    total,
    status: "confirmed",
    placed_at: new Date().toISOString(),
  };
}

const readBody = (req) =>
  new Promise((resolve) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      try {
        resolve(JSON.parse(raw || "{}"));
      } catch {
        resolve(null);
      }
    });
  });

createServer(async (req, res) => {
  const { pathname } = new URL(req.url, `http://${req.headers.host}`);

  if (pathname === "/api/products") {
    const lang = new URL(req.url, `http://${req.headers.host}`).searchParams.get("lang") === "es" ? "es" : "en";
    return json(res, 200, {
      products: PRODUCTS.map((p) => ({ sku: p.sku, price: p.price, name: p.name[lang] })),
    });
  }

  if (pathname === "/api/orders" && req.method === "POST") {
    const body = await readBody(req);
    // A real 400, so a walkthrough can film the rejection as easily as the success.
    if (!body?.customer || !body?.items?.length) {
      return json(res, 400, { error: "customer and items are required" });
    }
    const order = makeOrder(body);
    orders.push(order);
    return json(res, 201, order);
  }

  if (pathname === "/api/orders") return json(res, 200, { orders });

  if (pathname.startsWith("/api/orders/") && req.method === "GET") {
    const order = orders.find((o) => o.id === pathname.slice("/api/orders/".length));
    if (!order) return json(res, 404, { error: "no such order" });
    return json(res, 200, order);
  }

  // A second, guarded API: a partner gets a credential and creates orders through it
  // instead of through the storefront. Deliberately a separate route from /api/orders
  // above — that one stays open, because it is what the browser's own "Place order"
  // button calls, and gating it would break the checkout walkthrough along with it.
  if (pathname === "/api/token" && req.method === "POST") {
    const body = await readBody(req);
    if (body?.password !== PARTNER_PASSWORD) {
      return problem(res, 401, { title: "Invalid credentials" });
    }
    const token = randomUUID().replace(/-/g, "");
    const role = "partner";
    TOKENS.set(token, { role });
    return json(res, 200, { token, role });
  }

  if (pathname === "/api/partner/orders" && req.method === "POST") {
    const auth = req.headers["authorization"] ?? "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : undefined;
    const grant = token ? TOKENS.get(token) : undefined;
    if (!grant) {
      return problem(res, 401, {
        title: "Unauthorized",
        detail: "POST /api/token first, then send its token as a bearer credential.",
      });
    }
    const body = await readBody(req);
    if (!body?.customer || !body?.items?.length) {
      return json(res, 400, { error: "customer and items are required" });
    }
    const order = makeOrder(body);
    orders.push(order);
    logAccess("POST", "/api/partner/orders", grant.role);
    return json(res, 201, { ...order, channel: "partner" });
  }

  if (pathname === "/api/access-log") return json(res, 200, { entries: ACCESS_LOG });

  const file = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
  try {
    const body = await readFile(join(ROOT, file));
    res.writeHead(200, { "content-type": MIME[extname(file)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("Not Found");
  }
}).listen(PORT, () => console.log(`sample-app on http://127.0.0.1:${PORT}`));
