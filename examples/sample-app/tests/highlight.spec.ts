import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { Page } from "@playwright/test";
import {
  createCapture,
  resetDir,
} from "../../../plugins/e2e-video-doc/skills/e2e-video-doc/recipes/playwright-node/capture";

// Regression fixture for the highlight box, not a video flow — nothing here is narrated.
//
// The box used to be a mark on the element it framed, and any framework that re-renders
// that node between the mark and the screenshot took the box with it: selector matched,
// test green, photograph empty. A fork of this recipe carried that bug for two releases
// (kleer-la/claude-plugins#11), which is why the recipe now ships the test.
const SHOTS = "tmp/highlight";
const CATALOG = "#catalog";
const SEL = '[data-sku="CUP-010"]';

/** Pixels close to the highlight's #d9534f, counted by drawing the PNG into a canvas in
 *  the browser — no image library, and no dependency on ffmpeg being installed. */
async function redPixels(page: Page, file: string): Promise<number> {
  const b64 = readFileSync(join(process.cwd(), SHOTS, file)).toString("base64");
  return page.evaluate(async (src) => {
    const img = new Image();
    img.src = `data:image/png;base64,${src}`;
    await img.decode();
    const canvas = document.createElement("canvas");
    canvas.width = img.width;
    canvas.height = img.height;
    const ctx = canvas.getContext("2d")!;
    ctx.drawImage(img, 0, 0);
    const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
    let n = 0;
    for (let i = 0; i < data.length; i += 4) {
      if (data[i] > 170 && data[i + 1] < 120 && data[i + 2] < 120) n++;
    }
    return n;
  }, b64);
}

test("the box survives the framework re-rendering the node it frames", async ({ page }) => {
  resetDir(SHOTS);
  const capture = createCapture(page, SHOTS);
  await page.goto("/?lang=en");
  await page.waitForSelector("#catalog tr");

  const control = await capture("control");
  const baseline = await capture("baseline", { highlight: SEL });

  // The faithful stand-in for a Turbo stream, a React render or a DevExpress grid
  // callback: the markup the server sent, put back over the live node from a timer that
  // fires while capture is inside its pause.
  //
  // NOT cloneNode(true) — a clone copies attributes, so a mark on the element would ride
  // along and this test would pass against the very bug it exists to catch.
  const original = await page.locator(CATALOG).innerHTML();
  await page.evaluate(
    ({ sel, html }) => {
      setTimeout(() => {
        document.querySelector(sel)!.innerHTML = html;
      }, 120);
    },
    { sel: CATALOG, html: original },
  );
  const remounted = await capture("remounted", { highlight: SEL, pauseMs: 500 });

  const clean = await redPixels(page, control);
  const drawn = await redPixels(page, baseline);
  const survived = await redPixels(page, remounted);

  expect(clean, "the page draws no red of its own, so any red is the box").toBe(0);
  expect(drawn, "the box is in the undisturbed shot").toBeGreaterThan(1000);
  // 0 here is the regression: the mark left with the node and nothing failed.
  expect(survived, "the box is still there after the re-render").toBeGreaterThan(1000);
  // and it is the same box, in the same place, not a smaller remnant
  expect(Math.abs(survived - drawn)).toBeLessThan(drawn * 0.02);
});
