import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { Page } from "@playwright/test";

/** Pixels close to the highlight's #d9534f in a captured PNG, counted by drawing the file
 *  into a canvas in the browser — no image library, and no dependency on ffmpeg. */
export async function redPixels(page: Page, dir: string, file: string): Promise<number> {
  const b64 = readFileSync(join(process.cwd(), dir, file)).toString("base64");
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

/** Fraction of pixels that differ between two captured PNGs (0 = identical frames).
 *  Used to ask whether a shot was taken of the page it was supposed to be taken of. */
export async function frameDiff(
  page: Page,
  dir: string,
  a: string,
  b: string,
): Promise<number> {
  const load = (f: string) => readFileSync(join(process.cwd(), dir, f)).toString("base64");
  return page.evaluate(
    async ([one, two]) => {
      const decode = async (src: string) => {
        const img = new Image();
        img.src = `data:image/png;base64,${src}`;
        await img.decode();
        const canvas = document.createElement("canvas");
        canvas.width = img.width;
        canvas.height = img.height;
        canvas.getContext("2d")!.drawImage(img, 0, 0);
        return canvas.getContext("2d")!.getImageData(0, 0, canvas.width, canvas.height).data;
      };
      const [x, y] = [await decode(one), await decode(two)];
      if (x.length !== y.length) return 1;
      let differing = 0;
      for (let i = 0; i < x.length; i += 4) {
        if (Math.abs(x[i] - y[i]) > 12 || Math.abs(x[i + 1] - y[i + 1]) > 12) differing++;
      }
      return differing / (x.length / 4);
    },
    [load(a), load(b)],
  );
}

/** Vertical extent of the highlight box in a captured PNG, in image pixels. Answers the
 *  only question that matters for a full-page shot: is the ring where the element is? */
export async function redBounds(
  page: Page,
  dir: string,
  file: string,
): Promise<{ top: number; bottom: number; count: number }> {
  const b64 = readFileSync(join(process.cwd(), dir, file)).toString("base64");
  return page.evaluate(async (src) => {
    const img = new Image();
    img.src = `data:image/png;base64,${src}`;
    await img.decode();
    const canvas = document.createElement("canvas");
    canvas.width = img.width;
    canvas.height = img.height;
    canvas.getContext("2d")!.drawImage(img, 0, 0);
    const { data } = canvas.getContext("2d")!.getImageData(0, 0, canvas.width, canvas.height);
    let top = Infinity;
    let bottom = -Infinity;
    let count = 0;
    for (let i = 0; i < data.length; i += 4) {
      if (data[i] > 170 && data[i + 1] < 120 && data[i + 2] < 120) {
        const y = Math.floor(i / 4 / canvas.width);
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        count++;
      }
    }
    return { top: count ? top : -1, bottom: count ? bottom : -1, count };
  }, b64);
}
