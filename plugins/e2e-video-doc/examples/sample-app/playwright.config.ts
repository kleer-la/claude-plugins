import { defineConfig } from "@playwright/test";

// One project per language. `run.sh` selects with --project={lang}, which works the same
// on Windows as it does here — a `VIDEO_LOCALE=es npx ...` prefix would not, because the
// capture command goes through cmd /c on Windows. See the plugin's gotchas.
export default defineConfig({
  testDir: "./tests",
  // 1280x720 is 16:9, which is what the engine pads to. A 4:3 viewport lands the whole
  // app inside white pillars — see the plugin's gotchas, "the screen size is the window".
  use: { baseURL: "http://127.0.0.1:3210", viewport: { width: 1280, height: 720 } },
  projects: [
    { name: "en" },
    { name: "es" },
  ],
  webServer: {
    command: "node server.mjs",
    url: "http://127.0.0.1:3210/api/products",
    reuseExistingServer: !process.env.CI,
  },
  reporter: [["list"]],
});
