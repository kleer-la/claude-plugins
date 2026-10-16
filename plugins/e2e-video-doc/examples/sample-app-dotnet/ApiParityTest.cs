using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using E2EVideoDoc.Recipe;
using Microsoft.Playwright;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace E2EVideoDoc.Examples;

// The .NET counterpart of `../sample-app/tests/api.video.spec.ts`, pointed at the SAME
// `server.mjs` rather than a second fixture: the two recipes are proven against one source of
// truth for what a real call and response look like. It walks the same four cards and asserts
// what the Node flow only photographs, because a card that renders is not a card that is right.
//
//   dotnet test examples/sample-app-dotnet        # needs node on PATH
[TestClass]
public class ApiParityTest
{
	const string PartnerPassword = "wholesale-2024";   // must match server.mjs
	static readonly object PartnerOrder = new { customer = "Distribuidora Norte", items = new[] { new { sku = "GFT-100", qty = 5 } } };

	static Process? server;
	static string baseUrl = "";
	static IPlaywright? playwright;
	static IBrowser? browser;

	[ClassInitialize]
	public static async Task Start(TestContext _)
	{
		var port = FreePort();
		var appDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "sample-app"));
		server = Process.Start(new ProcessStartInfo("node", "server.mjs")
		{
			WorkingDirectory = appDir,
			RedirectStandardOutput = true,
			Environment = { ["PORT"] = port.ToString() },
		}) ?? throw new InvalidOperationException("could not start node server.mjs");
		baseUrl = $"http://127.0.0.1:{port}";

		// The server prints one line when it is listening; waiting for it beats sleeping.
		var ready = server.StandardOutput.ReadLineAsync();
		if (await Task.WhenAny(ready, Task.Delay(15000)) != ready)
			throw new TimeoutException("server.mjs did not report listening within 15s");

		// CHROMIUM_PATH: a Chromium already on the machine, for a platform this Playwright
		// version cannot download for (it refuses an OS newer than it knows). Otherwise
		// Chromium is a per-machine download, not a restore step; a no-op when present.
		var chromium = Environment.GetEnvironmentVariable("CHROMIUM_PATH");
		if (string.IsNullOrEmpty(chromium))
		{
			var code = Microsoft.Playwright.Program.Main(["install", "chromium"]);
			if (code != 0) throw new InvalidOperationException($"playwright install chromium exited {code}; set CHROMIUM_PATH to an existing chrome binary");
		}

		playwright = await Playwright.CreateAsync();
		browser = await playwright.Chromium.LaunchAsync(new() { ExecutablePath = string.IsNullOrEmpty(chromium) ? null : chromium });
	}

	[ClassCleanup]
	public static async Task Stop()
	{
		if (browser is not null) await browser.CloseAsync();
		playwright?.Dispose();
		if (server is { HasExited: false }) { server.Kill(true); server.WaitForExit(); }
	}

	static int FreePort()
	{
		var l = new TcpListener(IPAddress.Loopback, 0);
		l.Start();
		var p = ((IPEndPoint)l.LocalEndpoint).Port;
		l.Stop();
		return p;
	}

	static async Task<(IBrowserContext ctx, IPage page)> NewPage()
	{
		var ctx = await browser!.NewContextAsync(new() { BaseURL = baseUrl, ViewportSize = new() { Width = 1920, Height = 1080 } });
		return (ctx, await ctx.NewPageAsync());
	}

	static async Task<string> Computed(IPage page, string selector, string prop) =>
		await page.EvalOnSelectorAsync<string>(selector, $"e => getComputedStyle(e).{prop}");

	[TestMethod(DisplayName = "the api flow: token, rejected, bearer, access log, order on screen")]
	public async Task the_api_flow()
	{
		var (ctx, page) = await NewPage();
		await using var _ = ctx;
		var api = ctx.APIRequest;

		// 1. The credential. PostJson without a bearer sends no Authorization header at all.
		var token = await ApiPanel.PostJson(api, "/api/token", new { password = PartnerPassword });
		Assert.AreEqual(200, token.Status);
		var tokenValue = token.Get("token");
		Assert.IsGreaterThan(8, tokenValue.Length, "a real token, long enough for TrimValue to cut");
		await ApiPanel.ShowApiCall(page, new ApiCall
		{
			Description = "A wholesale partner trades its password for a token.",
			Method = "POST",
			Url = "/api/token",
			Request = new { password = "••••••" },
			Status = token.Status,
			Response = new { token = ApiPanel.TrimValue(tokenValue), role = token.Get("role") },
		});
		var card = await page.InnerTextAsync("body");
		StringAssert.Contains(card, "200 OK");
		StringAssert.Contains(card, ApiPanel.TrimValue(tokenValue));
		Assert.IsFalse(card.Contains(tokenValue), "the full token must not reach the card");
		Assert.IsFalse(card.Contains(PartnerPassword), "the password must not reach the card");

		// 2. The negative case: no credential, rejected, drawn red.
		var rejected = await ApiPanel.PostJson(api, "/api/partner/orders", PartnerOrder);
		Assert.AreEqual(401, rejected.Status);
		await ApiPanel.ShowApiCall(page, new ApiCall
		{
			Description = "The same order, with no credential at all: rejected.",
			Method = "POST",
			Url = "/api/partner/orders",
			Request = PartnerOrder,
			Status = rejected.Status,
			Response = rejected.Body,
			Reject = true,
			Note = "Drawn in red.",
		});
		StringAssert.Contains(await page.InnerTextAsync(".status"), "401 Unauthorized");
		Assert.AreEqual("rgb(164, 48, 42)", await Computed(page, ".status", "color"), "Reject draws the status red");
		Assert.AreEqual("rgb(192, 70, 61)", await Computed(page, ".note", "borderLeftColor"), "Reject draws the note border red");

		// 3. The same call with the token as bearer: created, drawn green, header shown trimmed.
		var granted = await ApiPanel.PostJson(api, "/api/partner/orders", PartnerOrder, tokenValue);
		Assert.AreEqual(201, granted.Status);
		var orderId = granted.Get("id");
		Assert.AreNotEqual("", orderId);
		await ApiPanel.ShowApiCall(page, new ApiCall
		{
			Description = "The token as a bearer credential: created.",
			Method = "POST",
			Url = "/api/partner/orders",
			Headers = new Dictionary<string, string> { ["Authorization"] = $"Bearer {ApiPanel.TrimValue(tokenValue)}" },
			Request = PartnerOrder,
			Status = granted.Status,
			Response = ApiPanel.PickFields(granted.Body!.Value, "id", "total", "channel"),
		});
		var grantedCard = await page.InnerTextAsync("body");
		StringAssert.Contains(grantedCard, $"Authorization: Bearer {ApiPanel.TrimValue(tokenValue)}");
		Assert.IsFalse(grantedCard.Contains(tokenValue), "Headers shows the trimmed credential, never the whole one");
		StringAssert.Contains(grantedCard, "201 Created");
		Assert.AreEqual("rgb(29, 107, 63)", await Computed(page, ".status", "color"), "no Reject: green");
		// PickFields keeps what it was told to and says how much it left out.
		StringAssert.Contains(grantedCard, "more fields");

		// 4. ShowCard: not an HTTP call. The last entry of the server's own access log.
		var log = await api.GetAsync("/api/access-log");
		using var logDoc = JsonDocument.Parse(await log.TextAsync());
		var entries = logDoc.RootElement.GetProperty("entries");
		var last = entries[entries.GetArrayLength() - 1];
		await ApiPanel.ShowCard(page, "What the guard kept on the way in.", "access log · last entry",
			JsonSerializer.Serialize(last, new JsonSerializerOptions { WriteIndented = true }), "From the server.");
		var logCard = await page.InnerTextAsync("body");
		StringAssert.Contains(logCard, "SQL", "ShowCard draws through ShowApiCall with the SQL verb, as the Node recipe does");
		StringAssert.Contains(logCard, "partner");
		Assert.IsFalse(logCard.Contains(tokenValue) || logCard.Contains(PartnerPassword), "the access log holds neither secret");

		// 5. Proof on a screen: the order the API created, found by id in the storefront.
		await page.GotoAsync("/?lang=en");
		await page.FillAsync("#track-id", orderId);
		await page.ClickAsync("#track-btn");
		await Assertions.Expect(page.Locator("#track-result-id")).ToHaveTextAsync(orderId);
	}

	[TestMethod(DisplayName = "a card that needs more than the frame refuses to render")]
	public async Task an_overflowing_card_throws()
	{
		var (ctx, page) = await NewPage();
		await using var _ = ctx;
		var huge = string.Join("\n", Enumerable.Range(0, 400).Select(i => $"line {i}"));
		var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
			ApiPanel.ShowCard(page, "too long", "label", huge));
		StringAssert.Contains(ex.Message, "past the point of being readable");
	}
}
