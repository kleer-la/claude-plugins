import type { APIRequestContext, Page } from "@playwright/test";

/**
 * Hace VISIBLE una llamada a la API dentro de un video que, por lo demás, muestra
 * pantallas.
 *
 * El problema: una llamada HTTP no tiene nada que fotografiar. Si el video sólo muestra
 * el resultado en la web, el espectador tiene que creer que la API hizo algo. Acá la
 * llamada se dibuja como una ficha —qué se pidió, qué contestó, y qué hay que mirar— y se
 * fotografía con el mismo `capture` que el resto del flujo, así entra en el mismo MP4 sin
 * tocar el pipeline de narración.
 *
 * El recorte es a propósito: un cuerpo entero de Carga son cuarenta campos y en pantalla
 * no se lee ninguno. Se muestran las líneas que la descripción está señalando.
 */

export interface Llamada {
  /** Qué está pasando, en una línea. Es lo que el espectador lee primero. */
  descripcion: string;
  metodo: string;
  url: string;
  /** Cabeceras a mostrar. La credencial se recorta sola, ver `recortarValor`. */
  headers?: Record<string, string>;
  /** Cuerpo del pedido, ya recortado a lo que importa. */
  request?: unknown;
  status?: number;
  /** Cuerpo de la respuesta, ya recortado. */
  response?: unknown;
  /** Lo que hay que mirar de esta llamada. Se resalta abajo. */
  observacion?: string;
  /** Marca la ficha como el caso negativo (rojo en vez de verde). */
  esperado?: "ok" | "rechazo";
}

/** Deja ver el principio de un valor largo, no el valor. Sirve para la credencial. */
export function recortarValor(valor: string, visibles = 8): string {
  return valor.length <= visibles ? valor : `${valor.slice(0, visibles)}…`;
}

/** Se queda con estas claves del objeto, en este orden. El resto no entra en pantalla. */
export function recortarCuerpo(cuerpo: Record<string, unknown>, claves: string[]): Record<string, unknown> {
  const salida: Record<string, unknown> = {};
  for (const k of claves) if (k in cuerpo) salida[k] = cuerpo[k];
  const resto = Object.keys(cuerpo).length - Object.keys(salida).length;
  if (resto > 0) salida["…"] = `${resto} campos más`;
  return salida;
}

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function bloque(titulo: string, cuerpo: string | undefined): string {
  if (!cuerpo) return "";
  return `<div class="bloque"><div class="et">${esc(titulo)}</div><pre>${esc(cuerpo)}</pre></div>`;
}

function json(v: unknown): string | undefined {
  if (v === undefined) return undefined;
  return typeof v === "string" ? v : JSON.stringify(v, null, 2);
}

function html(l: Llamada): string {
  const rechazo = l.esperado === "rechazo";
  const cabeceras = l.headers
    ? Object.entries(l.headers)
        .map(([k, v]) => `${k}: ${v}`)
        .join("\n")
    : undefined;

  return `<!doctype html><meta charset="utf-8"><style>
  :root { color-scheme: light }
  * { box-sizing: border-box }
  body { margin:0; padding:44px 56px; background:#f4f6f8; font:16px/1.5 "Segoe UI",system-ui,sans-serif; color:#1b1f24 }
  .ficha { background:#fff; border:1px solid #d6dbe1; border-radius:10px; overflow:hidden;
           box-shadow:0 2px 14px rgba(20,30,45,.10) }
  .desc { padding:22px 28px; font-size:26px; font-weight:600; line-height:1.35;
          border-bottom:1px solid #e7ebef }
  .llamada { padding:18px 28px; font-family:Consolas,"Courier New",monospace; font-size:21px;
             background:#1b2733; color:#e8eef5; word-break:break-all }
  .verbo { display:inline-block; padding:2px 12px; border-radius:5px; margin-right:12px;
           font-weight:700; background:#3d7dca; color:#fff }
  .cuerpo { display:grid; grid-template-columns:1fr 1fr; gap:0 }
  .bloque { padding:18px 28px; border-top:1px solid #e7ebef }
  .bloque + .bloque { border-left:1px solid #e7ebef }
  .et { font-size:14px; letter-spacing:.10em; text-transform:uppercase; color:#66707b; margin-bottom:8px }
  pre { margin:0; font-family:Consolas,"Courier New",monospace; font-size:19px; line-height:1.45;
        white-space:pre-wrap; word-break:break-word }
  .estado { padding:16px 28px; border-top:1px solid #e7ebef; font-size:22px; font-weight:700;
            color:${rechazo ? "#a4302a" : "#1d6b3f"}; background:${rechazo ? "#fdf2f1" : "#f1f8f3"} }
  .obs { margin-top:18px; padding:18px 24px; border-left:5px solid ${rechazo ? "#c0463d" : "#3d7dca"};
         background:#fff; border-radius:0 8px 8px 0; font-size:21px; line-height:1.45 }
  </style>
  <div class="ficha">
    <div class="desc">${esc(l.descripcion)}</div>
    <div class="llamada"><span class="verbo">${esc(l.metodo)}</span>${esc(l.url)}</div>
    ${l.status !== undefined ? `<div class="estado">${l.status} ${esc(textoDeEstado(l.status))}</div>` : ""}
    <div class="cuerpo">
      ${bloque("pedido", [cabeceras, json(l.request)].filter(Boolean).join("\n\n") || undefined)}
      ${bloque("respuesta", json(l.response))}
    </div>
  </div>
  ${l.observacion ? `<div class="obs">${esc(l.observacion)}</div>` : ""}`;
}

function textoDeEstado(status: number): string {
  const t: Record<number, string> = {
    200: "OK",
    201: "Created",
    400: "Bad Request",
    401: "Unauthorized",
    403: "Forbidden",
    409: "Conflict",
    429: "Too Many Requests",
  };
  return t[status] ?? "";
}

/** Dibuja la ficha en la página y la deja lista para que `capture` la fotografíe. */
export async function mostrarLlamada(page: Page, l: Llamada): Promise<void> {
  await page.setContent(html(l), { waitUntil: "load" });
}

/** Ficha de texto libre, para lo que no es una llamada (por ejemplo, la Traza). */
export async function mostrarFicha(
  page: Page,
  o: { descripcion: string; etiqueta: string; texto: string; observacion?: string },
): Promise<void> {
  await page.setContent(
    html({
      descripcion: o.descripcion,
      metodo: "SQL",
      url: o.etiqueta,
      response: o.texto,
      observacion: o.observacion,
    }),
    { waitUntil: "load" },
  );
}

/** POST JSON con la credencial en el header, que es lo que separa v4 del legacy. */
export async function postJson(
  api: APIRequestContext,
  url: string,
  data: unknown,
  bearer?: string,
): Promise<{ status: number; body: any; texto: string }> {
  const r = await api.post(url, {
    data,
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
  const texto = await r.text();
  let body: any = undefined;
  try {
    body = JSON.parse(texto);
  } catch {
    body = undefined;
  }
  return { status: r.status(), body, texto };
}
