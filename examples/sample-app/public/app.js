// The interface renders in the language the narration speaks. That is the plugin's own
// rule — a screen in one language under a voice in another reads as a mistake, not as a
// translation — so the sample follows it rather than merely documenting it.
const STRINGS = {
  en: {
    brand: "Sample shop",
    catalogue: "Catalogue",
    product: "Product",
    price: "Price",
    your_order: "Your order",
    total: "Total",
    name: "Name",
    name_placeholder: "Your name",
    place_order: "Place order",
    confirmed: "Order confirmed",
    add: "Add",
    empty: "Nothing added yet.",
    empty_cart: "Cart empty",
    status_confirmed: "confirmed",
    items: (n) => `${n} item${n === 1 ? "" : "s"}`,
    locale: "en-US",
  },
  es: {
    brand: "Tienda de ejemplo",
    catalogue: "Catálogo",
    product: "Producto",
    price: "Precio",
    your_order: "Tu pedido",
    total: "Total",
    name: "Nombre",
    name_placeholder: "Tu nombre",
    place_order: "Confirmar pedido",
    confirmed: "Pedido confirmado",
    add: "Agregar",
    empty: "Todavía no agregaste nada.",
    empty_cart: "Carrito vacío",
    status_confirmed: "confirmado",
    items: (n) => `${n} artículo${n === 1 ? "" : "s"}`,
    locale: "es-AR",
  },
};

const LANG = new URLSearchParams(location.search).get("lang") === "es" ? "es" : "en";
const t = STRINGS[LANG];
document.documentElement.lang = LANG;

const money = (n) => `$ ${n.toLocaleString(t.locale)}`;
const cart = new Map();

function applyStrings() {
  for (const el of document.querySelectorAll("[data-i18n]")) {
    el.textContent = t[el.dataset.i18n];
  }
  document.querySelector("#customer").placeholder = t.name_placeholder;
  document.title = t.brand;
}

async function loadCatalog() {
  const { products } = await (await fetch(`/api/products?lang=${LANG}`)).json();
  document.querySelector("#catalog").innerHTML = products
    .map(
      (p) => `<tr data-sku="${p.sku}">
        <td>${p.name}</td>
        <td class="sku">${p.sku}</td>
        <td class="price">${money(p.price)}</td>
        <td class="price"><button class="ghost add" data-sku="${p.sku}"
            data-name="${p.name}" data-price="${p.price}">${t.add}</button></td>
      </tr>`,
    )
    .join("");
}

function renderCart() {
  const lines = [...cart.values()];
  const total = lines.reduce((s, l) => s + l.price * l.qty, 0);
  document.querySelector("#cart-lines").innerHTML = lines.length
    ? lines
        .map(
          (l) =>
            `<div class="cart-line"><span>${l.qty} × ${l.name}</span><span>${money(l.price * l.qty)}</span></div>`,
        )
        .join("")
    : `<p class="cart-empty">${t.empty}</p>`;
  document.querySelector("#total-amount").textContent = money(total);
  document.querySelector("#cart-count").textContent = lines.length
    ? t.items(lines.reduce((s, l) => s + l.qty, 0))
    : t.empty_cart;
  document.querySelector("#place-order").disabled = lines.length === 0;
}

document.addEventListener("click", (e) => {
  const btn = e.target.closest("button.add");
  if (!btn) return;
  const sku = btn.dataset.sku;
  const line = cart.get(sku) ?? { sku, name: btn.dataset.name, price: +btn.dataset.price, qty: 0 };
  line.qty += 1;
  cart.set(sku, line);
  renderCart();
});

document.querySelector("#place-order").addEventListener("click", async (e) => {
  e.target.disabled = true;
  const res = await fetch("/api/orders", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      customer: document.querySelector("#customer").value,
      items: [...cart.values()].map((l) => ({ sku: l.sku, qty: l.qty })),
    }),
  });
  const order = await res.json();
  if (!res.ok) return void (e.target.disabled = false);
  document.querySelector("#order-id").textContent = order.id;
  document.querySelector("#order-status").textContent =
    order.status === "confirmed" ? t.status_confirmed : order.status;
  document.querySelector("#confirmation").classList.remove("hidden");
});

applyStrings();
loadCatalog().then(renderCart);
