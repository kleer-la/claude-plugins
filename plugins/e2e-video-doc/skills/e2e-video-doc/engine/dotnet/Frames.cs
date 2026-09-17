using System.Text.Json;

namespace E2EVideoDoc.Engine;

/// <summary>One narration entry, with its screenshot already resolved.</summary>
public sealed record Frame(int Index, string Screenshot, double Duration, string Narration);

/// <summary>
/// Reads the narration JSON and resolves each entry to a screenshot file name, the way
/// make_video.sh does. This is the one part of the engine that is logic rather than plumbing,
/// so it is kept pure and tested branch by branch against the script (Tests/FramesTest.cs).
/// </summary>
public static class Frames
{
    public static List<Frame> Read(string narrationFile, string screenshotsDir)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(narrationFile));
        var frames = new List<Frame>();
        var i = 0;
        foreach (var entry in doc.RootElement.EnumerateArray())
        {
            frames.Add(new Frame(
                i + 1,
                Resolve(entry, i, screenshotsDir),
                entry.GetProperty("duration").GetDouble(),
                entry.GetProperty("narration").GetString() ?? ""));
            i++;
        }
        return frames;
    }

    /// <summary>
    /// make_video.sh: `name` matches `NN_&lt;name&gt;.png` regardless of its ordinal, so inserting a
    /// frame earlier in the walkthrough touches one JSON entry instead of renumbering every file
    /// after it and every `screenshot` key that names one. `screenshot`, when given, still wins
    /// outright — this only fires when it is absent.
    /// </summary>
    public static string Resolve(JsonElement entry, int i, string screenshotsDir)
    {
        var screenshot = StringOrEmpty(entry, "screenshot");
        if (screenshot.Length > 0)
            return screenshot;

        var name = StringOrEmpty(entry, "name");
        if (name.Length == 0)
            throw new InvalidDataException($"entry {i} has neither \"screenshot\" nor \"name\"");

        // The script's glob is `[0-9][0-9]_<name>.png`: exactly two digits, then the name. Bash
        // globs case-sensitively and Windows lists case-insensitively, so the name is compared
        // ordinally after listing rather than trusted to the file system's pattern.
        var matches = Directory.Exists(screenshotsDir)
            ? Directory.GetFiles(screenshotsDir, "*.png")
                .Select(Path.GetFileName)
                .Select(f => f!)
                .Where(f => f.Length == name.Length + 7
                    && char.IsAsciiDigit(f[0]) && char.IsAsciiDigit(f[1])
                    && f.AsSpan(2).SequenceEqual(("_" + name + ".png").AsSpan()))
                .OrderBy(f => f, StringComparer.Ordinal)
                .ToList()
            : new List<string>();

        if (matches.Count > 1)
            throw new InvalidDataException(
                $"\"name\": \"{name}\" matches more than one screenshot: {string.Join(" ", matches)}");
        // No match is not an error here: like the script, it resolves to a file that does not
        // exist, and the frame is reported missing and skipped.
        return matches.Count == 1 ? matches[0] : $"NN_{name}.png";
    }

    /// <summary>jq's `.[$i].key // empty`: absent, null and "" all read as empty.</summary>
    static string StringOrEmpty(JsonElement entry, string key) =>
        entry.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";
}
