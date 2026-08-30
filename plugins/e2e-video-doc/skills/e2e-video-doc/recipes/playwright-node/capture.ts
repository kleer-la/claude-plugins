import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import type { Page } from "@playwright/test";

export function resetDir(dir: string): void {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
}

/**
 * Closes a trial or environment banner so the video shows the product, not the
 * scaffolding. Point it at whatever your stack puts on top of the page — a component
 * library's trial strip, a staging ribbon, a debug bar.
 */
export async function dismissBanner(page: Page, selector: string): Promise<void> {
  const close = page.locator(selector).first();
  try {
    await close.click({ timeout: 2500 });
    await page.waitForTimeout(200);
  } catch {
    // banner absent
  }
}

type Scroll = "bottom" | "top" | number | `css:${string}`;

/** Box drawn over whatever the narration is pointing at. Removed after the shot, so it
 *  does not leak into the next step. At full size a single cell cannot be found on its
 *  own: either you frame it, or you crop the image around it. */
const HIGHLIGHT_ATTR = "data-e2e-highlight";
const HIGHLIGHT_STYLE_ID = "e2e-highlight-style";
const HIGHLIGHT_CSS = `
[${HIGHLIGHT_ATTR}] {
  outline: 3px solid #d9534f !important;
  outline-offset: 2px !important;
  box-shadow: 0 0 0 6px rgba(217, 83, 79, .18) !important;
  border-radius: 3px;
}`;

async function highlightOn(page: Page, selectors: string[]): Promise<void> {
  // Through the locator and not document.querySelector: Playwright selectors
  // (:has-text, :text) are not CSS and the DOM does not understand them. Going
  // through the locator accepts both.
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
  for (const sel of selectors) {
    const loc = page.locator(sel).first();
    // Loud failure on purpose: a highlight that does not match is narration pointing at
    // something no longer on the screen — exactly the change the video exists to catch.
    if (!(await loc.count())) throw new Error(`highlight did not match: ${sel}`);
    await loc.evaluate((el, attr) => el.setAttribute(attr, "1"), HIGHLIGHT_ATTR);
  }
}

async function highlightOff(page: Page): Promise<void> {
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
      /** Selectors to frame in red during the shot. */
      highlight?: string | string[];
      /** Crops the image around this selector, with `focusPad` px of air. */
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
    if (highlight.length) await highlightOn(page, highlight);

    await page.waitForTimeout(opts?.pauseMs ?? 400);
    step += 1;
    const filename = `${String(step).padStart(2, "0")}_${name}.png`;

    let clip: { x: number; y: number; width: number; height: number } | undefined;
    if (opts?.focus) {
      const box = await page.locator(opts.focus).first().boundingBox();
      if (!box) throw new Error(`focus has no box: ${opts.focus}`);
      const pad = opts.focusPad ?? 40;
      const vp = page.viewportSize() ?? { width: 1280, height: 800 };
      const x = Math.max(0, box.x - pad);
      const y = Math.max(0, box.y - pad);
      clip = {
        x,
        y,
        width: Math.min(box.width + pad * 2, vp.width - x),
        height: Math.min(box.height + pad * 2, vp.height - y),
      };
    }

    await page.screenshot({
      path: join(dir, filename),
      // clip and fullPage do not coexist: cropping means looking at the viewport.
      fullPage: clip ? undefined : opts?.fullPage,
      clip,
    });
    if (highlight.length) await highlightOff(page);
    return filename;
  };
}
