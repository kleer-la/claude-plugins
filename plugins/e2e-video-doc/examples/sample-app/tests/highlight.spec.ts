import { test, expect } from "@playwright/test";
import { redPixels, redBounds } from "./pixels";
import {
  createCapture,
  resetDir,
} from "../../../skills/e2e-video-doc/recipes/playwright-node/capture";

// Regression fixture for the highlight box, not a video flow — nothing here is narrated.
//
// The box used to be a mark on the element it framed, and any framework that re-renders
// that node between the mark and the screenshot took the box with it: selector matched,
// test green, photograph empty. A fork of this recipe carried that bug for two releases
// (kleer-la/claude-plugins#11), which is why the recipe now ships the test.
const SHOTS = "tmp/highlight";
const CATALOG = "#catalog";
const SEL = '[data-sku="CUP-010"]';

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

  const clean = await redPixels(page, SHOTS, control);
  const drawn = await redPixels(page, SHOTS, baseline);
  const survived = await redPixels(page, SHOTS, remounted);

  expect(clean, "the page draws no red of its own, so any red is the box").toBe(0);
  expect(drawn, "the box is in the undisturbed shot").toBeGreaterThan(1000);
  // 0 here is the regression: the mark left with the node and nothing failed.
  expect(survived, "the box is still there after the re-render").toBeGreaterThan(1000);
  // and it is the same box, in the same place, not a smaller remnant
  expect(Math.abs(survived - drawn)).toBeLessThan(drawn * 0.02);
});

test("the box frames the element in a full-page shot of a scrolled page", async ({ page }) => {
  const shots = "tmp/highlight_fullpage";
  resetDir(shots);
  const capture = createCapture(page, shots);
  await page.setViewportSize({ width: 800, height: 600 });
  await page.goto("/?lang=en");

  // Something far enough down that the window and the document disagree about where it is.
  await page.evaluate(() => {
    const before = document.createElement("div");
    before.style.cssText = "height:1500px;background:linear-gradient(#fff,#ccd)";
    document.body.prepend(before);
    const target = document.createElement("p");
    target.id = "deep";
    target.textContent = "deep in the page";
    target.style.cssText = "height:60px;margin:0";
    document.body.insertBefore(target, document.body.children[1]);
    const after = document.createElement("div");
    after.style.cssText = "height:1500px;background:linear-gradient(#ccd,#fff)";
    document.body.appendChild(after);
  });

  const shot = await capture("deep", {
    scroll: "css:#deep",
    highlight: "#deep",
    fullPage: true,
  });

  const { docTop, docWidth } = await page.evaluate(() => {
    const r = document.querySelector("#deep")!.getBoundingClientRect();
    return {
      docTop: Math.round(r.top + window.scrollY),
      docWidth: document.documentElement.scrollWidth,
    };
  });

  // The box is drawn in document coordinates, so in a full-page image it must sit at the
  // element's place in the document — not at its place in the window, which is where a
  // position:fixed box ends up on some browser versions and not others.
  const { top, count } = await redBounds(page, shots, shot);
  expect(count, "the box is in the picture at all").toBeGreaterThan(1000);
  expect(
    Math.abs(top - (docTop - 5)),
    `box top ${top}, element at ${docTop} (less the 2px gap and 3px ring)`,
  ).toBeLessThanOrEqual(2);

  // And it did not widen the page on its way in: a ring past the right edge is new
  // scrollable area, which recomposes every later frame.
  const shotWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(shotWidth, "the overlay must not add scrollable width").toBe(docWidth);
});
