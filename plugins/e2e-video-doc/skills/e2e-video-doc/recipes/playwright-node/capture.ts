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

type Scroll = "bottom" | "top" | number | `css:${string}` | `text:${string}`;

/** Box drawn over whatever the narration is pointing at. Removed after the shot, so it
 *  does not leak into the next step. At full size a single cell cannot be found on its
 *  own: either you frame it, or you crop the image around it.
 *
 *  It is its own element on document.body, not a mark on the element it frames. A mark
 *  on the element leaves with the element the moment the framework re-renders that node,
 *  and the loss is silent: the selector matched, the test passes, the photograph simply
 *  has no box on it. Measured on a real app — the mark scored 3411 red pixels before a
 *  re-render replaced the node and 0 after, green test both times. Nothing appended to
 *  document.body is reachable by a re-render of the app's own tree. */
const OVERLAY_ATTR = "data-e2e-overlay";
// Reproduces what `outline: 3px` at `outline-offset: 2px` used to draw: 2px of air, a
// 3px ring, then the glow outside it.
const OVERLAY_GAP = 2;
const OVERLAY_BORDER = 3;

async function highlightOn(page: Page, selectors: string[]): Promise<void> {
  for (const sel of selectors) {
    // Through the locator and not document.querySelector: Playwright selectors
    // (:has-text, :text) are not CSS and the DOM does not understand them. Going
    // through the locator accepts both.
    const loc = page.locator(sel).first();
    // Loud failure on purpose: a highlight that does not match is narration pointing at
    // something no longer on the screen — exactly the change the video exists to catch.
    if (!(await loc.count())) throw new Error(`highlight did not match: ${sel}`);
    const box = await loc.boundingBox();
    // Matched but unphotographable — display:none, zero-sized — is the same kind of
    // silence, so it fails the same way.
    if (!box) throw new Error(`highlight has no box: ${sel}`);
    await page.evaluate(
      ({ attr, box, gap, border }) => {
        const el = document.createElement("div");
        el.setAttribute(attr, "1");
        el.style.cssText =
          `position:fixed;box-sizing:border-box;pointer-events:none;z-index:2147483647;` +
          `left:${box.x - gap - border}px;top:${box.y - gap - border}px;` +
          `width:${box.width + 2 * (gap + border)}px;` +
          `height:${box.height + 2 * (gap + border)}px;` +
          `border:${border}px solid #d9534f;border-radius:3px;` +
          `box-shadow:0 0 0 6px rgba(217, 83, 79, .18)`;
        document.body.appendChild(el);
      },
      { attr: OVERLAY_ATTR, box, gap: OVERLAY_GAP, border: OVERLAY_BORDER },
    );
  }
}

async function highlightOff(page: Page): Promise<void> {
  await page.evaluate((attr) => {
    document.querySelectorAll(`[${attr}]`).forEach((el) => el.remove());
  }, OVERLAY_ATTR);
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
    } else if (typeof scroll === "string" && scroll.startsWith("text:")) {
      // By visible text, for screens where nothing useful has a stable selector.
      await page.getByText(scroll.slice(5)).first().scrollIntoViewIfNeeded();
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
