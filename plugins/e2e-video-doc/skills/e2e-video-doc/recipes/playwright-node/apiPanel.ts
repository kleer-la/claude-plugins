import type { APIRequestContext, Page } from "@playwright/test";

/**
 * Makes an API call VISIBLE inside a video that otherwise shows screens.
 *
 * The problem: an HTTP call has nothing to photograph. If the video only shows the
 * result on screen, the viewer has to take on faith that the API did anything. Here the
 * call is drawn as a card — what was sent, what came back, and what to look at — and is
 * photographed with the same `capture` as the rest of the walkthrough, so it lands in the
 * same MP4 without touching the narration pipeline.
 *
 * The trimming is deliberate: a full request body of forty fields is forty fields nobody
 * can read on screen. Show the lines the description is pointing at.
 */

/** Card labels. Override to match the narration language. */
export interface CardLabels {
  request: string;
  response: string;
}

const DEFAULT_LABELS: CardLabels = { request: "request", response: "response" };

export interface ApiCall {
  /** What is happening, in one line. This is what the viewer reads first. */
  description: string;
  method: string;
  url: string;
  /** Headers to show. Trim the credential yourself with `trimValue`. */
  headers?: Record<string, string>;
  /** Request body, already trimmed to what matters. */
  request?: unknown;
  status?: number;
  /** Response body, already trimmed. */
  response?: unknown;
  /** What to look at in this call. Highlighted underneath. */
  note?: string;
  /** Marks the card as the negative case (red instead of green). */
  expect?: "ok" | "reject";
  labels?: Partial<CardLabels>;
}

/** Shows the start of a long value, not the value. Use it for credentials. */
export function trimValue(value: string, visible = 8): string {
  return value.length <= visible ? value : `${value.slice(0, visible)}…`;
}

/** Keeps these keys, in this order. Everything else stays off screen. */
export function pickFields(body: Record<string, unknown>, keys: string[]): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of keys) if (k in body) out[k] = body[k];
  const rest = Object.keys(body).length - Object.keys(out).length;
  if (rest > 0) out["…"] = `${rest} more fields`;
  return out;
}

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function block(label: string, body: string | undefined): string {
  if (!body) return "";
  return `<div class="block"><div class="label">${esc(label)}</div><pre>${esc(body)}</pre></div>`;
}

function json(v: unknown): string | undefined {
  if (v === undefined) return undefined;
  return typeof v === "string" ? v : JSON.stringify(v, null, 2);
}

function statusText(status: number): string {
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

function html(c: ApiCall): string {
  const reject = c.expect === "reject";
  const labels = { ...DEFAULT_LABELS, ...c.labels };
  const headers = c.headers
    ? Object.entries(c.headers)
        .map(([k, v]) => `${k}: ${v}`)
        .join("\n")
    : undefined;

  return `<!doctype html><meta charset="utf-8"><style>
  :root { color-scheme: light }
  * { box-sizing: border-box }
  body { margin:0; padding:44px 56px; background:#f4f6f8; font:16px/1.5 "Segoe UI",system-ui,sans-serif; color:#1b1f24 }
  .card { background:#fff; border:1px solid #d6dbe1; border-radius:10px; overflow:hidden;
          box-shadow:0 2px 14px rgba(20,30,45,.10) }
  .desc { padding:22px 28px; font-size:26px; font-weight:600; line-height:1.35;
          border-bottom:1px solid #e7ebef }
  .call { padding:18px 28px; font-family:Consolas,"Courier New",monospace; font-size:21px;
          background:#1b2733; color:#e8eef5; word-break:break-all }
  .verb { display:inline-block; padding:2px 12px; border-radius:5px; margin-right:12px;
          font-weight:700; background:#3d7dca; color:#fff }
  .bodies { display:grid; grid-template-columns:1fr 1fr; gap:0 }
  .block { padding:18px 28px; border-top:1px solid #e7ebef }
  .block + .block { border-left:1px solid #e7ebef }
  .label { font-size:14px; letter-spacing:.10em; text-transform:uppercase; color:#66707b; margin-bottom:8px }
  pre { margin:0; font-family:Consolas,"Courier New",monospace; font-size:19px; line-height:1.45;
        white-space:pre-wrap; word-break:break-word }
  .status { padding:16px 28px; border-top:1px solid #e7ebef; font-size:22px; font-weight:700;
            color:${reject ? "#a4302a" : "#1d6b3f"}; background:${reject ? "#fdf2f1" : "#f1f8f3"} }
  .note { margin-top:18px; padding:18px 24px; border-left:5px solid ${reject ? "#c0463d" : "#3d7dca"};
          background:#fff; border-radius:0 8px 8px 0; font-size:21px; line-height:1.45 }
  </style>
  <div class="card">
    <div class="desc">${esc(c.description)}</div>
    <div class="call"><span class="verb">${esc(c.method)}</span>${esc(c.url)}</div>
    ${c.status !== undefined ? `<div class="status">${c.status} ${esc(statusText(c.status))}</div>` : ""}
    <div class="bodies">
      ${block(labels.request, [headers, json(c.request)].filter(Boolean).join("\n\n") || undefined)}
      ${block(labels.response, json(c.response))}
    </div>
  </div>
  ${c.note ? `<div class="note">${esc(c.note)}</div>` : ""}`;
}

/** Draws the card on the page, ready for `capture` to photograph it. */
export async function showApiCall(page: Page, call: ApiCall): Promise<void> {
  await page.setContent(html(call), { waitUntil: "load" });
}

/** Free-text card, for what is not an API call — a query result, a log line, a file. */
export async function showCard(
  page: Page,
  o: { description: string; label: string; text: string; note?: string; labels?: Partial<CardLabels> },
): Promise<void> {
  await page.setContent(
    html({
      description: o.description,
      method: "SQL",
      url: o.label,
      response: o.text,
      note: o.note,
      labels: o.labels,
    }),
    { waitUntil: "load" },
  );
}

/** JSON POST with an optional bearer credential. */
export async function postJson(
  api: APIRequestContext,
  url: string,
  data: unknown,
  bearer?: string,
): Promise<{ status: number; body: any; text: string }> {
  const r = await api.post(url, {
    data,
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
  const text = await r.text();
  let body: any = undefined;
  try {
    body = JSON.parse(text);
  } catch {
    body = undefined;
  }
  return { status: r.status(), body, text };
}
