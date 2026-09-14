# Playwright recipe (.NET / C#)

Copy `Capture.cs`, `ApiPanel.cs` and `IsExternalInit.cs` into the test project. They need
`Microsoft.Playwright` and nothing else: the helper takes an `IPage`, so it works the same
under plain MSTest, under `Microsoft.Playwright.MSTest`'s `PageTest`, or under NUnit.
`HighlightRegressionTest.cs` is the test to copy next to yours; it needs MSTest.

The port is function for function, and the comments inside are the Node recipe's own, so
`capture.ts` and `Capture.cs` diff side by side. When one changes, port the change to the
other.

## The project

```xml
<PropertyGroup>
  <TargetFrameworks>net48;net10.0</TargetFrameworks>   <!-- or just one -->
  <LangVersion>latest</LangVersion>
  <Nullable>enable</Nullable>
</PropertyGroup>
<ItemGroup>
  <PackageReference Include="Microsoft.Playwright" Version="1.55.0" />
</ItemGroup>
```

Three things there are not optional:

- **`LangVersion`.** The helper uses raw string literals (`"""`) for its JavaScript, which is
  C# 11. The SDK defaults `net48` to C# 7.3 and the error it gives names the feature, not
  the setting.
- **`IsExternalInit.cs`** is what lets `init` and positional records compile on .NET
  Framework 4.8. It compiles out on .NET 5+. If the project already carries one, delete the
  copy: two definitions of that type are an error.
- **Chromium is installed once per machine**, not by `restore`:

  ```powershell
  bin\Debug\net48\playwright.ps1 install chromium
  ```

  The package pins the browser version, so a machine that already has it downloads nothing.

## `Capture.cs`

```csharp
using E2EVideoDoc.Recipe;

[TestClass]
public class CheckoutVideo
{
	const string Dir = "tmp/e2e/checkout";

	[TestMethod, TestCategory("video")]
	public async Task placing_an_order()
	{
		// First thing, before ResetDir: a skip after it still wipes the last real run.
		if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("RUN_VIDEO_TESTS")))
			Assert.Inconclusive("only with RUN_VIDEO_TESTS=1");   // shows as Skipped

		Capture.ResetDir(Dir);
		var capture = new Capture(page, Dir);

		await page.GotoAsync("/");
		await capture.Take("start");
		await capture.Take("total", highlight: "#total", scroll: "css:#total");
		await capture.Take("detail", focus: ".detail-panel", focusPad: 40);
	}
}
```

`Take` returns the file name it wrote, `NN_name.png`. Its options are named parameters:

| Parameter | What it does |
|---|---|
| `highlight` | Red box over one or more selectors during the shot: a `string`, or a `string[]`. Removed afterwards, so it does not leak into the next step. Throws if it does not match. |
| `focus` / `focusPad` | Crops the image around a selector, with air. |
| `scroll` | `"top"` \| `"bottom"` \| `"css:<selector>"` \| `"text:<substring>"`. |
| `scrollBy` | A pixel offset — the numeric form of `scroll`, its own parameter because C# has no `string \| number`. |
| `fullPage` | Whole page. Does not coexist with `focus` — cropping means looking at the viewport. Works with `highlight`: the box is drawn in document coordinates, so it frames the element wherever it sits in the tall image. |
| `pauseMs` | Wait before the shot (default 400). |
| `assertInFrame` | Refuses to take the picture unless that element is whole in the viewport and nothing covers it. Scrolls once more, centred, and re-checks before giving up. Any Playwright selector, `text=…` included. |

`Capture.DismissBanner(page, selector)` closes whatever your stack puts on top of the page
— a component library's trial strip, a staging ribbon, a debug bar. Call it once after
navigating, before the first capture, not in every test.

## `ApiPanel.cs`

For flows where part of what you are telling happens through the API rather than on the
screen. It draws the call as a card and photographs it with the same `capture`.

```csharp
using static E2EVideoDoc.Recipe.ApiPanel;

await ShowApiCall(page, new ApiCall
{
	Description = "The client requests a token. The password travels in the body, not the URL.",
	Method = "POST",
	Url = "/api/v2/tokens",
	Request = PickFields(body, "username"),
	Status = 200,
	Response = new { token = TrimValue(token) },
	Note = "The token is scoped to this client only.",
});
await capture.Take("token_issued");
```

| Member | What it is |
|---|---|
| `ShowApiCall(page, call)` | Draws the card. Follow it with `capture.Take(...)`. |
| `ShowCard(page, description, label, text, note?)` | Free-text card, for what is not an API call — a query result, a log line. |
| `PickFields(body, keys...)` | Keeps the keys the description points at, says how many were left out. Takes a `JsonElement` or a dictionary. |
| `TrimValue(value)` | Shows the start of a long value, not the value. **Always use it for credentials.** |
| `PostJson(api, url, data, bearer?)` | JSON POST with an optional bearer credential. Returns a `JsonResponse`: `Status`, `Body` (a `JsonElement?`, null when the body is not JSON), `Text`, and `Get("prop")` / `Prop("prop")` to read one property without a null check. |

`Reject = true` paints the card red, for showing the negative case.

**Labels are configurable.** The card says `request` / `response` by default; if the
narration is in another language, pass `Labels = new CardLabels("pedido", "respuesta")` so
the card matches the voice.

## Difference from the Node recipe

- Options are named parameters, not an options object, and `scroll`'s numeric form is a
  separate parameter, `scrollBy`.
- `expect: "reject"` is `Reject = true`.
- `postJson` returns a typed `JsonResponse` instead of `{ status, body }`, because reading a
  property off an untyped body is a cast on every line in C#.

Everything else behaves the same, on purpose.

## One .NET-only gotcha, measured

`Microsoft.Playwright` serializes a `float` argument to the page as an **empty object**, and
`BoundingBoxAsync` returns floats. Passed as-is, the overlay's arithmetic goes NaN and the
box comes out as a 0x0 dot with the test green: 30 red pixels where 5,000 were due. Every
coordinate that crosses into `EvaluateAsync` is cast to `double` first, and
`HighlightRegressionTest.cs` scores the box, so a regression here fails loudly.

## Running it

`run.sh` and `make_videos.cmd` export `RUN_VIDEO_TESTS=1` for the capture command, so video
tests sit behind that flag and a normal `dotnet test` skips them (`Assert.Inconclusive`
reports as *Skipped*). Put the check before `ResetDir`, as above: a skip further down still
wipes the last real run's captures.

In `e2e-video-doc.json`, one category per flow keeps the capture command generic:

```json
"capture": "dotnet test -f net48 --filter TestCategory={flow}"
```

A filter that matches no test is **green**: `dotnet test` exits 0 having run nothing, and
the first thing to say so is the engine reporting every screenshot missing. Check the PNG
directory has new files before assembling if the capture runs unattended.

A browser test that fails can leave its Playwright trace: open the page's context with
`Tracing.StartAsync` and stop it into a `.zip` only when the test failed;
`playwright.ps1 show-trace <file>.zip` replays the screen, the network and every action.

## After every update of the helper

Copy `HighlightRegressionTest.cs` next to your tests and run it:

```
dotnet test --filter FullyQualifiedName~HighlightRegressionTest
```

It proves the one property that was silently false in a fork of this recipe for two
releases — the red box outlives a re-render of the node it frames, because it is drawn on
`document.body` rather than as a mark on the element. Turbo streams, React renders and
DevExpress grid callbacks all replace that node with markup that never carried a mark, and
when they do, nothing else fails: the selector matched, the test is green, only the
photograph is empty. It needs no app: it photographs a page it sets itself.

`HighlightOn`/`HighlightOff` are the parts that must be re-ported on every update, and
that test is how you find out whether you did.
