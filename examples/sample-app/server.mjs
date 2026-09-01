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

const PRODUCTS = [
  { sku: "TEA-001", name: "Yerba mate, 1kg", price: 4200 },
  { sku: "TEA-002", name: "Té de menta, 100g", price: 1850 },
  { sku: "CUP-010", name: "Mate de calabaza", price: 9500 },
  { sku: "CUP-011", name: "Bombilla de acero", price: 3400 },
  { sku: "GFT-100", name: "Set de regalo", price: 15800 },
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

  if (pathname === "/api/products") return json(res, 200, { products: PRODUCTS });

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
