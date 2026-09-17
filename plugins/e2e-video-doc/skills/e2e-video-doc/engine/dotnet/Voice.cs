using System.Globalization;
using System.Net;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace E2EVideoDoc.Engine;

/// <summary>
/// The narration voice: Microsoft Edge's read-aloud service, the same one edge-tts talks to.
///
/// A port of edge-tts 7.2.8 (communicate.py, drm.py, constants.py). The constants keep their
/// constants.py names so the two diff directly. When the service changes its handshake — it has:
/// the Sec-MS-GEC token appeared in 2024 — the fix is to diff those three files, from the edge-tts
/// release that fixed it, against this one.
///
/// Not an official or documented API. edge-tts carries the same risk; the difference is that
/// here the fix is an edit to this file rather than a `pipx upgrade`.
/// </summary>
public static partial class Voice
{
    const string TRUSTED_CLIENT_TOKEN = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
    const string BASE_URL = "speech.platform.bing.com/consumer/speech/synthesize/readaloud";
    const string CHROMIUM_FULL_VERSION = "143.0.3650.75";
    const long WIN_EPOCH = 11644473600;
    /// <summary>communicate.py splits text at 4096 bytes. No narration entry comes near; this fails instead.</summary>
    const int MaxTextBytes = 4000;

    /// <summary>drm.py corrects the clock from the server's date when a token is rejected.</summary>
    static double _clockSkewSeconds;

    /// <summary>
    /// drm.generate_sec_ms_gec: seconds since the Windows epoch, rounded down to 5 minutes, in
    /// 100-ns ticks, followed by the client token, SHA-256, uppercase hex. Integer arithmetic here
    /// where Python uses a float; at these magnitudes the result is the same, and checked against
    /// edge-tts for the same instant.
    /// </summary>
    public static string SecMsGec(DateTimeOffset now)
    {
        long seconds = now.ToUnixTimeSeconds() + (long)_clockSkewSeconds + WIN_EPOCH;
        seconds -= seconds % 300;
        var toHash = (seconds * 10_000_000L).ToString(CultureInfo.InvariantCulture) + TRUSTED_CLIENT_TOKEN;
        return Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(toHash)));
    }

    // edge-tts validates rate the same way before sending it (data_classes.py).
    [GeneratedRegex(@"^[+-]\d+%$")]
    private static partial Regex RateFormat();

    /// <summary>Speaks <paramref name="text"/> and returns the MP3 (24 kHz, 48 kb/s, mono).</summary>
    public static async Task<byte[]> Synthesize(string text, string voice, string rate, CancellationToken ct = default)
    {
        if (!RateFormat().IsMatch(rate))
            throw new ArgumentException($"Invalid rate '{rate}': expected something like +0% or -10%.", nameof(rate));
        if (Encoding.UTF8.GetByteCount(text) > MaxTextBytes)
            throw new ArgumentException($"A narration entry longer than {MaxTextBytes} bytes; split it in two.", nameof(text));

        using var ws = await Connect(ct);

        await SendText(ws,
            $"X-Timestamp:{JavascriptDate()}\r\n"
            + "Content-Type:application/json; charset=utf-8\r\n"
            + "Path:speech.config\r\n\r\n"
            + "{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{"
            + "\"sentenceBoundaryEnabled\":\"true\",\"wordBoundaryEnabled\":\"false\""
            + "},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}\r\n", ct);

        var ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>"
            + $"<voice name='{voice}'><prosody pitch='+0Hz' rate='{rate}' volume='+0%'>{EscapeText(text)}</prosody></voice>"
            + "</speak>";
        // The "Z" after the timestamp is not a mistake: communicate.py copies it from an Edge bug.
        await SendText(ws,
            $"X-RequestId:{Guid.NewGuid():N}\r\n"
            + "Content-Type:application/ssml+xml\r\n"
            + $"X-Timestamp:{JavascriptDate()}Z\r\n"
            + "Path:ssml\r\n\r\n"
            + ssml, ct);

        using var audio = new MemoryStream();
        while (true)
        {
            var (type, data) = await Receive(ws, ct);
            if (type == WebSocketMessageType.Text)
            {
                var path = Header(Encoding.UTF8.GetString(data), "Path");
                if (path == "turn.end")
                    break;
                if (path is not ("response" or "turn.start" or "audio.metadata"))
                    throw new InvalidOperationException($"Unknown message from the voice service: Path={path}");
                continue;
            }

            // Binary: the first two bytes are the header length, big-endian. As in communicate.py,
            // the header is data[:header_length] and the audio data[header_length + 2:], both
            // counted from the start of the message.
            if (data.Length < 2)
                throw new InvalidOperationException("Binary message without a header length.");
            int length = (data[0] << 8) | data[1];
            if (length > data.Length)
                throw new InvalidOperationException("The header length is greater than the message.");
            var header = Encoding.ASCII.GetString(data, 0, length);
            if (Header(header, "Path") != "audio")
                throw new InvalidOperationException("Binary message that is not audio.");
            int from = Math.Min(length + 2, data.Length);
            int count = data.Length - from;
            // The stream ends with a binary message with no Content-Type and no data: expected.
            if (Header(header, "Content-Type") is null)
            {
                if (count > 0)
                    throw new InvalidOperationException("Binary message with no Content-Type, but with data.");
                continue;
            }
            audio.Write(data, from, count);
        }

        if (audio.Length == 0)
            throw new InvalidOperationException($"No audio received. Does the voice '{voice}' exist?");
        try { await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "", ct); } catch (WebSocketException) { }
        return audio.ToArray();
    }

    /// <summary>
    /// A 403 is usually the clock: the token changes every 5 minutes and a skewed machine
    /// produces one the service rejects. Like drm.py, correct it from the server's date and try
    /// once more.
    /// </summary>
    static async Task<ClientWebSocket> Connect(CancellationToken ct)
    {
        for (int attempt = 1; ; attempt++)
        {
            var ws = NewWebSocket();
            try
            {
                var url = $"wss://{BASE_URL}/edge/v1?TrustedClientToken={TRUSTED_CLIENT_TOKEN}"
                    + $"&ConnectionId={Guid.NewGuid():N}"
                    + $"&Sec-MS-GEC={SecMsGec(DateTimeOffset.UtcNow)}"
                    + $"&Sec-MS-GEC-Version=1-{CHROMIUM_FULL_VERSION}";
                await ws.ConnectAsync(new Uri(url), ct);
                return ws;
            }
            catch (WebSocketException) when (attempt == 1 && ws.HttpStatusCode == HttpStatusCode.Forbidden
                && ServerDate(ws) is { } server)
            {
                _clockSkewSeconds += (server - DateTimeOffset.UtcNow).TotalSeconds;
                ws.Dispose();
            }
            catch
            {
                ws.Dispose();
                throw;
            }
        }
    }

    static ClientWebSocket NewWebSocket()
    {
        var major = CHROMIUM_FULL_VERSION.Split('.')[0];
        var ws = new ClientWebSocket();
        ws.Options.CollectHttpResponseDetails = true;
        // WSS_HEADERS in constants.py. Without User-Agent the service answers 403.
        ws.Options.SetRequestHeader("Pragma", "no-cache");
        ws.Options.SetRequestHeader("Cache-Control", "no-cache");
        ws.Options.SetRequestHeader("Origin", "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold");
        ws.Options.SetRequestHeader("User-Agent",
            $"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{major}.0.0.0 Safari/537.36 Edg/{major}.0.0.0");
        ws.Options.SetRequestHeader("Accept-Language", "en-US,en;q=0.9");
        ws.Options.SetRequestHeader("Cookie", $"muid={Guid.NewGuid().ToString("N").ToUpperInvariant()};");
        return ws;
    }

    static DateTimeOffset? ServerDate(ClientWebSocket ws)
    {
        if (ws.HttpResponseHeaders is null || !ws.HttpResponseHeaders.TryGetValue("Date", out var values))
            return null;
        return DateTimeOffset.TryParse(values.FirstOrDefault(), CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal, out var date) ? date : null;
    }

    static async Task<(WebSocketMessageType Type, byte[] Data)> Receive(ClientWebSocket ws, CancellationToken ct)
    {
        var buffer = new byte[64 * 1024];
        using var message = new MemoryStream();
        WebSocketReceiveResult r;
        do
        {
            r = await ws.ReceiveAsync(buffer, ct);
            if (r.MessageType == WebSocketMessageType.Close)
                throw new InvalidOperationException($"The voice service closed the connection: {r.CloseStatus} {r.CloseStatusDescription}");
            message.Write(buffer, 0, r.Count);
        } while (!r.EndOfMessage);
        return (r.MessageType, message.ToArray());
    }

    static Task SendText(ClientWebSocket ws, string text, CancellationToken ct) =>
        ws.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(text)), WebSocketMessageType.Text, true, ct);

    /// <summary>Value of a "Key:value" header in the block before the first \r\n\r\n.</summary>
    static string? Header(string message, string key)
    {
        var end = message.IndexOf("\r\n\r\n", StringComparison.Ordinal);
        foreach (var line in (end < 0 ? message : message[..end]).Split("\r\n"))
        {
            var colon = line.IndexOf(':');
            if (colon > 0 && line[..colon] == key)
                return line[(colon + 1)..];
        }
        return null;
    }

    /// <summary>communicate.date_to_string: Javascript's date format, always in UTC.</summary>
    static string JavascriptDate() =>
        DateTime.UtcNow.ToString("ddd MMM dd yyyy HH:mm:ss", CultureInfo.InvariantCulture)
        + " GMT+0000 (Coordinated Universal Time)";

    /// <summary>
    /// communicate.remove_incompatible_characters (the service rejects control characters) and the
    /// XML escaping edge-tts applies before building the SSML.
    /// </summary>
    static string EscapeText(string text)
    {
        var sb = new StringBuilder(text.Length);
        foreach (var c in text)
        {
            if (c <= 8 || c == 11 || c == 12 || (c >= 14 && c <= 31)) { sb.Append(' '); continue; }
            sb.Append(c switch { '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", _ => c.ToString() });
        }
        return sb.ToString();
    }
}
