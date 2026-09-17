using System.Text.Json;
using E2EVideoDoc.Engine;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace E2EVideoDoc.Engine.Tests;

// Parity with make_video.sh on the one piece of the engine that is logic rather than plumbing:
// which screenshot a narration entry resolves to. Voice, rate, language and titleAssets are
// resolved by make_videos.ps1 before either engine runs, so they need no test of their own
// here. Each case names the branch of the script it mirrors.
[TestClass]
public class FramesTest
{
    string _dir = "";

    [TestInitialize]
    public void CreateDir()
    {
        _dir = Path.Combine(Path.GetTempPath(), "e2e-video-doc-frames-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
    }

    [TestCleanup]
    public void RemoveDir() => Directory.Delete(_dir, true);

    void Shots(params string[] names)
    {
        foreach (var n in names)
            File.WriteAllBytes(Path.Combine(_dir, n), Array.Empty<byte>());
    }

    string Resolve(string json)
    {
        using var doc = JsonDocument.Parse(json);
        return Frames.Resolve(doc.RootElement, 0, _dir);
    }

    // `screenshot`, when given, still wins outright.
    [TestMethod]
    public void screenshot_wins_even_when_a_name_would_match()
    {
        Shots("01_login.png", "02_other.png");
        Assert.AreEqual("02_other.png", Resolve("""{ "screenshot": "02_other.png", "name": "login" }"""));
    }

    // SCREENSHOT=$(jq -r ".[$i].screenshot // empty"): an empty or null screenshot is absent.
    [TestMethod]
    public void an_empty_or_null_screenshot_falls_back_to_name()
    {
        Shots("04_login.png");
        Assert.AreEqual("04_login.png", Resolve("""{ "screenshot": "", "name": "login" }"""));
        Assert.AreEqual("04_login.png", Resolve("""{ "screenshot": null, "name": "login" }"""));
    }

    // elif [ "${#MATCHES[@]}" -eq 1 ]: the ordinal does not matter.
    [TestMethod]
    public void name_matches_one_screenshot_whatever_its_ordinal()
    {
        Shots("01_intro.png", "07_login.png");
        Assert.AreEqual("07_login.png", Resolve("""{ "name": "login" }"""));
    }

    // make_videos.ps1 copies titleAssets in as 00_<name>.png, and they are found the same way.
    [TestMethod]
    public void a_title_asset_copied_in_as_00_is_found_by_name()
    {
        Shots("00_title.png", "01_login.png");
        Assert.AreEqual("00_title.png", Resolve("""{ "name": "title" }"""));
    }

    // if [ "${#MATCHES[@]}" -gt 1 ]: an error naming the files, not a guess.
    [TestMethod]
    public void name_matching_more_than_one_screenshot_is_an_error()
    {
        Shots("02_login.png", "05_login.png");
        var e = Assert.ThrowsExactly<InvalidDataException>(() => Resolve("""{ "name": "login" }"""));
        Assert.AreEqual("\"name\": \"login\" matches more than one screenshot: 02_login.png 05_login.png", e.Message);
    }

    // else SCREENSHOT="NN_${NAME}.png": no match resolves to a file that does not exist, and the
    // frame is then reported missing and skipped rather than failing the run.
    [TestMethod]
    public void name_matching_nothing_resolves_to_NN_name()
    {
        Shots("01_intro.png");
        Assert.AreEqual("NN_login.png", Resolve("""{ "name": "login" }"""));
    }

    // echo "entry $i has neither \"screenshot\" nor \"name\""
    [TestMethod]
    public void an_entry_with_neither_is_an_error()
    {
        var e = Assert.ThrowsExactly<InvalidDataException>(() => Resolve("""{ "narration": "x", "duration": 3 }"""));
        Assert.AreEqual("entry 0 has neither \"screenshot\" nor \"name\"", e.Message);
    }

    // The glob is [0-9][0-9]_"$NAME".png: exactly two digits, then exactly the name.
    [TestMethod]
    public void the_glob_is_exactly_two_digits_and_exactly_the_name()
    {
        Shots("1_login.png", "123_login.png", "ab_login.png", "03_login_2.png", "03_my_login.png");
        Assert.AreEqual("NN_login.png", Resolve("""{ "name": "login" }"""));
    }

    // Bash globs case-sensitively; a Windows directory listing does not, so this is checked.
    [TestMethod]
    public void the_name_is_case_sensitive_like_the_glob()
    {
        Shots("03_Login.png");
        Assert.AreEqual("NN_login.png", Resolve("""{ "name": "login" }"""));
    }
}
