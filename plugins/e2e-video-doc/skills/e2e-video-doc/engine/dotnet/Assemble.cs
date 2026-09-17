using System.Diagnostics;
using System.Globalization;
using FFMpegCore;
using FFMpegCore.Extensions.Downloader;
using FFMpegCore.Extensions.Downloader.Enums;

namespace E2EVideoDoc.Engine;

/// <summary>
/// make_video.sh's loop: one segment per screenshot with its narration spoken, then all of them
/// concatenated. The ffmpeg arguments are the script's, so the MP4 comes out the same — measured
/// on 7 real screenshots: same duration, resolution, codecs, frame rate and audio bitrate.
/// </summary>
public static class Assemble
{
    /// <summary>Pinned, not "latest": the video changing should be a decision.</summary>
    const FFMpegVersions FFmpegVersion = FFMpegVersions.V6_1;

    /// <summary>One per machine, shared by every project, like ms-playwright.</summary>
    public static string FFmpegDir { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "e2e-video-doc", "ffmpeg");

    /// <summary>
    /// ffmpeg and ffprobe ship in no package: they are fetched the first time they are needed,
    /// about 250 MB. The same kind of step as installing a Playwright browser, minus the command
    /// to remember.
    /// </summary>
    public static async Task EnsureFFmpeg()
    {
        var options = new FFOptions { BinaryFolder = FFmpegDir, TemporaryFilesFolder = Path.GetTempPath() };
        if (!File.Exists(Path.Combine(FFmpegDir, "ffmpeg.exe")) || !File.Exists(Path.Combine(FFmpegDir, "ffprobe.exe")))
        {
            Directory.CreateDirectory(FFmpegDir);
            Console.WriteLine($"   Fetching ffmpeg 6.1 into {FFmpegDir} (once per machine, about 250 MB)...");
            var clock = Stopwatch.StartNew();
            await FFMpegDownloader.DownloadBinaries(FFmpegVersion, options: options);
            Console.WriteLine($"   ffmpeg ready in {clock.Elapsed.TotalSeconds:0} s.");
        }
        GlobalFFOptions.Configure(options);
    }

    public static async Task<int> Run(string narrationFile, string screenshotsDir, string output, string voice, string rate)
    {
        Console.WriteLine("Building video from screenshots + narration (.NET engine)");
        Console.WriteLine($"   Voice:       {voice}");
        Console.WriteLine($"   Narration:   {narrationFile}");
        Console.WriteLine($"   Screenshots: {screenshotsDir}");
        Console.WriteLine($"   Output:      {output}");

        if (!File.Exists(narrationFile)) { Console.WriteLine($"No such narration file: {narrationFile}"); return 1; }
        if (!Directory.Exists(screenshotsDir)) { Console.WriteLine($"No such screenshots directory: {screenshotsDir}"); return 1; }

        await EnsureFFmpeg();

        List<Frame> frames;
        try { frames = Frames.Read(narrationFile, screenshotsDir); }
        catch (InvalidDataException e) { Console.Error.WriteLine(e.Message); return 1; }

        // Same working directories as the script, removed at the end.
        var audioDir = Path.Combine(screenshotsDir, "audio");
        var segmentsDir = Path.GetFullPath(Path.Combine(screenshotsDir, "segments"));
        Directory.CreateDirectory(audioDir);
        Directory.CreateDirectory(segmentsDir);
        var outputDir = Path.GetDirectoryName(Path.GetFullPath(output));
        if (outputDir is not null) Directory.CreateDirectory(outputDir);

        var segments = new List<string>();
        var missing = 0;
        foreach (var frame in frames)
        {
            var idx = frame.Index.ToString("00", CultureInfo.InvariantCulture);
            var image = Path.Combine(screenshotsDir, frame.Screenshot);
            if (!File.Exists(image))
            {
                Console.WriteLine($"  missing screenshot: {frame.Screenshot} — skipped");
                missing++;
                continue;
            }

            Console.WriteLine($"  [{idx}] {Truncate(frame.Narration, 60)}...");
            var mp3 = Path.Combine(audioDir, idx + ".mp3");
            try
            {
                await File.WriteAllBytesAsync(mp3, await Voice.Synthesize(frame.Narration, voice, rate));
            }
            catch (Exception e)
            {
                Console.Error.WriteLine($"The voice failed on entry {idx}. Usual causes: a voice name that does not exist,");
                Console.Error.WriteLine("no network access, or the service having changed its handshake (see Voice.cs).");
                Console.Error.WriteLine($"  {e.GetType().Name}: {e.Message}");
                return 1;
            }

            // The segment lasts as long as the voice does, not as long as the JSON says:
            // `duration` is a floor, not a value. If the narration runs long, the image follows.
            var audioSeconds = (await FFProbe.AnalyseAsync(mp3)).Duration.TotalSeconds;
            var segmentSeconds = Math.Max(audioSeconds + 0.5, frame.Duration);

            var segment = Path.Combine(segmentsDir, idx + ".mp4");
            try
            {
                await FFMpegArguments
                    .FromFileInput(image, false, o => o.WithCustomArgument("-loop 1"))
                    .AddFileInput(mp3)
                    .OutputToFile(segment, true, o => o
                        .WithCustomArgument("-vf \"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=white\"")
                        .WithVideoCodec("libx264")
                        .WithCustomArgument("-tune stillimage -pix_fmt yuv420p")
                        .WithAudioCodec("aac")
                        .WithCustomArgument("-b:a 128k")
                        .WithCustomArgument("-t " + segmentSeconds.ToString("0.###", CultureInfo.InvariantCulture))
                        .UsingShortest())
                    .ProcessAsynchronously();
            }
            catch (Exception e)
            {
                Console.Error.WriteLine($"ffmpeg failed building segment {idx} from {frame.Screenshot}.");
                Console.Error.WriteLine($"  {e.Message}");
                return 1;
            }
            segments.Add(segment);
        }

        // Without this guard ffmpeg gets an empty list and returns its own error instead of
        // saying what actually happened: there were no screenshots.
        if (segments.Count == 0)
        {
            Console.WriteLine($"Nothing to concatenate: all {frames.Count} screenshots are missing.");
            Console.WriteLine("Did the capture step run before this?");
            return 1;
        }

        Console.WriteLine($"Concatenating {segments.Count} segments...");
        var list = Path.Combine(segmentsDir, "concat.txt");
        // ffmpeg's concat demuxer resolves paths against the list file, so they are absolute.
        await File.WriteAllLinesAsync(list, segments.Select(s => $"file '{s.Replace('\\', '/')}'"));
        try
        {
            await FFMpegArguments
                .FromFileInput(list, false, o => o.WithCustomArgument("-f concat -safe 0"))
                .OutputToFile(output, true, o => o.CopyChannel())
                .ProcessAsynchronously();
        }
        catch (Exception e)
        {
            Console.Error.WriteLine("ffmpeg failed concatenating the segments.");
            Console.Error.WriteLine($"  {e.Message}");
            return 1;
        }

        Directory.Delete(audioDir, true);
        Directory.Delete(segmentsDir, true);

        var info = await FFProbe.AnalyseAsync(output);
        var size = new FileInfo(output).Length / 1024.0 / 1024.0;
        Console.WriteLine($"Done: {output}  ({(int)info.Duration.TotalSeconds}s, {size:0.0}M)");
        if (missing > 0)
            Console.WriteLine($"Heads up: {missing} screenshots were missing and are not in the video.");
        return 0;
    }

    static string Truncate(string s, int n) => s.Length <= n ? s : s[..n];
}
