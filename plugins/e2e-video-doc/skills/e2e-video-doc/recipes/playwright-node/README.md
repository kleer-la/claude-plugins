# Receta Playwright (Node/TypeScript)

Copiá `capture.ts` y `apiPanel.ts` a los helpers del proyecto. No tienen
dependencias más allá de `@playwright/test`.

Extraídos de kydat-poc (`e2e-transoftweb/browser/helpers/`), donde corren contra
IIS Express en Windows.

## `capture.ts`

```ts
import { createCapture, resetDir } from "../helpers/capture";

const DIR = "tmp/e2e/alta";

test.beforeAll(() => resetDir(DIR));

test("alta de un pedido", { tag: "@video" }, async ({ page }) => {
  test.skip(!process.env.RUN_VIDEO_TESTS, "sólo con RUN_VIDEO_TESTS=1");
  const capture = createCapture(page, DIR);

  await page.goto("/");
  await capture("inicio");
  await capture("total", { highlight: "#total", scroll: "css:#total" });
  await capture("detalle", { focus: ".panel-detalle", focusPad: 40 });
});
```

| Opción | Qué hace |
|---|---|
| `highlight` | Recuadro rojo sobre uno o más selectores durante el disparo. Se saca después, no ensucia el paso siguiente. Falla si no matchea. |
| `focus` / `focusPad` | Recorta la imagen alrededor de un selector, con aire. |
| `scroll` | `"top"` \| `"bottom"` \| número de píxeles \| `"css:<selector>"`. |
| `fullPage` | Página completa. No convive con `focus` — recortar implica mirar el viewport. |
| `pauseMs` | Espera antes del disparo (default 400). |

`dismissDxTrial` cierra la franja de trial de DevExpress. Si el proyecto tiene
otro banner de entorno, agregá el equivalente y llamalo desde el mismo lugar.

## `apiPanel.ts`

Para flujos donde parte de lo que se cuenta pasa por la API y no por la pantalla.
Dibuja la llamada como una ficha y la fotografía con el mismo `capture`.

```ts
await mostrarLlamada(page, {
  descripcion: "El dador pide su credencial. La contraseña va en el cuerpo, no en la URL.",
  metodo: "POST",
  url: "/api/v4/credenciales/usuario",
  request: recortarCuerpo(cuerpo, ["Password"]),
  status: 200,
  response: { Token: recortarValor(token) },
  observacion: "El OperationId es el Id del usuario.",
});
await capture("credencial_emitida");
```

`recortarCuerpo` se queda con las claves que la descripción señala y dice cuántas
quedaron afuera. `recortarValor` deja ver el principio de un valor largo, no el
valor — usalo siempre para credenciales.

`esperado: "rechazo"` pinta la ficha en rojo, para mostrar el caso negativo.
