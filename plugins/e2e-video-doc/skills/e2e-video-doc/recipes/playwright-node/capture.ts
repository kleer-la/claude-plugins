import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import type { Page } from "@playwright/test";

export function resetDir(dir: string): void {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
}

/** Local IIS often shows the DevExpress trial strip. Close it so demos look clean. */
export async function dismissDxTrial(page: Page): Promise<void> {
  const close = page.locator('img[alt="Close"]').first();
  try {
    await close.click({ timeout: 2500 });
    await page.waitForTimeout(200);
  } catch {
    // banner absent
  }
}

type Scroll = "bottom" | "top" | number | `css:${string}`;

/** Recuadro que se dibuja sobre lo que la narración está señalando. Se saca después del
 *  disparo, así que no ensucia el paso siguiente. En un video a tamaño completo una celda
 *  no se encuentra sola: o se la enmarca, o se recorta la imagen alrededor. */
const HIGHLIGHT_ATTR = "data-e2e-highlight";
const HIGHLIGHT_STYLE_ID = "e2e-highlight-style";
const HIGHLIGHT_CSS = `
[${HIGHLIGHT_ATTR}] {
  outline: 3px solid #d9534f !important;
  outline-offset: 2px !important;
  box-shadow: 0 0 0 6px rgba(217, 83, 79, .18) !important;
  border-radius: 3px;
}`;

async function marcar(page: Page, selectores: string[]): Promise<void> {
  // Por locator y no por document.querySelector: los selectores de Playwright (:has-text,
  // :text) no son CSS y el DOM no los entiende. Pasando por el locator valen los dos.
  await page.evaluate(
    ([styleId, css]) => {
      if (document.getElementById(styleId as string)) return;
      const style = document.createElement("style");
      style.id = styleId as string;
      style.textContent = css as string;
      document.head.appendChild(style);
    },
    [HIGHLIGHT_STYLE_ID, HIGHLIGHT_CSS] as const,
  );
  for (const sel of selectores) {
    const loc = page.locator(sel).first();
    if (!(await loc.count())) throw new Error(`highlight sin match: ${sel}`);
    await loc.evaluate((el, attr) => el.setAttribute(attr, "1"), HIGHLIGHT_ATTR);
  }
}

async function desmarcar(page: Page): Promise<void> {
  await page.evaluate((attr) => {
    document.querySelectorAll(`[${attr}]`).forEach((el) => el.removeAttribute(attr));
  }, HIGHLIGHT_ATTR);
}

export function createCapture(page: Page, dir: string) {
  let step = 0;
  return async function capture(
    name: string,
    opts?: {
      pauseMs?: number;
      scroll?: Scroll;
      fullPage?: boolean;
      /** Selectores a enmarcar en rojo durante el disparo. */
      highlight?: string | string[];
      /** Recorta la imagen alrededor de este selector, con `focusPad` px de aire. */
      focus?: string;
      focusPad?: number;
    },
  ) {
    const scroll = opts?.scroll;
    if (scroll === "bottom") {
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    } else if (scroll === "top") {
      await page.evaluate(() => window.scrollTo(0, 0));
    } else if (typeof scroll === "number") {
      await page.evaluate((n) => window.scrollBy(0, n), scroll);
    } else if (typeof scroll === "string" && scroll.startsWith("css:")) {
      await page.locator(scroll.slice(4)).first().scrollIntoViewIfNeeded();
    }
    const highlight = opts?.highlight
      ? Array.isArray(opts.highlight)
        ? opts.highlight
        : [opts.highlight]
      : [];
    if (highlight.length) await marcar(page, highlight);

    await page.waitForTimeout(opts?.pauseMs ?? 400);
    step += 1;
    const filename = `${String(step).padStart(2, "0")}_${name}.png`;

    let clip: { x: number; y: number; width: number; height: number } | undefined;
    if (opts?.focus) {
      const caja = await page.locator(opts.focus).first().boundingBox();
      if (!caja) throw new Error(`focus sin caja: ${opts.focus}`);
      const pad = opts.focusPad ?? 40;
      const vp = page.viewportSize() ?? { width: 1280, height: 800 };
      const x = Math.max(0, caja.x - pad);
      const y = Math.max(0, caja.y - pad);
      clip = {
        x,
        y,
        width: Math.min(caja.width + pad * 2, vp.width - x),
        height: Math.min(caja.height + pad * 2, vp.height - y),
      };
    }

    await page.screenshot({
      path: join(dir, filename),
      // clip y fullPage no conviven: recortar implica mirar el viewport.
      fullPage: clip ? undefined : opts?.fullPage,
      clip,
    });
    if (highlight.length) await desmarcar(page);
    return filename;
  };
}
