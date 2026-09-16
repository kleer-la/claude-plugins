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

/**
 * Opens a `<details>` element if it is not already open. The `open` attribute is present
 * as `""` when open, which is falsy: `if (!(await el.getAttribute("open")))` reads that
 * as closed and *closes* an already-open panel, and the next `check()` on what is now a
 * hidden input waits out the whole test timeout. The attribute is `=== null` only when
 * the panel is actually closed.
 */
export async function ensureOpen(page: Page, selector: string): Promise<void> {
  const el = page.locator(selector).first();
  if ((await el.getAttribute("open")) === null) {
    await el.evaluate((node) => {
      (node as HTMLDetailsElement).open = true;
    });
  }
}

/**
 * Asserts the screen's own vocabulary: words the narration should be able to use, and
 * words that should never reach a viewer (internal jargon, field names, HTTP verbs). The
 * walkthrough is exactly where a copy regression shows, and the narration is already
 * written against the same words.
 *
 * Reads `textContent`, not `innerText`: `innerText` omits collapsed `<details>` content,
 * so a lint built on it passes or fails depending on which panel happens to be open at
 * the moment — the same trap `ensureOpen` exists for.
 */
export async function assertVocabulary(
  page: Page,
  opts: { required?: string[]; forbidden?: string[]; scope?: string },
): Promise<void> {
  const root = opts.scope ? page.locator(opts.scope).first() : page.locator("body");
  const text = (await root.evaluate((el) => el.textContent)) ?? "";
  for (const word of opts.required ?? []) {
    if (!text.includes(word)) throw new Error(`assertVocabulary: missing required word "${word}"`);
  }
  for (const word of opts.forbidden ?? []) {
    if (text.includes(word)) throw new Error(`assertVocabulary: forbidden word leaked: "${word}"`);
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
        // Document coordinates, not viewport ones. A `position: fixed` box is placed
        // against the window, and a full-page screenshot is not a window: where it ends
        // up then depends on how the browser stitches the tall image, which differs
        // between versions — measured landing at the element on one Playwright and
        // reported pinned near the top of the image on another. Absolute positioning
        // plus the scroll offset asks the question the picture actually answers: where
        // is this element on the page?
        // Clamped inside the document, and the extents are read before anything is
        // appended. A ring drawn 5px past the right edge is 5px of new scrollable area:
        // the page acquires a horizontal scrollbar, the full-page image comes out wider,
        // and every frame after it is composed differently. Measured, once.
        const docW = document.documentElement.scrollWidth;
        const docH = document.documentElement.scrollHeight;
        const left = Math.max(0, box.x + window.scrollX - gap - border);
        const top = Math.max(0, box.y + window.scrollY - gap - border);
        const width = Math.min(box.width + 2 * (gap + border), docW - left);
        const height = Math.min(box.height + 2 * (gap + border), docH - top);
        el.style.cssText =
          `position:absolute;box-sizing:border-box;pointer-events:none;z-index:2147483647;` +
          `left:${left}px;top:${top}px;width:${width}px;height:${height}px;` +
          `border:${border}px solid #d9534f;border-radius:3px;` +
          `box-shadow:0 0 0 6px rgba(217, 83, 79, .18)`;
        document.body.appendChild(el);
        // `absolute` is resolved against the nearest positioned ancestor, and a body with
        // `position: relative` — or a margin — is not the document origin. Rather than
        // assume, measure where the box actually landed and shift it by the difference.
        const drawn = el.getBoundingClientRect();
        const dx = Math.max(0, box.x - gap - border) - drawn.left;
        const dy = Math.max(0, box.y - gap - border) - drawn.top;
        if (dx || dy) {
          el.style.left = `${left + dx}px`;
          el.style.top = `${top + dy}px`;
        }
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

/** Nil when the element is whole in the viewport and visible; otherwise a phrase saying
 *  what is wrong with it. Three ways a capture goes silently wrong: the subject is off the
 *  top or bottom of the frame, it has no box at all, or something is sitting on top of it
 *  — a sticky header, a modal, a cookie bar. The last is why this asks the document what
 *  is actually painted at the middle of the element rather than trusting the rectangle.
 *  The overlay drawn above has `pointer-events: none`, so elementFromPoint sees past it.
 *
 *  `useText` measures the rendered text instead of the element's own box. A `<caption>`
 *  on a table wider than the viewport has its whole text visible at the left while its
 *  box — the table's width — runs past the right edge; same for any block inside an
 *  `overflow-x: auto` wrapper. `getBoundingClientRect()` on the element answers "is the
 *  box in frame", which is the wrong question when the box is not what the narration
 *  points at. A `Range` over the element's contents answers "is the text in frame". */
async function frameProblem(
  page: Page,
  selector: string,
  useText = false,
): Promise<string | null> {
  const loc = page.locator(selector).first();
  if (!(await loc.count())) return `did not match anything`;
  return loc.evaluate((el, useText) => {
    const r = useText
      ? (() => {
          const range = document.createRange();
          range.selectNodeContents(el);
          return range.getBoundingClientRect();
        })()
      : el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return "has no box on the page";
    if (r.top < 0) return `starts ${Math.round(-r.top)}px above the frame`;
    if (r.bottom > window.innerHeight)
      return `runs ${Math.round(r.bottom - window.innerHeight)}px past the bottom of the frame`;
    if (r.left < 0 || r.right > window.innerWidth) return "runs off the side of the frame";
    const over = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
    if (over && over !== el && !el.contains(over)) {
      const cls =
        typeof over.className === "string" && over.className.trim()
          ? "." + over.className.trim().split(/\s+/).join(".")
          : "";
      return `is covered by <${over.tagName.toLowerCase()}${cls}>`;
    }
    return null;
  }, useText);
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
      /** Refuse to take the picture unless this element is whole in the frame and
       *  nothing is covering it. A plain string checks the element's own box — wrong for
       *  a block whose box is wider than its visible text (a `<caption>` on an overflowing
       *  table, anything inside `overflow-x: auto`); pass `{ selector, text: true }` to
       *  check the rendered text instead. */
      assertInFrame?: string | { selector: string; text?: boolean };
    },
  ) {
    const frame =
      typeof opts?.assertInFrame === "string"
        ? { selector: opts.assertInFrame, text: false }
        : opts?.assertInFrame;
    const scroll = opts?.scroll;
    // `behavior: "instant"` on every branch: `window.scrollTo(0, y)` is the two-argument
    // form, which means `behavior: "auto"`, which resolves to the computed
    // `scroll-behavior` — smooth on any Bootstrap app, and then the shot is a race
    // against the pause. Measured on the sample: 0 immediately, 190 seven-tenths later.
    if (scroll === "bottom") {
      await page.evaluate(() =>
        window.scrollTo({ top: document.body.scrollHeight, behavior: "instant" }),
      );
    } else if (scroll === "top") {
      await page.evaluate(() => window.scrollTo({ top: 0, behavior: "instant" }));
    } else if (typeof scroll === "number") {
      await page.evaluate((n) => window.scrollBy({ top: n, behavior: "instant" }), scroll);
    } else if (typeof scroll === "string" && scroll.startsWith("css:")) {
      await page.locator(scroll.slice(4)).first().scrollIntoViewIfNeeded();
    } else if (typeof scroll === "string" && scroll.startsWith("text:")) {
      // By visible text, for screens where nothing useful has a stable selector.
      await page.getByText(scroll.slice(5)).first().scrollIntoViewIfNeeded();
    }
    // Checked before the box is drawn, because scrolling afterwards would leave the box
    // behind at the old position — it is placed once and does not follow.
    if (frame) {
      let problem = await frameProblem(page, frame.selector, frame.text);
      if (problem) {
        // One retry, centred rather than minimal. Two things it fixes: a framework that
        // restores scroll position asynchronously after a navigation, undoing a scroll
        // applied a moment too early; and an element parked under a sticky header, which
        // scrollIntoViewIfNeeded considers already in view and will not move.
        await page
          .locator(frame.selector)
          .first()
          .evaluate((el) => el.scrollIntoView({ block: "center", behavior: "instant" }));
        await page.waitForTimeout(300);
        problem = await frameProblem(page, frame.selector, frame.text);
        if (problem)
          throw new Error(
            `capture(${name}): ${frame.selector} ${problem}, and scrolling again did not fix it`,
          );
      }
    }

    const highlight = opts?.highlight
      ? Array.isArray(opts.highlight)
        ? opts.highlight
        : [opts.highlight]
      : [];
    if (highlight.length) await highlightOn(page, highlight);

    await page.waitForTimeout(opts?.pauseMs ?? 400);
    // Again, after the pause and immediately before the shutter, because this is what the
    // camera will see: a scroll can still be undone while the page settles, and that
    // produces a perfectly valid photograph of the wrong part of the page.
    if (frame) {
      const problem = await frameProblem(page, frame.selector, frame.text);
      if (problem)
        throw new Error(
          `capture(${name}): ${frame.selector} ${problem} at the moment of the shot`,
        );
    }
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
