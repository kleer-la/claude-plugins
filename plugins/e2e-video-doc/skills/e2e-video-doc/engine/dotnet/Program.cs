// The .NET engine takes exactly what make_video.sh takes, through the environment, so the
// caller (make_videos.ps1) resolves everything once and hands it to whichever engine runs:
//
//   NARRATION    path of the narration JSON              (required)
//   SCREENSHOTS  directory of NN_name.png files           (required)
//   OUTPUT       path of the output mp4                  (required)
//   VOICE        an edge-tts voice name                  (default en-US-JennyNeural)
//   RATE         speaking rate, like +0% or -10%         (default +0%)
using E2EVideoDoc.Engine;

static string Required(string key, string what) =>
    Environment.GetEnvironmentVariable(key) is { Length: > 0 } v
        ? v
        : throw new ArgumentException($"set {key}=<{what}>");

static string Optional(string key, string fallback) =>
    Environment.GetEnvironmentVariable(key) is { Length: > 0 } v ? v : fallback;

try
{
    return await Assemble.Run(
        Required("NARRATION", "path to the narration json"),
        Required("SCREENSHOTS", "directory of PNGs"),
        Required("OUTPUT", "path of the output mp4"),
        Optional("VOICE", "en-US-JennyNeural"),
        Optional("RATE", "+0%"));
}
catch (ArgumentException e)
{
    Console.Error.WriteLine(e.Message);
    return 2;
}
