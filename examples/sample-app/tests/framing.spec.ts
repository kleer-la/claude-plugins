import { test, expect } from "@playwright/test";
import {
  createCapture,
  resetDir,
} from "../../../plugins/e2e-video-doc/skills/e2e-video-doc/recipes/playwright-node/capture";
import { frameDiff } from "./pixels";

// Regression fixture for `assertInFrame`, not a video flow — nothing here is narrated.
//
// The sample app carries a sticky header and `scroll-behavior: smooth` on purpose: those
// are the conditions of a real Bootstrap-shaped app, and they are what turn a green test
// into a wrong photograph. These run against them.
const LAST_ROW = '[data-sku="GFT-100"]';

test("the scroll has landed by the time the shutter opens", async ({ page }) => {
  const shots = "tmp/framing";
  resetDir(shots);
  const capture = createCapture(page, shots);

  // Short enough that the last row starts well below the fold.
  await page.setViewportSize({ width: 1280, height: 380 });
  await page.goto("/?lang=en");
  await page.waitForSelector("#catalog tr");

  // pauseMs: 0 leaves no room for an animation to finish. If the scroll were smooth —
  // and the page asks for smooth — the row would still be in flight here.
  await capture("last_row", {
    scroll: `css:${LAST_ROW}`,
    assertInFrame: LAST_ROW,
    pauseMs: 0,
  });
});

test("a covered subject is refused instead of photographed", async ({ page }) => {
  const shots = "tmp/framing_covered";
  resetDir(shots);
  const capture = createCapture(page, shots);
  await page.goto("/?lang=en");
  await page.waitForSelector("#catalog tr");

  // The cookie wall nobody dismissed. It cannot be scrolled away from, so the retry
  // cannot rescue this one — which is the point: the failure has to be loud.
  await page.evaluate(() => {
    const wall = document.createElement("div");
    wall.className = "cookie-wall";
    wall.style.cssText = "position:fixed;inset:0;background:#000;opacity:.55;z-index:999";
    document.body.appendChild(wall);
  });

  await expect(
    capture("covered", { assertInFrame: "#cart-total", pauseMs: 0 }),
  ).rejects.toThrow(/is covered by <div\.cookie-wall>/);
});

test("a subject with no box is refused", async ({ page }) => {
  const shots = "tmp/framing_nobox";
  resetDir(shots);
  const capture = createCapture(page, shots);
  await page.goto("/?lang=en");
  await page.waitForSelector("#catalog tr");
  await page.evaluate((sel) => {
    (document.querySelector(sel) as HTMLElement).style.display = "none";
  }, LAST_ROW);

  await expect(
    capture("nobox", { assertInFrame: LAST_ROW, pauseMs: 0 }),
  ).rejects.toThrow(/has no box on the page/);
});

test("a scroll to the bottom lands before the shutter too", async ({ page }) => {
  const shots = "tmp/framing_bottom";
  resetDir(shots);
  const capture = createCapture(page, shots);
  await page.setViewportSize({ width: 1280, height: 300 });
  await page.goto("/?lang=en");
  await page.waitForSelector("#catalog tr");

  // A long way to travel, so an animated scroll cannot finish inside the shot.
  await page.evaluate(() => {
    const filler = document.createElement("div");
    filler.style.height = "4000px";
    filler.style.background = "linear-gradient(#fff, #7a8a99)";
    document.body.appendChild(filler);
  });

  // No `highlight:` and no `assertInFrame` here, and both omissions are the point. Each of
  // them scrolls on its own — `boundingBox()` inside highlightOn, the retry inside the
  // framing check — and either would quietly correct the very thing under test. A bare
  // `scroll:` with neither is also exactly what one real project's whole flow does.
  const inFlight = await capture("bottom_now", { scroll: "bottom", pauseMs: 0 });

  // The same frame, taken once the page can no longer be moving.
  await page.waitForTimeout(1200);
  const settled = await capture("bottom_settled", { pauseMs: 0 });

  // `scroll: "bottom"` through window.scrollTo was still animating after the
  // scrollIntoView path was made instant: measured 0 -> 41 -> 241 -> 270 on a short page,
  // and 0 -> 22 -> 283 -> 3396 -> 4270 on this one. Animated, the first shot is of the
  // page somewhere in mid-flight and the two frames disagree.
  expect(
    await frameDiff(page, shots, inFlight, settled),
    "the shot taken immediately should be of the same place as the settled one",
  ).toBeLessThan(0.01);
});
