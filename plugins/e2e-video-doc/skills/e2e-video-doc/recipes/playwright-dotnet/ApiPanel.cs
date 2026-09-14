using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Playwright;

namespace E2EVideoDoc.Recipe;

// The C# port of `recipes/playwright-node/apiPanel.ts`. Same rule as Capture.cs: the two
// files diff side by side, and a change in one is ported to the other.
//
// Makes an API call VISIBLE inside a video that otherwise shows screens.
//
// The problem: an HTTP call has nothing to photograph. If the video only shows the
// result on screen, the viewer has to take on faith that the API did anything. Here the
// call is drawn as a card — what was sent, what came back, and what to look at — and is
// photographed with the same `capture` as the rest of the walkthrough, so it lands in the
// same MP4 without touching the narration pipeline.
//
// The trimming is deliberate: a full request body of forty fields is forty fields nobody
// can read on screen. Show the lines the description is pointing at.

/// <summary>Card labels. Override to match the narration language.</summary>
public sealed record CardLabels(string Request = "request", string Response = "response");

public sealed class ApiCall
{
	/// <summary>What is happening, in one line. This is what the viewer reads first.</summary>
	public string Description { get; init; } = "";
	public string Method { get; init; } = "";
	public string Url { get; init; } = "";
	/// <summary>Headers to show. Trim the credential yourself with `TrimValue`.</summary>
	public IReadOnlyDictionary<string, string>? Headers { get; init; }
	/// <summary>Request body, already trimmed to what matters.</summary>
	public object? Request { get; init; }
	public int? Status { get; init; }
	/// <summary>Response body, already trimmed.</summary>
	public object? Response { get; init; }
	/// <summary>What to look at in this call. Highlighted underneath.</summary>
	public string? Note { get; init; }
	/// <summary>Marks the card as the negative case (red instead of green).</summary>
	public bool Reject { get; init; }
	public CardLabels? Labels { get; init; }
}

public static class ApiPanel
{
	static readonly JsonSerializerOptions Pretty = new()
	{
		WriteIndented = true,
		Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
	};

	/// <summary>Shows the start of a long value, not the value. Use it for credentials.</summary>
	public static string TrimValue(string value, int visible = 8) =>
		value.Length <= visible ? value : value.Substring(0, visible) + "…";

	/// <summary>Keeps these keys, in this order. Everything else stays off screen.</summary>
	public static Dictionary<string, object?> PickFields(JsonElement body, params string[] keys)
	{
		var all = body.EnumerateObject().ToDictionary(p => p.Name, p => (object?)p.Value);
		return PickFields(all, keys);
	}

	public static Dictionary<string, object?> PickFields(IReadOnlyDictionary<string, object?> body, params string[] keys)
	{
		var result = new Dictionary<string, object?>();
		foreach (var k in keys)
		{
			if (body.TryGetValue(k, out var v))
				result[k] = v;
		}
		var rest = body.Count - result.Count;
		if (rest > 0)
			result["…"] = $"{rest} more fields";
		return result;
	}

	static string Esc(string s) => WebUtility.HtmlEncode(s);

	static string Block(string label, string? body) =>
		string.IsNullOrEmpty(body)
			? ""
			: $"<div class=\"block\"><div class=\"label\">{Esc(label)}</div><pre>{Esc(body!)}</pre></div>";

	static string? Json(object? v) => v switch
	{
		null => null,
		string s => s,
		_ => JsonSerializer.Serialize(v, Pretty),
	};

	static string StatusText(int status) => status switch
	{
		200 => "OK",
		201 => "Created",
		400 => "Bad Request",
		401 => "Unauthorized",
		403 => "Forbidden",
		404 => "Not Found",
		409 => "Conflict",
		429 => "Too Many Requests",
		_ => "",
	};

	static string Html(ApiCall c)
	{
		var reject = c.Reject;
		var labels = c.Labels ?? new CardLabels();
		var headers = c.Headers is null
			? null
			: string.Join("\n", c.Headers.Select(h => $"{h.Key}: {h.Value}"));
		var requestParts = new[] { headers, Json(c.Request) }.Where(p => !string.IsNullOrEmpty(p));
		var request = string.Join("\n\n", requestParts);
		var statusColor = reject ? "#a4302a" : "#1d6b3f";
		var statusBg = reject ? "#fdf2f1" : "#f1f8f3";
		var noteBorder = reject ? "#c0463d" : "#3d7dca";

		return $$"""
			<!doctype html><meta charset="utf-8"><style>
			  :root { color-scheme: light }
			  * { box-sizing: border-box }
			  body { margin:0; padding:44px 56px; background:#f4f6f8; font:16px/1.5 "Segoe UI",system-ui,sans-serif; color:#1b1f24 }
			  .card { background:#fff; border:1px solid #d6dbe1; border-radius:10px; overflow:hidden;
			          box-shadow:0 2px 14px rgba(20,30,45,.10) }
			  .desc { padding:22px 28px; font-size:26px; font-weight:600; line-height:1.35;
			          border-bottom:1px solid #e7ebef }
			  .call { padding:18px 28px; font-family:Consolas,"Courier New",monospace; font-size:21px;
			          background:#1b2733; color:#e8eef5; word-break:break-all }
			  .verb { display:inline-block; padding:2px 12px; border-radius:5px; margin-right:12px;
			          font-weight:700; background:#3d7dca; color:#fff }
			  .bodies { display:grid; grid-template-columns:1fr 1fr; gap:0 }
			  .block { padding:18px 28px; border-top:1px solid #e7ebef }
			  .block + .block { border-left:1px solid #e7ebef }
			  .label { font-size:14px; letter-spacing:.10em; text-transform:uppercase; color:#66707b; margin-bottom:8px }
			  pre { margin:0; font-family:Consolas,"Courier New",monospace; font-size:19px; line-height:1.45;
			        white-space:pre-wrap; word-break:break-word }
			  .status { padding:16px 28px; border-top:1px solid #e7ebef; font-size:22px; font-weight:700;
			            color:{{statusColor}}; background:{{statusBg}} }
			  .note { margin-top:18px; padding:18px 24px; border-left:5px solid {{noteBorder}};
			          background:#fff; border-radius:0 8px 8px 0; font-size:21px; line-height:1.45 }
			  </style>
			  <div class="card">
			    <div class="desc">{{Esc(c.Description)}}</div>
			    <div class="call"><span class="verb">{{Esc(c.Method)}}</span>{{Esc(c.Url)}}</div>
			    {{(c.Status is int st ? $"<div class=\"status\">{st} {Esc(StatusText(st))}</div>" : "")}}
			    <div class="bodies">
			      {{Block(labels.Request, request == "" ? null : request)}}
			      {{Block(labels.Response, Json(c.Response))}}
			    </div>
			  </div>
			  {{(c.Note is not null ? $"<div class=\"note\">{Esc(c.Note)}</div>" : "")}}
			""";
	}

	/// <summary>Below this the card's smallest text stops being readable in a 1080p frame.</summary>
	const double MinFitScale = 0.62;

	// Scales the card down until it fits the frame, and refuses to shrink it past the point
	// of legibility. A card that overflows loses its LAST line first — which is exactly
	// where `pickFields` puts "… N more fields". The marker saying something was left out
	// is the first thing to disappear, and what remains looks complete.
	static async Task FitToFrame(IPage page)
	{
		var scale = await page.EvaluateAsync<double>("""
			() => {
			  const body = document.body;
			  body.style.transform = "";
			  body.style.width = "";
			  const needed = body.scrollHeight;
			  const available = window.innerHeight;
			  if (needed <= available) return 1;
			  const s = available / needed;
			  body.style.transformOrigin = "top left";
			  body.style.transform = `scale(${s})`;
			  // Widen as it shrinks, so the card still fills the frame instead of leaving a band.
			  body.style.width = `${100 / s}%`;
			  return s;
			}
			""");

		if (scale < MinFitScale)
		{
			throw new InvalidOperationException(
				$"apiPanel: this card needs {1 / scale:0.0}x the frame height and would have " +
				$"to shrink to {Math.Round(scale * 100)}% to fit, past the point of being readable. " +
				"Trim it with pickFields, shorten the note, or split the call across two cards.");
		}
	}

	/// <summary>Draws the card on the page, ready for `capture` to photograph it.</summary>
	public static async Task ShowApiCall(IPage page, ApiCall call)
	{
		await page.SetContentAsync(Html(call), new() { WaitUntil = WaitUntilState.Load });
		await FitToFrame(page);
	}

	/// <summary>Free-text card, for what is not an API call — a query result, a log line, a file.</summary>
	public static Task ShowCard(IPage page, string description, string label, string text, string? note = null, CardLabels? labels = null) =>
		// Through ShowApiCall, not SetContent: one path to draw a card, so the fit-to-frame
		// check cannot be true of one kind of card and not the other.
		ShowApiCall(page, new ApiCall
		{
			Description = description,
			Method = "SQL",
			Url = label,
			Response = text,
			Note = note,
			Labels = labels,
		});

	public sealed record JsonResponse(int Status, JsonElement? Body, string Text)
	{
		/// <summary>A property of the body as JSON, or null when the body is not JSON or lacks it.</summary>
		public JsonElement? Prop(string property) =>
			Body is { ValueKind: JsonValueKind.Object } b && b.TryGetProperty(property, out var v) ? v : null;

		/// <summary>A property of the body as text, or "" when the body is not JSON or lacks it.</summary>
		public string Get(string property) =>
			Body is { ValueKind: JsonValueKind.Object } b && b.TryGetProperty(property, out var v)
				? (v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : v.ToString())
				: "";
	}

	/// <summary>JSON POST with an optional bearer credential.</summary>
	public static async Task<JsonResponse> PostJson(IAPIRequestContext api, string url, object data, string? bearer = null)
	{
		var r = await api.PostAsync(url, new()
		{
			DataObject = data,
			Headers = bearer is null
				? new Dictionary<string, string>()
				: new Dictionary<string, string> { ["Authorization"] = $"Bearer {bearer}" },
		});
		var text = await r.TextAsync();
		JsonElement? body = null;
		try
		{
			using var doc = JsonDocument.Parse(text);
			body = doc.RootElement.Clone();
		}
		catch (JsonException)
		{
			body = null;
		}
		return new JsonResponse(r.Status, body, text);
	}
}
