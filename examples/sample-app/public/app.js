const money = (n) => `$ ${n.toLocaleString("es-AR")}`;
const cart = new Map();

async function loadCatalog() {
  const { products } = await (await fetch("/api/products")).json();
  document.querySelector("#catalog").innerHTML = products
    .map(
      (p) => `<tr data-sku="${p.sku}">
        <td>${p.name}</td>
        <td class="sku">${p.sku}</td>
        <td class="price">${money(p.price)}</td>
        <td class="price"><button class="ghost add" data-sku="${p.sku}"
            data-name="${p.name}" data-price="${p.price}">Agregar</button></td>
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
    : '<p class="cart-empty">Todavía no agregaste nada.</p>';
  document.querySelector("#total-amount").textContent = money(total);
  document.querySelector("#cart-count").textContent = lines.length
    ? `${lines.reduce((s, l) => s + l.qty, 0)} artículos`
    : "Carrito vacío";
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
  document.querySelector("#order-status").textContent = order.status;
  document.querySelector("#confirmation").classList.remove("hidden");
});

loadCatalog().then(renderCart);
