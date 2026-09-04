import { test, expect } from "@playwright/test";
import {
  createCapture,
  resetDir,
} from "../../../plugins/e2e-video-doc/skills/e2e-video-doc/recipes/playwright-node/capture";

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
