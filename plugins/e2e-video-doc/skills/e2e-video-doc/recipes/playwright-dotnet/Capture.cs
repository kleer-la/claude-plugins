using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Playwright;

namespace E2EVideoDoc.Recipe;

// The e2e-video-doc capture helper for Playwright .NET: the C# port of
// `recipes/playwright-node/capture.ts`, function for function. The comments below are that
// recipe's own, kept so the two files diff side by side; when one changes, port the change
// to the other. HighlightOn/HighlightOff are the parts that can never drift (see the
// plugin's gotchas, "a highlight that matched could once still be gone by the time of the
// shot"), and HighlightRegressionTest.cs is how you find out whether they did.
//
// One .NET-only gotcha, measured: Playwright .NET serializes a `float` argument to JS as an
// empty object, and BoundingBoxAsync returns floats. Passed as-is, the overlay's maths went
// NaN and the box came out as a 0x0 dot with a green test (30 red pixels where 5,000 were
// due). Every coordinate that crosses into EvaluateAsync is cast to double first.

/// <summary>Selectors to frame in red during the shot: one, or several.</summary>
public readonly record struct Selectors(string[] Items)
{
	public static implicit operator Selectors(string one) => new(new[] { one });
	public static implicit operator Selectors(string[] many) => new(many);
}

public sealed class Capture
{
	readonly IPage _page;
	readonly string _dir;
	int _step;

	public Capture(IPage page, string dir)
	{
		_page = page;
		_dir = dir;
	}

	public static void ResetDir(string dir)
	{
		if (Directory.Exists(dir))
			Directory.Delete(dir, recursive: true);
		Directory.CreateDirectory(dir);
	}

	/// <summary>
	/// Closes a trial or environment banner so the video shows the product, not the
	/// scaffolding. Point it at whatever your stack puts on top of the page — a component
	/// library's trial strip, a staging ribbon, a debug bar.
	/// </summary>
	public static async Task DismissBanner(IPage page, string selector)
	{
		var close = page.Locator(selector).First;
		try
		{
			await close.ClickAsync(new() { Timeout = 2500 });
			await page.WaitForTimeoutAsync(200);
		}
		catch (Exception)
		{
			// banner absent
		}
	}

	// Box drawn over whatever the narration is pointing at. Removed after the shot, so it
	// does not leak into the next step. At full size a single cell cannot be found on its
	// own: either you frame it, or you crop the image around it.
	//
	// It is its own element on document.body, not a mark on the element it frames. A mark
	// on the element leaves with the element the moment the framework re-renders that node,
	// and the loss is silent: the selector matched, the test passes, the photograph simply
	// has no box on it. Measured on a real app — the mark scored 3411 red pixels before a
	// re-render replaced the node and 0 after, green test both times. Nothing appended to
	// document.body is reachable by a re-render of the app's own tree.
	const string OverlayAttr = "data-e2e-overlay";
	// Reproduces what `outline: 3px` at `outline-offset: 2px` used to draw: 2px of air, a
	// 3px ring, then the glow outside it.
	const int OverlayGap = 2;
	const int OverlayBorder = 3;

	const string HighlightOnJs = """
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
		}
		""";

	async Task HighlightOn(IReadOnlyList<string> selectors)
	{
		foreach (var sel in selectors)
		{
			// Through the locator and not document.querySelector: Playwright selectors
			// (:has-text, :text) are not CSS and the DOM does not understand them. Going
			// through the locator accepts both.
			var loc = _page.Locator(sel).First;
			// Loud failure on purpose: a highlight that does not match is narration pointing at
			// something no longer on the screen — exactly the change the video exists to catch.
			if (await loc.CountAsync() == 0)
				throw new InvalidOperationException($"highlight did not match: {sel}");
			var box = await loc.BoundingBoxAsync();
			// Matched but unphotographable — display:none, zero-sized — is the same kind of
			// silence, so it fails the same way.
			if (box is null)
				throw new InvalidOperationException($"highlight has no box: {sel}");
			await _page.EvaluateAsync(HighlightOnJs, new
			{
				attr = OverlayAttr,
				box = new { x = (double)box.X, y = (double)box.Y, width = (double)box.Width, height = (double)box.Height },
				gap = OverlayGap,
				border = OverlayBorder,
			});
		}
	}

	Task HighlightOff() =>
		_page.EvaluateAsync("attr => { document.querySelectorAll(`[${attr}]`).forEach((el) => el.remove()); }", OverlayAttr);

	const string FrameProblemJs = """
		(el) => {
		  const r = el.getBoundingClientRect();
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
		}
		""";

	// Nil when the element is whole in the viewport and visible; otherwise a phrase saying
	// what is wrong with it. Three ways a capture goes silently wrong: the subject is off the
	// top or bottom of the frame, it has no box at all, or something is sitting on top of it
	// — a sticky header, a modal, a cookie bar. The last is why this asks the document what
	// is actually painted at the middle of the element rather than trusting the rectangle.
	// The overlay drawn above has `pointer-events: none`, so elementFromPoint sees past it.
	async Task<string?> FrameProblem(string selector)
	{
		var loc = _page.Locator(selector).First;
		if (await loc.CountAsync() == 0)
			return "did not match anything";
		var result = await loc.EvaluateAsync<JsonElement?>(FrameProblemJs);
		return result is { ValueKind: JsonValueKind.String } s ? s.GetString() : null;
	}

	/// <summary>
	/// Takes the numbered shot `NN_name.png` and returns the file name.
	/// </summary>
	/// <param name="pauseMs">Wait before the shot (default 400).</param>
	/// <param name="scroll">"top" | "bottom" | "css:&lt;selector&gt;" | "text:&lt;substring&gt;".</param>
	/// <param name="scrollBy">Pixel offset, the numeric form of `scroll`.</param>
	/// <param name="fullPage">Whole page. Does not coexist with `focus`.</param>
	/// <param name="highlight">Selectors to frame in red during the shot.</param>
	/// <param name="focus">Crops the image around this selector, with `focusPad` px of air.</param>
	/// <param name="assertInFrame">Refuse to take the picture unless this element is whole in the
	/// frame and nothing is covering it.</param>
	public async Task<string> Take(
		string name,
		int pauseMs = 400,
		string? scroll = null,
		int? scrollBy = null,
		bool fullPage = false,
		Selectors? highlight = null,
		string? focus = null,
		int focusPad = 40,
		string? assertInFrame = null)
	{
		// `behavior: "instant"` on every branch: `window.scrollTo(0, y)` is the two-argument
		// form, which means `behavior: "auto"`, which resolves to the computed
		// `scroll-behavior` — smooth on any Bootstrap app, and then the shot is a race
		// against the pause. Measured on the sample: 0 immediately, 190 seven-tenths later.
		if (scroll == "bottom")
			await _page.EvaluateAsync("() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' })");
		else if (scroll == "top")
			await _page.EvaluateAsync("() => window.scrollTo({ top: 0, behavior: 'instant' })");
		else if (scrollBy is int n)
			await _page.EvaluateAsync("(n) => window.scrollBy({ top: n, behavior: 'instant' })", n);
		else if (scroll is not null && scroll.StartsWith("css:", StringComparison.Ordinal))
			await _page.Locator(scroll.Substring(4)).First.ScrollIntoViewIfNeededAsync();
		else if (scroll is not null && scroll.StartsWith("text:", StringComparison.Ordinal))
			// By visible text, for screens where nothing useful has a stable selector.
			await _page.GetByText(scroll.Substring(5)).First.ScrollIntoViewIfNeededAsync();
		else if (scroll is not null)
			throw new ArgumentException($"unrecognised scroll: {scroll}", nameof(scroll));

		// Checked before the box is drawn, because scrolling afterwards would leave the box
		// behind at the old position — it is placed once and does not follow.
		if (assertInFrame is not null)
		{
			var problem = await FrameProblem(assertInFrame);
			if (problem is not null)
			{
				// One retry, centred rather than minimal. Two things it fixes: a framework that
				// restores scroll position asynchronously after a navigation, undoing a scroll
				// applied a moment too early; and an element parked under a sticky header, which
				// scrollIntoViewIfNeeded considers already in view and will not move.
				await _page.Locator(assertInFrame).First
					.EvaluateAsync("(el) => el.scrollIntoView({ block: 'center', behavior: 'instant' })");
				await _page.WaitForTimeoutAsync(300);
				problem = await FrameProblem(assertInFrame);
				if (problem is not null)
					throw new InvalidOperationException(
						$"capture({name}): {assertInFrame} {problem}, and scrolling again did not fix it");
			}
		}

		var selectors = highlight?.Items ?? Array.Empty<string>();
		if (selectors.Length > 0)
			await HighlightOn(selectors);

		await _page.WaitForTimeoutAsync(pauseMs);
		// Again, after the pause and immediately before the shutter, because this is what the
		// camera will see: a scroll can still be undone while the page settles, and that
		// produces a perfectly valid photograph of the wrong part of the page.
		if (assertInFrame is not null)
		{
			var problem = await FrameProblem(assertInFrame);
			if (problem is not null)
				throw new InvalidOperationException(
					$"capture({name}): {assertInFrame} {problem} at the moment of the shot");
		}
		_step += 1;
		var filename = $"{_step:00}_{name}.png";

		Clip? clip = null;
		if (focus is not null)
		{
			var box = await _page.Locator(focus).First.BoundingBoxAsync();
			if (box is null)
				throw new InvalidOperationException($"focus has no box: {focus}");
			var vpWidth = _page.ViewportSize?.Width ?? 1280;
			var vpHeight = _page.ViewportSize?.Height ?? 800;
			var x = Math.Max(0, box.X - focusPad);
			var y = Math.Max(0, box.Y - focusPad);
			clip = new Clip
			{
				X = x,
				Y = y,
				Width = Math.Min(box.Width + focusPad * 2, vpWidth - x),
				Height = Math.Min(box.Height + focusPad * 2, vpHeight - y),
			};
		}

		await _page.ScreenshotAsync(new()
		{
			Path = Path.Combine(_dir, filename),
			// clip and fullPage do not coexist: cropping means looking at the viewport.
			FullPage = clip is null ? fullPage : null,
			Clip = clip,
		});
		if (selectors.Length > 0)
			await HighlightOff();
		return filename;
	}
}
