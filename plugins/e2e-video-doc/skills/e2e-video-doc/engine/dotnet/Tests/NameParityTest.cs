using System.Diagnostics;
using System.Text.Json;
using E2EVideoDoc.Engine;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace E2EVideoDoc.Engine.Tests;

// The parity test proper: the same cases run through make_video.sh's own resolution block and
// through Frames, and the two outputs must be identical — resolved file names and error messages
// alike. FramesTest pins each branch; this one catches the script changing under the port.
//
// It needs bash and jq. On Windows they come from WSL; where there is no bash, the test is
// inconclusive rather than green, because a parity test that compared nothing passed nothing.
[TestClass]
public class NameParityTest
{
    static readonly (string Name, object Entry, string[] Shots)[] Cases =
    {
        ("screenshot_wins", new { screenshot = "02_other.png", name = "login" }, new[] { "01_login.png", "02_other.png" }),
        ("empty_screenshot", new { screenshot = "", name = "login" }, new[] { "04_login.png" }),
        ("null_screenshot", new { screenshot = (string?)null, name = "login" }, new[] { "04_login.png" }),
        ("one_match", new { name = "login" }, new[] { "01_intro.png", "07_login.png" }),
        ("title_asset", new { name = "title" }, new[] { "00_title.png", "01_login.png" }),
        ("two_matches", new { name = "login" }, new[] { "02_login.png", "05_login.png" }),
        ("no_match", new { name = "login" }, new[] { "01_intro.png" }),
        ("neither", new { }, Array.Empty<string>()),
        ("glob_exact", new { name = "login" }, new[] { "1_login.png", "123_login.png", "ab_login.png", "03_login_2.png", "03_my_login.png" }),
        ("case_sensitive", new { name = "login" }, new[] { "03_Login.png" }),
    };

    [TestMethod]
    public void dotnet_resolves_every_case_exactly_as_make_video_sh_does()
    {
        var root = Path.Combine(Path.GetTempPath(), "e2e-video-doc-parity-" + Guid.NewGuid().ToString("N"));
        try
        {
            foreach (var (name, entry, shots) in Cases)
            {
                var shotsDir = Path.Combine(root, name, "shots");
                Directory.CreateDirectory(shotsDir);
                foreach (var s in shots)
                    File.WriteAllBytes(Path.Combine(shotsDir, s), Array.Empty<byte>());
                // duration and narration are read by the script's loop, not by the block under
                // test; they are there because a real entry always has them.
                var node = JsonSerializer.SerializeToNode(entry)!.AsObject();
                node["duration"] = 3;
                node["narration"] = "x";
                File.WriteAllText(Path.Combine(root, name, "narration.json"), new System.Text.Json.Nodes.JsonArray(node).ToJsonString());
            }

            var expected = RunBash(root);
            var actual = Cases
                .Select(c => c.Name)
                .OrderBy(n => n, StringComparer.Ordinal)
                .Select(n =>
                {
                    try
                    {
                        var dir = Path.Combine(root, n);
                        return $"{n}|OK {Frames.Read(Path.Combine(dir, "narration.json"), Path.Combine(dir, "shots"))[0].Screenshot}";
                    }
                    catch (InvalidDataException e) { return $"{n}|{e.Message}"; }
                })
                .ToList();

            CollectionAssert.AreEqual(expected, actual,
                "make_video.sh:\n  " + string.Join("\n  ", expected) + "\n.NET:\n  " + string.Join("\n  ", actual));
        }
        finally
        {
            if (Directory.Exists(root)) Directory.Delete(root, true);
        }
    }

    static List<string> RunBash(string casesDir)
    {
        var script = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "resolve_names.sh"));
        var makeVideo = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "make_video.sh"));
        var onWindows = OperatingSystem.IsWindows();
        string Arg(string p) => onWindows ? ToWslPath(p) : p;

        var psi = new ProcessStartInfo(onWindows ? "wsl" : "bash")
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        if (onWindows) { psi.ArgumentList.Add("-e"); psi.ArgumentList.Add("bash"); }
        psi.ArgumentList.Add(Arg(script));
        psi.ArgumentList.Add(Arg(makeVideo));
        psi.ArgumentList.Add(Arg(casesDir));

        Process? p;
        try { p = Process.Start(psi); }
        catch (System.ComponentModel.Win32Exception) { p = null; }
        if (p is null)
            Assert.Inconclusive("No bash here (and no WSL on Windows): nothing to compare the .NET engine with.");

        var stdout = p!.StandardOutput.ReadToEnd();
        var stderr = p.StandardError.ReadToEnd();
        p.WaitForExit();
        if (p.ExitCode != 0 || stdout.Contains("jq: command not found") || stdout.Contains("jq: not found"))
            Assert.Inconclusive($"bash could not run the script's block (exit {p.ExitCode}): {stderr}{stdout}");

        return stdout.Replace("\r", "")
            .Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .OrderBy(l => l, StringComparer.Ordinal)
            .ToList();
    }

    /// <summary>C:\x\y → /mnt/c/x/y. Done here rather than with wslpath, which loses the backslashes on the way in.</summary>
    static string ToWslPath(string windowsPath)
    {
        var full = Path.GetFullPath(windowsPath);
        return "/mnt/" + char.ToLowerInvariant(full[0]) + full[2..].Replace('\\', '/');
    }
}
