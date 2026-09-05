// The smallest app worth filming. No database, no framework, no build step: `npm start`.
//
// Deliberately small but not a toy screen — it has the four things a walkthrough needs to
// exercise the plugin: a list to scroll, a total to highlight, a form to fill, and an API
// call that has nothing to photograph until `apiPanel` draws it.
import { createServer } from "node:http";
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
    const total = body.items.reduce((sum, i) => {
      const p = PRODUCTS.find((p) => p.sku === i.sku);
      return sum + (p ? p.price * i.qty : 0);
    }, 0);
    const order = {
      id: `ORD-${String(orders.length + 1).padStart(4, "0")}`,
      customer: body.customer,
      items: body.items,
      total,
      status: "confirmed",
      placed_at: new Date().toISOString(),
    };
    orders.push(order);
    return json(res, 201, order);
  }

  if (pathname === "/api/orders") return json(res, 200, { orders });

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
