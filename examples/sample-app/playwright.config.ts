import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  // 1280x720 is 16:9, which is what the engine pads to. A 4:3 viewport lands the whole
  // app inside white pillars — see the plugin's gotchas, "the screen size is the window".
  use: { baseURL: "http://127.0.0.1:3210", viewport: { width: 1280, height: 720 } },
  webServer: {
    command: "node server.mjs",
    url: "http://127.0.0.1:3210/api/products",
    reuseExistingServer: !process.env.CI,
  },
  reporter: [["list"]],
});
