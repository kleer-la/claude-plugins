# Playwright recipe (Node / TypeScript)

Copy `capture.ts` and `apiPanel.ts` into the project's helpers. They have no dependencies
beyond `@playwright/test`.

**`@playwright/test` is not `playwright`.** They are different npm packages, and a project
can have the library without the test runner. Check before writing the first capture:

```bash
node -e "require.resolve('@playwright/test')" || npm install --save-dev @playwright/test
```

Skipping it fails late and points at the wrong thing: `npx playwright test` exists and
starts, because the `playwright` binary is there, and the error names your
`playwright.config.ts` rather than the missing package.

## `capture.ts`

```ts
import { createCapture, resetDir } from "../helpers/capture";

const DIR = "tmp/e2e/checkout";

test.beforeAll(() => resetDir(DIR));

test("placing an order", { tag: "@video" }, async ({ page }) => {
  test.skip(!process.env.RUN_VIDEO_TESTS, "only with RUN_VIDEO_TESTS=1");
  const capture = createCapture(page, DIR);

  await page.goto("/");
  await capture("start");
  await capture("total", { highlight: "#total", scroll: "css:#total" });
  await capture("detail", { focus: ".detail-panel", focusPad: 40 });
});
```

| Option | What it does |
|---|---|
| `highlight` | Red box over one or more selectors during the shot. Removed afterwards, so it does not leak into the next step. Throws if it does not match. |
| `focus` / `focusPad` | Crops the image around a selector, with air. |
| `scroll` | `"top"` \| `"bottom"` \| pixel offset \| `"css:<selector>"` \| `"text:<substring>"`. |
| `fullPage` | Whole page. Does not coexist with `focus` — cropping means looking at the viewport. Works with `highlight`: the box is drawn in document coordinates, so it frames the element wherever it sits in the tall image. |
| `pauseMs` | Wait before the shot (default 400). |
| `assertInFrame` | Refuses to take the picture unless that element is whole in the viewport and nothing covers it. Scrolls once more, centred, and re-checks before giving up. Any Playwright selector, `text=…` included. |

`dismissBanner(page, selector)` closes whatever your stack puts on top of the page — a
component library's trial strip, a staging ribbon, a debug bar. Call it once in a
`beforeEach`, not in every test.

## `apiPanel.ts`

For flows where part of what you are telling happens through the API rather than on the
screen. It draws the call as a card and photographs it with the same `capture`.

```ts
await showApiCall(page, {
  description: "The client requests a token. The password travels in the body, not the URL.",
  method: "POST",
  url: "/api/v2/tokens",
  request: pickFields(body, ["username"]),
  status: 200,
  response: { token: trimValue(token) },
  note: "The token is scoped to this client only.",
});
await capture("token_issued");
```

| Export | What it is |
|---|---|
| `showApiCall(page, call)` | Draws the card. Follow it with `capture(...)`. |
| `showCard(page, {...})` | Free-text card, for what is not an API call — a query result, a log line. |
| `pickFields(body, keys)` | Keeps the keys the description points at, says how many were left out. |
| `trimValue(value)` | Shows the start of a long value, not the value. **Always use it for credentials.** |
| `postJson(api, url, data, bearer?)` | JSON POST with an optional bearer credential. |

`expect: "reject"` paints the card red, for showing the negative case.

**Labels are configurable.** The card says `request` / `response` by default; if the
narration is in another language, pass `labels: { request: "pedido", response: "respuesta" }`
so the card matches the voice.

## After every update of the helper

The plugin repository ships `examples/sample-app/tests/highlight.spec.ts`, which stages a
re-render of the framed node inside `capture`'s own pause and counts the red pixels in the
resulting PNGs. It exists because a fork of this recipe carried a silent failure for two
releases: the box used to be a mark on the element, and any framework that re-renders that
node took the box with it — green test, empty photograph.

If you copied this recipe, copy that spec too and point it at a page of your own. If you
*forked* the recipe, `highlightOn`/`highlightOff` are the parts that must be re-ported on
every update, and that spec is how you find out whether you did.
