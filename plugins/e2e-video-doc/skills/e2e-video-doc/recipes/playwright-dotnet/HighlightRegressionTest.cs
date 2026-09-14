using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Playwright;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace E2EVideoDoc.Recipe;

// The .NET counterpart of `examples/sample-app/tests/highlight.spec.ts`, pointed at a page
// of its own so it needs no app: copy it next to your tests and run it after every update of
// Capture.cs. It proves the one property that was silently false in a fork for two releases —
// the red box outlives a re-render of the node it frames, because it is drawn on
// document.body rather than as a mark on the element. Turbo streams, React renders and
// DevExpress grid callbacks all replace that node with markup that never carried a mark, and
// when they do nothing else fails: the selector matched, the test is green, only the
// photograph is empty.
//
// It also catches the .NET-only failure Capture.cs guards against: a `float` coordinate
// handed to the page arrives as an empty object, the overlay's maths go NaN, and the box is a
// 0x0 dot. Both failures score under 50 red pixels here; a drawn box scores thousands.
//
// `cloneNode(true)` does not reproduce the failure: it copies the attribute and the box
// "survives" by accident. The original HTML, read before the box is drawn, is what gets put
// back.
[TestClass]
public class HighlightRegressionTest
{
	const string Container = "#box";
	const string Sel = "#target";

	/// <summary>
	/// Pixels close to the highlight's #d9534f, counted by drawing the PNG into a canvas in
	/// the browser: no image library, and no dependency on ffmpeg being installed.
	/// </summary>
	static Task<int> RedPixels(IPage page, string file)
	{
		var b64 = Convert.ToBase64String(File.ReadAllBytes(file));
		return page.EvaluateAsync<int>("""
			async (src) => {
			  const img = new Image();
			  img.src = `data:image/png;base64,${src}`;
			  await img.decode();
			  const canvas = document.createElement("canvas");
			  canvas.width = img.width;
			  canvas.height = img.height;
			  const ctx = canvas.getContext("2d");
			  ctx.drawImage(img, 0, 0);
			  const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
			  let n = 0;
			  for (let i = 0; i < data.length; i += 4) {
			    if (data[i] > 170 && data[i + 1] < 120 && data[i + 2] < 120) n++;
			  }
			  return n;
			}
			""", b64);
	}

	[TestMethod(DisplayName = "the box survives the framework re-rendering the node it frames")]
	public async Task the_box_survives_the_framework_re_rendering_the_node_it_frames()
	{
		using var playwright = await Playwright.CreateAsync();
		var browser = await playwright.Chromium.LaunchAsync();
		try
		{
			var page = await browser.NewPageAsync(new() { ViewportSize = new() { Width = 1280, Height = 800 } });
			await page.SetContentAsync("""
				<div id="box" style="padding:80px;background:#fff;color:#111">
				  <div id="target" style="display:inline-block;padding:12px 24px;font-size:18px;border:1px solid #111">Here</div>
				</div>
				""");

			var dir = Path.Combine(Path.GetTempPath(), "e2e-highlight-" + Guid.NewGuid().ToString("N"));
			Capture.ResetDir(dir);
			var capture = new Capture(page, dir);

			var control = await capture.Take("control");
			var baseline = await capture.Take("baseline", highlight: Sel);

			// Stage the re-render inside capture's own pause: the box is drawn, then the
			// framework replaces the node, then the shutter fires.
			var original = await page.Locator(Container).InnerHTMLAsync();
			await page.EvaluateAsync("""
				({ sel, html }) => {
				  setTimeout(() => {
				    document.querySelector(sel).innerHTML = html;
				  }, 120);
				}
				""", new { sel = Container, html = original });
			var remounted = await capture.Take("remounted", highlight: Sel, pauseMs: 500);

			var clean = await RedPixels(page, Path.Combine(dir, control));
			var drawn = await RedPixels(page, Path.Combine(dir, baseline));
			var survived = await RedPixels(page, Path.Combine(dir, remounted));

			// A blank setContent page still yields a handful of reddish pixels in Chromium's
			// PNG. The box is three orders above that.
			Assert.IsTrue(clean < 50, $"the page itself is not the box ({clean})");
			Assert.IsTrue(drawn > 500, $"the box is in the undisturbed shot ({drawn})");
			Assert.IsTrue(survived > 500, $"the box is still there after the re-render ({survived})");
			Assert.IsTrue(Math.Abs(survived - drawn) < drawn * 0.02, $"drawn {drawn}, survived {survived}");
		}
		finally
		{
			await browser.CloseAsync();
		}
	}
}
