# Windows: capture on the host (against the local site), assemble the video in WSL.
#
# `edge-tts`, `ffmpeg` and `jq` are not on a typical Windows host, but they are in WSL
# Ubuntu. Rather than rewrite the engine, it is called across the bridge.
# See reference/gotchas.md, "Windows".
#
#   .\make_videos.ps1 -Flow checkout
#   .\make_videos.ps1 -Flow checkout -Lang en
#   .\make_videos.ps1 -Flow checkout -CaptureOnly   # screenshots, no narration yet
#   .\make_videos.ps1 -Flow checkout -AssembleOnly  # from the screenshots already there
#   $env:VOICE = "en-GB-SoniaNeural"; .\make_videos.ps1 -Flow checkout

param(
    [Parameter(Mandatory = $true)][string]$Flow,
    [string]$Lang,
    [switch]$AssembleOnly,
    [switch]$CaptureOnly
)

if ($AssembleOnly -and $CaptureOnly) { throw "-AssembleOnly and -CaptureOnly are opposites; pick one." }

$ErrorActionPreference = "Stop"
$EngineDir = $PSScriptRoot

# Search for e2e-video-doc.json upward from the cwd.
$Dir = (Get-Location).Path
while ($Dir -and -not (Test-Path (Join-Path $Dir "e2e-video-doc.json"))) {
    $Dir = Split-Path $Dir -Parent
}
if (-not $Dir) { throw "No e2e-video-doc.json found from $(Get-Location) upward." }
$Root = $Dir
$Config = Get-Content (Join-Path $Root "e2e-video-doc.json") -Raw | ConvertFrom-Json

if (-not $Config.flows.$Flow) {
    $defined = ($Config.flows.PSObject.Properties.Name -join ", ")
    throw "Flow '$Flow' is not in the config. Defined: $defined"
}

# Languages are optional. Without them, {lang} and {lang_suffix} resolve to empty.
$Languages = $Config.languages
$HasLangs = $Languages -and $Languages.PSObject.Properties.Name.Count -gt 0
if ($HasLangs) {
    # PSObject.Properties preserves document order, unlike a sorted key list.
    $LangCode = if ($Lang) { $Lang } else { $Languages.PSObject.Properties.Name[0] }
    if (-not $Languages.$LangCode) {
        $defined = ($Languages.PSObject.Properties.Name -join ", ")
        throw "Language '$LangCode' is not in the config. Defined: $defined"
    }
    $LangSuffix = if ($null -ne $Languages.$LangCode.suffix) { $Languages.$LangCode.suffix } else { "" }
}
else {
    if ($Lang) { throw "This config declares no languages, but '$Lang' was passed." }
    $LangCode = ""
    $LangSuffix = ""
}

function Field([string]$Key) {
    $v = $Config.flows.$Flow.$Key
    if (-not $v) { $v = $Config.defaults.$Key }
    if (-not $v) { throw "Missing '$Key' for flow '$Flow'" }
    return $v.Replace("{flow}", $Flow).Replace("{lang_suffix}", $LangSuffix).Replace("{lang}", $LangCode)
}

$Shots     = Join-Path $Root (Field "screenshots")
$Narration = Join-Path $Root (Field "narration")
$Output    = Join-Path $Root (Field "output")
$Voice     = if ($env:VOICE) { $env:VOICE }
             elseif ($HasLangs -and $Languages.$LangCode.voice) { $Languages.$LangCode.voice }
             elseif ($Config.flows.$Flow.voice) { $Config.flows.$Flow.voice }
             elseif ($Config.defaults.voice) { $Config.defaults.voice }
             else { "en-US-JennyNeural" }
$Label     = if ($LangCode) { "$Flow ($LangCode)" } else { $Flow }

if (-not $AssembleOnly) {
    Write-Host "> $Label - capturing"
    Push-Location $Root
    try {
        $env:RUN_VIDEO_TESTS = "1"
        $env:E2E_VIDEO_DOC_ENGINE = $EngineDir
        $env:SCREENSHOTS = $Shots
        # One flow per run: several video specs at once fight over shared state
        # (config flags, seeded data) and take twice as long.
        cmd /c (Field "capture")
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally { Pop-Location }
}

function Convert-ToWslPath([string]$WinPath) {
    # Converted here rather than with `wsl wslpath`: going through PowerShell, wsl.exe
    # eats the backslashes and the argument arrives as "C:UsersDev..." -- it fails
    # without saying why. Doing it locally is deterministic and removes a moving part.
    $full = [System.IO.Path]::GetFullPath($WinPath)
    if ($full -notmatch '^[A-Za-z]:') {
        throw "not a Windows path with a drive letter: $WinPath"
    }
    $drive = $full.Substring(0, 1).ToLower()
    # .Replace and not -replace: the latter is regex, and a lone backslash does not compile.
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

$wslShots     = Convert-ToWslPath $Shots
$wslNarration = Convert-ToWslPath $Narration
$wslOutput    = Convert-ToWslPath $Output
$wslScript    = Convert-ToWslPath (Join-Path $EngineDir "make_video.sh")

if ($CaptureOnly) {
    Write-Host ""
    Write-Host "OK: screenshots in $Shots"
    Write-Host "Look at them before writing the narration - fixing the walkthrough is far"
    Write-Host "cheaper before the audio exists. Then rerun without -CaptureOnly."
    exit 0
}

# Checked here rather than up front: the narration is what assembling needs, and step 3
# of the skill is to capture and look at the PNGs before writing it.
if (-not (Test-Path $Narration)) {
    throw "No narration file: $Narration`nCapture first with -CaptureOnly, then write it."
}

Write-Host "> $Label - narrating and assembling in WSL ($Voice)"
# `tr -d '\r'`: a clone made with core.autocrlf=true - the Windows default - gives the
# engine's .sh files CRLF endings, and bash dies on its own shebang with
# "\r: command not found". .gitattributes fixes this at the source for fresh clones;
# this rescues the ones that already exist, and is a no-op once they are LF.
wsl bash -lc "VOICE='$Voice' NARRATION='$wslNarration' SCREENSHOTS='$wslShots' OUTPUT='$wslOutput' bash <(tr -d '\r' < '$wslScript')"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "OK: $Output"
